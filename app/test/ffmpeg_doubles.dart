import 'dart:async';

import 'package:ve_services/ve_services.dart';

/// A probe that reports one step and then waits, so a test can see the
/// FFmpeg screen mid-check. [finish] completes every probe started. With
/// [atHardware], the step is the hardware phase's first event: the encoder
/// list (the fixture's, hardware rows not tested yet) is already in (F7).
class StalledProbe implements FFmpegProbe {
  StalledProbe({this.atHardware = false});
  final bool atHardware;
  final FakeFFmpegProbe _fake = FakeFFmpegProbe();
  final List<StreamController<ProbeProgress>> _open = [];
  final List<String> cancelled = [];

  /// The installation of each probe started, in order.
  final List<String> started = [];

  @override
  Stream<ProbeProgress> probe(FFmpegInstallation installation) {
    started.add(installation.id);
    final controller = StreamController<ProbeProgress>();
    _open.add(controller);
    if (atHardware) {
      () async {
        final listed = (await _fake.probe(installation).last).capabilities!;
        final hardware = {for (final p in FakeVeCore().profiles().video) if (p.hw != null) p.id};
        final encoders = {
          for (final MapEntry(:key, :value) in listed.encoders.entries)
            key: hardware.contains(key)
                ? {...value as Map, 'availability': {'state': 'unknown', 'reason': 'Listed; awaiting a test on this PC.'}}
                : value,
        };
        if (controller.isClosed) return;
        controller.add(
          ProbeProgress(
            installationId: installation.id,
            phase: 'hardware',
            total: hardware.where(encoders.containsKey).length,
            message: 'Testing listed hardware encoders on this PC.',
            capabilities: listed.copyWith(encoders: encoders),
          ),
        );
      }();
      return controller.stream;
    }
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

  /// What each test asked for, in order.
  final List<({String installationId, List<String>? encoders, bool reuseIdentity})> calls = [];

  @override
  Stream<HardwareTestResult> test(
    FFmpegInstallation installation, {
    List<String>? encoders,
    bool force = false,
    bool reuseIdentity = false,
  }) {
    calls.add((installationId: installation.id, encoders: encoders, reuseIdentity: reuseIdentity));
    return StreamController<HardwareTestResult>().stream;
  }

  @override
  Future<void> cancel(String installationId) async => cancelled.add(installationId);
}

/// A completed background AMF HEVC check, as discovery returns it.
FFmpegInstallation withAmfHevcResult(FFmpegInstallation installation) => installation.copyWith(
  availability: {
    ...installation.availability,
    'hevc_amf': {
      'state': 'ok',
      'reason': 'One-frame test passed on this GPU/driver.',
      'note': 'AMD Radeon(TM) 8060S Graphics',
      'tenBit': true,
    },
  },
);

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
