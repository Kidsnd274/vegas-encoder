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
