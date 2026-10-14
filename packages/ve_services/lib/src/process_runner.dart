import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'api.dart';

class CancellationToken {
  final _cancelled = Completer<void>();
  final Set<void Function()> _callbacks = {};
  bool get cancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;
  void check() {
    if (cancelled)
      throw const ServiceException('CANCELLED', 'Operation cancelled.');
  }

  void Function() onCancel(void Function() callback) {
    if (cancelled) {
      callback();
      return () {};
    }
    _callbacks.add(callback);
    return () {
      _callbacks.remove(callback);
    };
  }

  void cancel() {
    if (cancelled) return;
    _cancelled.complete();
    for (final callback in _callbacks.toList()) {
      callback();
    }
    _callbacks.clear();
  }
}

class ProcessOutput {
  const ProcessOutput({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
    this.elapsedMs = 0,
    this.timedOut = false,
    this.cancelled = false,
    this.outputLimit = false,
  });
  final int exitCode;
  final String stdout;
  final String stderr;
  final int elapsedMs;
  final bool timedOut;
  final bool cancelled;
  final bool outputLimit;
  void requireSuccess(String operation) {
    if (cancelled)
      throw const ServiceException('CANCELLED', 'Operation cancelled.');
    if (timedOut)
      throw ServiceException(
        'PROCESS-TIMEOUT',
        '$operation timed out; child killed.',
      );
    if (outputLimit)
      throw ServiceException(
        'PROCESS-OUTPUT-LIMIT',
        '$operation exceeded its output limit.',
      );
    if (exitCode != 0)
      throw ServiceException(
        'PROCESS-FAILED',
        '$operation failed ($exitCode): $stderr',
      );
  }
}

abstract interface class ProcessExecutor {
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    CancellationToken? cancellation,
    Duration timeout = const Duration(seconds: 10),
    int stdoutLimit = 1024 * 1024,
    int outputLimit = 8 * 1024 * 1024,
    void Function(String text)? onStderr,
    void Function(String text)? onStdout,
  });
}

