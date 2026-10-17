import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import 'services.dart';

/// One run of "Test this preset" (UI_SPEC §2): these settings with this
/// FFmpeg. Each run is its own object, so "Test again" starts a new one.
final class PresetTestRequest {
  PresetTestRequest(this.recipe, this.installation);
  final Recipe recipe;
  final FFmpegInstallation installation;
}

/// What a run has reported so far (C3 `PresetTestProgress`), with FFmpeg's
/// output kept to its last [presetTestLogLines] lines.
@immutable
class PresetTestState {
  const PresetTestState({
    this.latest,
    this.log = '',
    this.logLines = 0,
    this.running = true,
    this.stopped = false,
    this.error,
  });

  /// The newest progress; null until the service reports.
  final PresetTestProgress? latest;

  /// The last lines FFmpeg wrote.
  final String log;

  /// Lines FFmpeg wrote in all.
  final int logLines;
  final bool running;

  /// Stopped here (Stop, or the dialog closed) before the service finished.
  final bool stopped;

  /// The service refused or failed outright, with its message.
  final String? error;

  PresetTestState copyWith({
    PresetTestProgress? latest,
    String? log,
    int? logLines,
    bool? running,
    bool? stopped,
    String? error,
  }) => PresetTestState(
    latest: latest ?? this.latest,
    log: log ?? this.log,
    logLines: logLines ?? this.logLines,
    running: running ?? this.running,
    stopped: stopped ?? this.stopped,
    error: error ?? this.error,
  );
}

/// How much of FFmpeg's output the test panel keeps.
const int presetTestLogLines = 400;

/// A run of the C3 `PresetTests` service. It starts when first watched and
/// stops when nothing watches it any more (the panel closed), which cancels
/// the service's work; its log and output stay where the service put them.
final presetTestProvider = NotifierProvider.autoDispose
    .family<PresetTestController, PresetTestState, PresetTestRequest>(PresetTestController.new);

class PresetTestController extends Notifier<PresetTestState> {
  PresetTestController(this.request);
  final PresetTestRequest request;
  StreamSubscription<PresetTestProgress>? _run;

  @override
  PresetTestState build() {
    final run = ref
        .watch(presetTestsProvider)
        .test(request.recipe, request.installation)
        .listen(
          _report,
          onError: (Object e) {
            if (ref.mounted) {
              state = state.copyWith(
                running: false,
                error: switch (e) {
                  ServiceException(:final message) || CoreException(:final message) => message,
                  _ => '$e',
                },
              );
            }
          },
          onDone: () {
            if (ref.mounted) state = state.copyWith(running: false);
          },
          cancelOnError: true,
        );
    _run = run;
    ref.onDispose(run.cancel);
    return const PresetTestState();
  }

  void _report(PresetTestProgress p) {
    if (!ref.mounted) return;
    var log = state.log;
    var lines = state.logLines;
    if (p.log.isNotEmpty) {
      final added = p.log.replaceAll('\r\n', '\n');
      lines += '\n'.allMatches(added).length;
      final all = (log + added).split('\n');
      log = all.length > presetTestLogLines + 1
          ? all.sublist(all.length - presetTestLogLines - 1).join('\n')
          : all.join('\n');
    }
    state = state.copyWith(latest: p, log: log, logLines: lines);
  }

  /// Stop: cancelling the subscription cancels the service's run (C3).
  Future<void> stop() async {
    final run = _run;
    if (run == null || !state.running) return;
    state = state.copyWith(running: false, stopped: true);
    await run.cancel();
  }
}
