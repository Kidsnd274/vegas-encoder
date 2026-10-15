import 'dart:async';

import 'package:ve_services/ve_services.dart';

/// A probe that reports one step and then waits, so a test can see the
/// FFmpeg screen mid-check. [finish] completes every probe started.
class StalledProbe implements FFmpegProbe {
  final FakeFFmpegProbe _fake = FakeFFmpegProbe();
  final List<StreamController<ProbeProgress>> _open = [];
  final List<String> cancelled = [];

  @override
  Stream<ProbeProgress> probe(FFmpegInstallation installation) {
    final controller = StreamController<ProbeProgress>();
    _open.add(controller);
    controller.add(
      ProbeProgress(
        installationId: installation.id,
        phase: 'details',
        completed: 18,
        total: 25,
        message: 'Reading encoder options',
      ),
    );
    return controller.stream;
  }

  /// Ends every probe with [phase] ("done" carries no capabilities here).
  Future<void> finish({String phase = 'failed', String message = 'ffmpeg.exe stopped responding.'}) async {
    for (final c in _open) {
      c.add(ProbeProgress(installationId: '', phase: phase, completed: 25, total: 25, message: message));
      await c.close();
    }
    _open.clear();
  }

  @override
  Future<EncoderDetails> encoderDetails(FFmpegInstallation installation, String encoder) =>
      _fake.encoderDetails(installation, encoder);

  @override
  Future<void> cancel(String installationId) async => cancelled.add(installationId);
}

/// Hardware tests that never report, so a test can see encoders mid-test.
class StalledHardwareTests implements HardwareTests {
  final List<String> cancelled = [];

  @override
  Stream<HardwareTestResult> test(FFmpegInstallation installation, {List<String>? encoders, bool force = false}) =>
      StreamController<HardwareTestResult>().stream;

  @override
  Future<void> cancel(String installationId) async => cancelled.add(installationId);
}

/// The fixture installations with discovery's health facts (C3 `health`): the
/// default changed on disk, 7.1.1 missing, the LGPL build without ffprobe.
Future<List<FFmpegInstallation>> unhealthyInstallations() async => [
  for (final i in await FakeFFmpegDiscovery().list())
    switch (i.label) {
      'FFmpeg 8.1 full' => i.copyWith(
        health: 'changed',
        healthMessage: 'FFmpeg files changed since they were checked.',
      ),
      'FFmpeg 7.1.1' => i.copyWith(health: 'missing', healthMessage: 'FFmpeg executable or libraries are missing.'),
      'FFmpeg 8.0 LGPL' => i.copyWith(health: 'ffprobe-missing', healthMessage: 'FFprobe is missing beside FFmpeg.'),
      _ => i,
    },
];
