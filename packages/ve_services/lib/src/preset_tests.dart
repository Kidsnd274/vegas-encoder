import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ve_core/ve_core.dart';

import 'api.dart';
import 'models.dart';
import 'storage.dart';
import 'ffmpeg_identity.dart';
import 'ffmpeg_parser.dart';
import 'process_runner.dart';
import 'operations.dart';
import 'capabilities.dart';

/// User-facing text and machine-readable identity are separate from an
/// exception's debugging representation.
(String, String) _failure(Object error) => switch (error) {
  ServiceException(:final code, :final message) => (code, message),
  CoreException(:final code, :final message) => (code, message),
  FileSystemException(:final message, :final osError) => (
    'PRESET-TEST-IO',
    osError == null ? message : '$message: ${osError.message}',
  ),
  ProcessException(:final message) => ('PRESET-TEST-PROCESS', message),
  FormatException(:final message) => ('PRESET-TEST-DATA', message),
  _ => ('PRESET-TEST-FAILED', 'The preset test could not finish.'),
};

/// Process/output boundary only. Expected kinds/codecs are supplied by core;
/// neither the UI nor services infer them from argv or command text.
VerificationResult verifyOutput(
  JsonMap probe,
  List<ExpectedStream> expected, {
  String? version,
}) {
  final actual = jsonMaps(probe['streams'] ?? []);
  final expectedCodecs = expected
      .map((s) => s.codec)
      .whereType<String>()
      .toList();
  final actualCodecs = actual
      .map((s) => s['codec_name'])
      .whereType<String>()
      .toList();
  VerificationResult result(String state, String message) => VerificationResult(
    state: state,
    message: message,
    expectedCodecs: expectedCodecs,
    actualCodecs: actualCodecs,
    ffprobeVersion: version,
  );
  if (actual.length != expected.length)
    return result(
      'failed',
      'Output stream count does not match the compiled recipe.',
    );
  final remaining = actual.toList();
  for (final stream in expected) {
    final index = remaining.indexWhere(
      (s) =>
          s['codec_type'] == stream.kind &&
          (stream.codec == null || s['codec_name'] == stream.codec),
    );
    if (index < 0)
      return result(
        'failed',
        'Expected ${stream.kind} ${stream.codec ?? 'stream'} is missing.',
      );
    final found = remaining.removeAt(index);
    if (found['codec_name'] is! String || found['codec_name'] == 'unknown')
      return result('failed', 'Output codec was not recognized.');
    if (stream.kind == 'video' &&
        (int.tryParse('${found['nb_read_frames']}') ?? 0) < 1)
      return result('failed', 'Output contains no readable video frames.');
  }
  return result(
    'passed',
    expected.any((s) => s.codec == null)
        ? 'Stream kinds/count and known codecs match; unestablished codecs are reported as actual output facts.'
        : 'Output stream count and codecs match the compiled recipe.',
  );
}

