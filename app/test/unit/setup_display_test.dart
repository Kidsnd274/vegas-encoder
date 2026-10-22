import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/design/components/status.dart';
import 'package:vegas_encoder/features/setup/display.dart';
import 'package:vegas_encoder/state/ffmpeg.dart';

import '../ffmpeg_doubles.dart';

/// The setup wizard's rows (UI_SPEC §5a) from the B0 fixture installations.
void main() {
  final catalog = FakeVeCore().profiles();
  late List<FFmpegInstallation> fixtures;
  setUpAll(() async => fixtures = await FakeFFmpegDiscovery().list());

  FFmpegInstallation fixture(String id) => fixtures.singleWhere((i) => i.id == id);

  /// [base] with its hardware encoders' recorded state replaced by [state].
  FFmpegInstallation withHardware(FFmpegInstallation base, String? state) => FFmpegInstallation.fromJson({
    ...base.toJson(),
    'availability': {
      for (final e in base.availability.entries)
        if (!e.key.contains('_nvenc') && !e.key.contains('_qsv') && !e.key.contains('_amf')) e.key: e.value,
      if (state != null)
        for (final id in ['h264_nvenc', 'hevc_qsv']) id: EncoderAvailability(state: state, reason: 'r').data,
    },
  });

  SetupCandidate row(FFmpegInstallation i, {FFmpegState state = const FFmpegState(), bool isDefault = false}) =>
      setupCandidate(i, isDefault: isDefault, state: state, catalog: catalog);

  group('hardware summary', () {
    test('names the hardware encoders ready on this PC and counts failures', () {
      final c = row(fixture('gyan-8.1'), isDefault: true);
      expect(c.title, 'FFmpeg 8.1 full');
      expect(c.line, 'gyan.dev full build, GPL v3. Installed with winget.');
      expect(c.hardware, 'Hardware ready: NVENC H.264, NVENC HEVC, NVENC AV1. 2 failed their test on this PC.');
      expect(c.hardwareState, VeAvailability.ready);
      expect(c.isDefault, isTrue);
    });

    test('says when none works, none was checked, or none is in this FFmpeg', () {
      final base = fixture('gyan-8.1');
      expect(row(withHardware(base, 'failed')).hardware, 'No hardware encoder works on this PC: 2 failed their test.');
      expect(row(withHardware(base, 'failed')).hardwareState, VeAvailability.failed);
      expect(row(withHardware(base, 'unknown')).hardware, 'Hardware encoders not checked yet.');
      expect(
        row(withHardware(base, null)).hardware,
        'No hardware encoders in this FFmpeg. Software encoders still work.',
      );
    });

    test('a running test or check says so', () {
      final i = fixture('gyan-8.1');
      final testing = FFmpegState(
        testing: {
          i.id: {'h264_nvenc'},
        },
      );
      expect(row(i, state: testing).hardware, 'Testing hardware encoders on this PC…');
      expect(row(i, state: testing).hardwareState, VeAvailability.testing);
      final probing = FFmpegState(
        probes: {i.id: ProbeProgress(installationId: i.id, phase: 'details', completed: 18, total: 25)},
      );
      expect(row(i, state: probing).progress?.label, 'Reading encoders… 18 of 25');
    });
  });

  test('untested hardware is what the FFmpeg lists with no result on this PC', () {
    expect(untestedHardware(fixture('gyan-8.1'), const FFmpegState(), catalog), isEmpty);
    expect(untestedHardware(withHardware(fixture('gyan-8.1'), 'unknown'), const FFmpegState(), catalog), [
      'h264_nvenc',
      'hevc_qsv',
    ]);
    expect(untestedHardware(withHardware(fixture('gyan-8.1'), null), const FFmpegState(), catalog), isEmpty);
  });

  group('recommendation and selection', () {
    test('the most ready video encoders wins; ties keep discovery order', () {
      final rows = [for (final i in fixtures) row(i)];
      expect(rows.map((r) => r.readyVideo), [10, 10, 8]);
      expect(recommendedCandidate(rows), 'gyan-8.1');
      expect(recommendedCandidate(rows.reversed.toList()), 'manual-7.1');
    });

    test('files as checked come first; a missing ffmpeg.exe can’t be chosen', () async {
      // The default changed on disk, 7.1.1 missing, the LGPL build without ffprobe.
      final rows = [for (final i in await unhealthyInstallations()) row(i)];
      expect(rows.where((r) => !r.selectable).map((r) => r.id), ['manual-7.1']);
      expect(recommendedCandidate(rows), 'gyan-8.1', reason: 'every one has a note; the most ready selectable one');
      final healthy = row(fixture('btbn-lgpl-8.0'));
      expect(recommendedCandidate([...rows, healthy]), 'btbn-lgpl-8.0', reason: 'as checked beats more encoders');
      expect(recommendedCandidate([rows[1]]), isNull);
    });

    test('the user’s pick, else the current default, else the recommendation', () async {
      final rows = [for (final i in fixtures) row(i, isDefault: i.id == 'btbn-lgpl-8.0')];
      expect(selectedCandidate(rows), 'btbn-lgpl-8.0');
      expect(selectedCandidate(rows, chosenId: 'manual-7.1'), 'manual-7.1');
      expect(selectedCandidate([for (final i in fixtures) row(i)]), 'gyan-8.1');
      final unhealthy = [for (final i in await unhealthyInstallations()) row(i)];
      expect(selectedCandidate(unhealthy, chosenId: 'manual-7.1'), 'gyan-8.1', reason: 'missing can’t be chosen');
    });
  });
}