/// One shared pool for identity/probe/hardware/preset calls. Queued cancellation
/// removes its waiter; it never consumes a slot or starts an executable.
class ProcessPool {
  ProcessPool({this.limit = 4}) {
    if (limit < 1 || limit > 4) throw ArgumentError.value(limit);
  }
  final int limit;
  int _active = 0;
  final List<Completer<void>> _waiters = [];
  int get active => _active;
  Future<void> _acquire(CancellationToken token) async {
    token.check();
    if (_active < limit) {
      _active++;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    final unsubscribe = token.onCancel(() {
      if (_waiters.remove(waiter))
        waiter.completeError(
          const ServiceException('CANCELLED', 'Queued process cancelled.'),
        );
    });
    try {
      await waiter.future;
    } finally {
      unsubscribe();
    }
  }

  void _release() {
    if (_waiters.isEmpty) {
      _active--;
    } else {
      _waiters.removeAt(0).complete();
    }
  }

  Future<T> use<T>(CancellationToken token, Future<T> Function() action) async {
    await _acquire(token);
    try {
      token.check();
      return await action();
    } finally {
      _release();
    }
  }
}

class WindowsProcessExecutor implements ProcessExecutor {
  WindowsProcessExecutor({ProcessPool? pool}) : pool = pool ?? ProcessPool();
  final ProcessPool pool;
  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    CancellationToken? cancellation,
    Duration timeout = const Duration(seconds: 10),
    int stdoutLimit = 1024 * 1024,
    int outputLimit = 8 * 1024 * 1024,
    void Function(String text)? onStderr,
    void Function(String text)? onStdout,
  }) async {
    final token = cancellation ?? CancellationToken();
    if (!Platform.isWindows)
      throw const ServiceException(
        'UNSUPPORTED-PLATFORM',
        'Windows processes are required.',
      );
    if (!RegExp(r'^(?:[A-Za-z]:[\\/]|\\\\)').hasMatch(executable) ||
        executable.contains('\u0000') ||
        arguments.any((a) => a.contains('\u0000'))) {
      throw const ServiceException(
        'PROCESS-PATH',
        'Use an absolute executable path and NUL-free arguments.',
      );
    }
    if (timeout <= Duration.zero ||
        stdoutLimit < 1 ||
        outputLimit < stdoutLimit)
      throw ArgumentError('Invalid process bounds.');
    return pool.use(token, () async {
      token.check();
      final watch = Stopwatch()..start();
      Process process;
      try {
        process = await Process.start(
          executable,
          arguments,
          runInShell: false,
          mode: ProcessStartMode.normal,
        );
      } on ProcessException catch (e) {
        throw ServiceException(
          'PROCESS-START',
          'Cannot start executable: ${e.message}',
        );
      }
      var timedOut = false;
      var limited = false;
      var total = 0;
      var stdoutCount = 0;
      final output = BytesBuilder(copy: false);
      final tail = <int>[];
      void stop() {
        process.kill(ProcessSignal.sigkill);
      }

      final unsubscribe = token.onCancel(stop);
      final timer = Timer(timeout, () {
        timedOut = true;
        stop();
      });
      Future<void> collect(Stream<List<int>> stream, bool isError) async {
        final callback = isError ? onStderr : onStdout;
        final decoder = callback == null
            ? null
            : const Utf8Decoder(
                allowMalformed: true,
              ).startChunkedConversion(_TextSink(callback));
        await for (final bytes in stream) {
          total += bytes.length;
          if (total > outputLimit) {
            limited = true;
            stop();
          }
          if (isError) {
            tail.addAll(bytes);
            if (tail.length > 65536) tail.removeRange(0, tail.length - 65536);
            // Invalid UTF-8 in FFmpeg diagnostics is replacement-decoded only;
            // protocol/cache JSON still uses strict UTF-8.
            if (total <= outputLimit) decoder?.add(bytes);
          } else {
            stdoutCount += bytes.length;
            if (stdoutCount > stdoutLimit) {
              limited = true;
              stop();
            } else {
              output.add(bytes);
              decoder?.add(bytes);
            }
          }
        }
        decoder?.close();
      }

      final streams = Future.wait([
        collect(process.stdout, false),
        collect(process.stderr, true),
      ]);
      try {
        await process.stdin.close();
        final completion = await Future.wait<Object?>([
          process.exitCode,
          streams,
        ]);
        final code = completion.first as int;
        return ProcessOutput(
          exitCode: code,
          stdout: utf8.decode(output.takeBytes(), allowMalformed: true),
          stderr: utf8.decode(tail, allowMalformed: true),
          elapsedMs: watch.elapsedMilliseconds,
          timedOut: timedOut,
          cancelled: token.cancelled,
          outputLimit: limited,
        );
      } catch (_) {
        stop();
        await process.exitCode;
        rethrow;
      } finally {
        timer.cancel();
        unsubscribe();
      }
    });
  }
}

class _TextSink implements Sink<String> {
  _TextSink(this.callback);
  final void Function(String) callback;
  @override
  void add(String value) => callback(value);
  @override
  void close() {}
}

class FakeProcessExecutor implements ProcessExecutor {
  FakeProcessExecutor(this.handler);
  final Future<ProcessOutput> Function(
    String executable,
    List<String> arguments,
    CancellationToken cancellation,
  )
  handler;
  final List<(String, List<String>)> calls = [];
  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    CancellationToken? cancellation,
    Duration timeout = const Duration(seconds: 10),
    int stdoutLimit = 1024 * 1024,
    int outputLimit = 8 * 1024 * 1024,
    void Function(String text)? onStderr,
    void Function(String text)? onStdout,
  }) async {
    final token = cancellation ?? CancellationToken();
    token.check();
    calls.add((executable, List.unmodifiable(arguments)));
    final result = await handler(executable, arguments, token);
    if (result.stderr.isNotEmpty) onStderr?.call(result.stderr);
    if (result.stdout.isNotEmpty) onStdout?.call(result.stdout);
    return result;
  }
}