class WindowsPresetTests implements PresetTests {
  WindowsPresetTests({
    required this.core,
    required this.runner,
    required this.cache,
    ServicePaths? paths,
    WindowsFFmpegHelpParser? parser,
  }) : paths = paths ?? ServicePaths.windows(),
       parser = parser ?? WindowsFFmpegHelpParser();
  final VeCore core;
  final ProcessExecutor runner;
  final CapabilityCache cache;
  final ServicePaths paths;
  final WindowsFFmpegHelpParser parser;
  final _operations = OperationRegistry();
  @override
  Future<void> cancel(String testId) => _operations.cancel(testId);
  @override
  Stream<PresetTestProgress> test(
    Recipe recipe,
    FFmpegInstallation installation,
  ) {
    final id =
        'test-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    late StreamController<PresetTestProgress> controller;
    ServiceOperation? operation;
    controller = StreamController(
      onListen: () {
        final op = operation = _operations.begin(id);
        unawaited(() async {
          String phase = 'preparing';
          String? outputPath;
          String? logPath;
          String? commandLine;
          IOSink? log;
          Object? logFailure;
          Future<void>? logCompletion;
          Directory? directory;
          var logBytes = 0;
          var logLimit = false;
          var frames = 0;
          PresetTestProgress? terminal;
          void emit({
            String text = '',
            String message = '',
            String? code,
            VerificationResult? verification,
          }) {
            final event = PresetTestProgress(
              testId: id,
              phase: phase,
              log: text,
              message: message,
              code: code,
              framesDone: frames,
              commandLine: commandLine,
              logPath: logPath,
              outputPath: outputPath,
              verification: verification,
            );
            if (['done', 'failed', 'cancelled'].contains(phase))
              terminal = event;
            else if (!controller.isClosed)
              controller.add(event);
          }

          void stderr(String text) {
            logBytes += utf8.encode(text).length;
            if (logBytes > 8 * 1024 * 1024) {
              logLimit = true;
              op.token.cancel();
              return;
            }
            log?.write(text);
            emit(text: text);
          }

          try {
            emit(
              message: 'Preparing 60 synthetic testsrc2 frames and two seconds of stereo sine.',
            );
            await requireCurrentInstallation(
              installation,
              parser.version,
              op.token,
            );
            final capabilities = await cache.read(installation.identity.key);
            if (capabilities == null)
              throw const ServiceException(
                'PROBE-REQUIRED',
                'Probe this installation before testing a preset.',
              );
            final root = Directory(joinPath(paths.local, 'tests'));
            await root.create(recursive: true);
            directory = await root.createTemp('$id-');
            final video = joinPath(directory.path, 'input.p010');
            final audio = joinPath(directory.path, 'input.f32');
            final container = core
                .profiles()
                .containers
                .where((c) => c.id == recipe.container.format)
                .firstOrNull;
            outputPath = joinPath(
              directory.path,
              'output${container?.ext ?? '.mkv'}',
            );
            logPath = joinPath(directory.path, 'ffmpeg.log');
            log = File(logPath).openWrite();
            // Observe asynchronous sink errors immediately, including before
            // flush/close. They must stop the child and remain a test failure.
            logCompletion = log.done.then<void>(
              (_) {},
              onError: (Object error, StackTrace stack) {
                logFailure = error;
                op.token.cancel();
              },
            );
            final media = MediaDescription(
              video: VideoMedia(
                width: 320,
                height: 180,
                fps: [30, 1],
                pixfmt: 'p010le',
              ),
              audio: AudioMedia(rate: 48000, channels: 2, sampleFmt: 'f32le'),
              durationSec: 2,
            );
            final compiled = core.compile(
              recipe,
              media: media,
              paths: CompilePaths(
                ffmpeg: installation.path,
                videoPipe: video,
                audioPipe: audio,
                output: outputPath,
              ),
              capabilities: capabilities.toCoreCapabilities(
                label: installation.label,
                recipe: recipe,
              ),
            );
            commandLine = compiled.commandLine;
            final errors = compiled.issues
                .where((i) => i.level == IssueLevel.error)
                .toList();
            if (errors.isNotEmpty)
              throw ServiceException(
                'RECIPE-INVALID',
                errors.map((i) => i.message).join(' '),
              );
            if (compiled.expectedStreams == null ||
                compiled.issues.any(
                  (i) => ['L-INPUT', 'L-OUTPUTS'].contains(i.id),
                )) {
              throw const ServiceException(
                'PRESET-TEST-SCOPE',
                'Synthetic preset tests require the generated inputs and one output.',
              );
            }
            final generated = await runner.run(
              installation.path,
              [
                '-hide_banner',
                '-nostdin',
                '-loglevel',
                'error',
                '-f',
                'lavfi',
                '-i',
                'testsrc2=s=320x180:r=30',
                '-frames:v',
                '60',
                '-pix_fmt',
                'p010le',
                '-f',
                'rawvideo',
                video,
              ],
              cancellation: op.token,
              onStderr: stderr,
            );
            generated.requireSuccess('Synthetic video generation');
            final generatedAudio = await runner.run(
              installation.path,
              [
                '-hide_banner',
                '-nostdin',
                '-loglevel',
                'error',
                '-f',
                'lavfi',
                '-i',
                'sine=frequency=1000:sample_rate=48000:duration=2',
                '-ac',
                '2',
                '-c:a',
                'pcm_f32le',
                '-f',
                'f32le',
                audio,
              ],
              cancellation: op.token,
              onStderr: stderr,
            );
            generatedAudio.requireSuccess('Synthetic audio generation');
            op.token.check();
            phase = 'encoding';
            emit();
            var pending = '';
            final encoded = await runner.run(
              compiled.executable,
              compiled.argv,
              cancellation: op.token,
              timeout: const Duration(seconds: 60),
              onStderr: stderr,
              onStdout: (text) {
                pending += text;
                final lines = pending.split('\n');
                pending = lines.removeLast();
                for (final line in lines) {
                  if (line.startsWith('frame='))
                    frames = int.tryParse(line.substring(6).trim()) ?? frames;
                  if (line.startsWith('progress=')) emit();
                }
              },
            );
            encoded.requireSuccess('Preset encoding');
            op.token.check();
            phase = 'verifying';
            emit();
            final probed = await runner.run(
              installation.ffprobePath,
              [
                '-v',
                'error',
                '-count_frames',
                '-show_streams',
                '-show_format',
                '-of',
                'json',
                outputPath,
              ],
              cancellation: op.token,
              timeout: const Duration(seconds: 15),
              onStderr: stderr,
            );
            probed.requireSuccess('Output verification');
            final verified = verifyOutput(
              decodeJson(probed.stdout),
              compiled.expectedStreams!,
              version: installation.version,
            );
            if (verified.state != 'passed') {
              phase = 'failed';
              emit(
                message: verified.message,
                code: 'PRESET-TEST-VERIFY',
                verification: verified,
              );
              return;
            }
            final decoded = await runner.run(
              installation.path,
              [
                '-hide_banner',
                '-nostdin',
                '-v',
                'error',
                '-xerror',
                '-i',
                outputPath,
                '-map',
                '0:v?',
                '-map',
                '0:a?',
                '-f',
                'null',
                '-',
              ],
              cancellation: op.token,
              timeout: const Duration(seconds: 30),
              onStderr: stderr,
            );
            decoded.requireSuccess('Complete output decode');
            await requireCurrentInstallation(
              installation,
              parser.version,
              op.token,
            );
            phase = 'done';
            emit(
              message: 'Synthetic preset test passed; output streams matched and fully decoded.',
              verification: verified,
            );
          } catch (e) {
            phase = op.token.cancelled && !logLimit && logFailure == null
                ? 'cancelled'
                : 'failed';
            final (code, message) = logLimit
                ? (
                    'PRESET-TEST-LOG-LIMIT',
                    'Test log exceeded 8 MiB; child stopped.',
                  )
                : phase == 'cancelled'
                ? ('CANCELLED', 'Test cancelled.')
                : _failure(logFailure ?? e);
            emit(message: message, code: code);
          } finally {
            try {
              await log?.flush();
              await log?.close();
              await logCompletion;
              if (logFailure != null) throw logFailure!;
              if (directory != null) {
                // Only known generated input names are removed. Output/log stay
                // available for inspection; stopped output is never published.
                for (final name in ['input.p010', 'input.f32']) {
                  final file = File(joinPath(directory.path, name));
                  if (await file.exists()) await file.delete();
                }
              }
            } catch (e) {
              final previous = terminal;
              final (_, message) = _failure(e);
              terminal = PresetTestProgress.fromJson({
                ...?previous?.data,
                'testId': id,
                'phase': 'failed',
                'code': 'PRESET-TEST-CLEANUP',
                'message':
                    '${previous?.message ?? ''} Test artifact cleanup/log write failed: $message'
                        .trim(),
              });
            } finally {
              if (terminal != null && !controller.isClosed)
                controller.add(terminal!);
              _operations.finish(id, op);
              unawaited(controller.close());
            }
          }
        }());
      },
      onCancel: () async {
        final op = operation;
        if (op != null) {
          op.token.cancel();
          await op.done.future;
        }
      },
    );
    return controller.stream;
  }
}

class FakePresetTests implements PresetTests {
  FakePresetTests({List<PresetTestProgress>? events})
    : events = List.unmodifiable(
        events ??
            [
              PresetTestProgress(
                testId: 'fixture-test',
                phase: 'preparing',
                isFixture: true,
              ),
              PresetTestProgress(
                testId: 'fixture-test',
                phase: 'encoding',
                framesDone: 30,
                log: 'Synthetic fixture log.\n',
                isFixture: true,
              ),
              PresetTestProgress(
                testId: 'fixture-test',
                phase: 'done',
                framesDone: 60,
                verification: VerificationResult(
                  state: 'passed',
                  message: 'Illustrative fixture result, no process executed.',
                ),
                isFixture: true,
              ),
            ],
      );
  final List<PresetTestProgress> events;
  final Set<String> _cancelled = {};
  @override
  Stream<PresetTestProgress> test(
    Recipe recipe,
    FFmpegInstallation installation,
  ) async* {
    for (final event in events) {
      if (_cancelled.contains(event.testId)) return;
      yield event;
    }
  }

  @override
  Future<void> cancel(String id) async {
    _cancelled.add(id);
  }
}
