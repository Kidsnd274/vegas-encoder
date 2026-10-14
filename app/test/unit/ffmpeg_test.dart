import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/design/components/status.dart';
import 'package:vegas_encoder/features/ffmpeg/display.dart';
import 'package:vegas_encoder/state/ffmpeg.dart';
import 'package:vegas_encoder/state/services.dart';

import '../ffmpeg_doubles.dart';

import '../helpers.dart';

/// The FFmpeg screen's mapping and state against the platform fakes (B0).
/// Nothing here runs FFmpeg; the installations are illustrative fixtures.
void main() {
  late List<FFmpegInstallation> installations;
  late ProfileCatalog catalog;
  late List<Preset> presets;

  FFmpegInstallation inst(String id) => installations.singleWhere((i) => i.id == id);

  setUpAll(() async {
    installations = await FakeFFmpegDiscovery().list();
    catalog = FakeVeCore().profiles();
    presets = await FakePresetLibrary().list();
  });

  group('encoder status', () {
    test('uses the installation’s recorded availability', () {
      final full = inst('gyan-8.1');
      expect(encoderStatus(full, 'libx264').state, VeAvailability.ready);
      final qsv = encoderStatus(full, 'hevc_qsv');
      expect(qsv.state, VeAvailability.failed);
      expect(qsv.reason, 'No Intel graphics device on this PC.');
      expect(qsv.detail, contains('MFX session'));
      expect(encoderStatus(full, 'hevc_nvenc').note, 'NVIDIA GeForce RTX 4070');
      expect(encoderStatus(inst('btbn-lgpl-8.0'), 'libx264').state, VeAvailability.missing);
    });

    test('an encoder nobody lists is missing, or unknown if never checked', () {
      final full = inst('gyan-8.1');
      final missing = encoderStatus(full, 'libfoo');
      expect(missing.state, VeAvailability.missing);
      expect(missing.reason, 'Not in FFmpeg 8.1 full.');
      final never = FFmpegInstallation.fromJson({...full.toJson(), 'probedAt': null, 'availability': {}});
      expect(encoderStatus(never, 'libx264').state, VeAvailability.unknown);
    });

    test('a test running now, then a test result, then a probe, win in that order', () {
      final full = inst('gyan-8.1');
      final failed = HardwareTestResult(
        encoder: 'hevc_nvenc',
        state: 'failed',
        failureClass: 'runtime-missing',
        reason: 'Driver too old.',
        stderr: '[hevc_nvenc] Driver does not support the required nvenc API version.',
        testedAt: '2026-10-14T01:00:00Z',
        identityKey: full.identity.key,
        gpuFingerprint: 'x',
      );
      final probed = FFmpegCapabilities(
        installationId: full.id,
        identityKey: full.identity.key,
        version: '8.1',
        probedAt: '2026-10-14T00:00:00Z',
        encoders: {
          'hevc_nvenc': {
            'kind': 'video',
            'availability': {'state': 'missing', 'reason': 'Gone.'},
          },
        },
      );
      expect(encoderStatus(full, 'hevc_nvenc', probed: probed).state, VeAvailability.missing);
      final tested = encoderStatus(full, 'hevc_nvenc', probed: probed, test: failed);
      expect(tested.state, VeAvailability.failed);
      expect(tested.detail, contains('nvenc API'));
      expect(tested.test, same(failed));
      expect(
        encoderStatus(full, 'hevc_nvenc', probed: probed, test: failed, testing: true).state,
        VeAvailability.testing,
      );
    });
  });

  group('capability list', () {
    EncoderStatus Function(String) statusOf(String id) => statusLookup(inst(id), const FFmpegState());

    test('groups by codec in catalog order, with depth and where it runs', () {
      final groups = capabilityGroups(catalog, kind: EncoderKind.video, statusOf: statusOf('gyan-8.1'));
      expect(groups.first.name, 'H.264');
      final x264 = groups.first.rows.first;
      expect((x264.id, x264.label, x264.depth, x264.runsOn), ('libx264', 'x264', '8 or 10-bit', 'CPU'));
      final nvenc = groups.expand((g) => g.rows).singleWhere((r) => r.id == 'hevc_nvenc');
      expect(nvenc.runsOn, 'NVIDIA GeForce RTX 4070', reason: 'a passed test names the device');
      final qsv = groups.expand((g) => g.rows).singleWhere((r) => r.id == 'hevc_qsv');
      expect(qsv.runsOn, 'Intel GPU');
      expect(qsv.why, 'No Intel graphics device on this PC.');
      final audio = capabilityGroups(catalog, kind: EncoderKind.audio, statusOf: statusOf('gyan-8.1'));
      expect(audio.every((g) => g.name.endsWith(' audio')), isTrue);
      expect(audio.expand((g) => g.rows).every((r) => r.depth.isEmpty && r.runsOn == 'CPU'), isTrue);
    });

    test('filters: only problems, hardware, search', () {
      List<String> ids(CapabilityFilter filter, {String query = ''}) => [
        for (final g in capabilityGroups(
          catalog,
          kind: EncoderKind.video,
          statusOf: statusOf('btbn-lgpl-8.0'),
          filter: filter,
          query: query,
        ))
          ...g.rows.map((r) => r.id),
      ];
      expect(ids(CapabilityFilter.problems), ['libx264', 'h264_amf', 'libx265', 'hevc_qsv']);
      expect(ids(CapabilityFilter.hardware), everyElement(matches(RegExp(r'_(nvenc|qsv|amf)$'))));
      expect(ids(CapabilityFilter.all, query: 'nvenc'), ['h264_nvenc', 'hevc_nvenc', 'av1_nvenc']);
      expect(ids(CapabilityFilter.all, query: 'nvidia hevc'), ['hevc_nvenc']);
      expect(ids(CapabilityFilter.problems, query: 'av1'), isEmpty);
    });

    test('the summary counts encoders that aren’t ready', () {
      expect(
        problemSummary(catalog, 'FFmpeg 8.0 LGPL', statusOf('btbn-lgpl-8.0')),
        'FFmpeg 8.0 LGPL: 4 video and 1 audio encoders not ready',
      );
      expect(
        problemSummary(catalog, 'Everything', (_) => const EncoderStatus(VeAvailability.ready)),
        'Everything: every encoder is ready',
      );
    });
  });

  group('installation card', () {
    test('says what it is, where it came from and when it was checked', () {
      final card = installationCard(
        inst('gyan-8.1'),
        isDefault: true,
        state: const FFmpegState(),
        presets: presets,
        catalog: catalog,
      );
      expect(card.line, 'gyan.dev full build, GPL v3. Installed with winget.');
      expect(card.checked, startsWith('Checked 12 Oct 2026 in 2.14 s'));
      expect(card.counts, (video: 142, audio: 91, muxers: 181));
      expect(card.blocked, isEmpty);
      expect(card.progress, isNull);
    });

    test('an LGPL build lists the presets it can’t render and why', () {
      final card = installationCard(
        inst('btbn-lgpl-8.0'),
        isDefault: false,
        state: const FFmpegState(),
        presets: presets,
        catalog: catalog,
      );
      expect(card.blocked, ['YouTube upload, H.264']);
      expect(card.blockedNeeds, ['x264']);
    });

    test('a running probe shows its phase and count', () {
      final full = inst('gyan-8.1');
      final card = installationCard(
        full,
        isDefault: true,
        state: FFmpegState(
          probes: {full.id: ProbeProgress(installationId: full.id, phase: 'details', completed: 18, total: 25)},
        ),
        presets: presets,
        catalog: catalog,
      );
      expect(card.progress!.label, 'Reading encoders… 18 of 25');
      expect(card.progress!.fraction, closeTo(0.72, 1e-9));
    });
  });

  group('encoder detail', () {
    test('a failed hardware encoder: what it means, what to do, who uses it', () {
      final full = inst('gyan-8.1');
      final detail = encoderDetail(
        catalog,
        'hevc_qsv',
        installation: full,
        status: encoderStatus(full, 'hevc_qsv'),
        presets: presets,
      );
      expect(detail.meaning, contains('the test encode on this PC failed. No Intel graphics device'));
      expect(detail.advice, contains('test again after installing the driver'));
      expect(detail.showsTestEncode, isTrue);
      expect(detail.usedBy, isEmpty);
    });

    test('a missing software encoder names the build to add; used-by comes from the library', () {
      final lgpl = inst('btbn-lgpl-8.0');
      final detail = encoderDetail(
        catalog,
        'libx264',
        installation: lgpl,
        status: encoderStatus(lgpl, 'libx264'),
        presets: presets,
      );
      expect(detail.meaning, startsWith('Not in this build.'));
      expect(detail.advice, contains('add an FFmpeg build that includes it'));
      expect(detail.hardware, isFalse);
      expect(detail.usedBy.map((p) => p.id), ['yt-h264']);
    });
  });

  group('controller', () {
    late ProviderContainer container;
    late FakeMachineSettingsRepository machine;
    late FakeFFmpegDiscovery discovery;
    late FakeCapabilityCache cache;
    var disposed = false;
    const added = r'E:\Tools\ffmpeg-8.1\bin\ffmpeg.exe';

    FFmpegController controller() => container.read(ffmpegControllerProvider.notifier);
    FFmpegState state() => container.read(ffmpegControllerProvider);

    void start({FakeFFmpegDiscovery? withDiscovery, HardwareTests? tests, FFmpegProbe? probe}) {
      final extra = FFmpegInstallation.fromJson({
        ...inst('manual-7.1').toJson(),
        'id': 'manual-8.1',
        'label': 'FFmpeg 8.1 portable',
        'path': added,
        'identity': {...inst('manual-7.1').identity.toJson(), 'key': 'b0-fixture-manual-8.1'},
      });
      discovery = withDiscovery ?? FakeFFmpegDiscovery(additions: {added: extra});
      machine = FakeMachineSettingsRepository();
      cache = FakeCapabilityCache();
      container = ProviderContainer(
        overrides: [
          veCoreProvider.overrideWithValue(FakeVeCore()),
          servicesOverride(),
          ffmpegDiscoveryProvider.overrideWithValue(discovery),
          machineSettingsRepositoryProvider.overrideWithValue(machine),
          capabilityCacheProvider.overrideWithValue(cache),
          hardwareTestsProvider.overrideWithValue(tests ?? FakeHardwareTests()),
          ffmpegProbeProvider.overrideWithValue(probe ?? FakeFFmpegProbe()),
        ],
      );
      disposed = false;
      addTearDown(() {
        if (!disposed) container.dispose();
      });
      container.listen(ffmpegControllerProvider, (_, _) {});
    }

    test('Set as default saves C7 defaultFFmpegId at the next revision', () async {
      start();
      await controller().setDefault(inst('manual-7.1'));
      final saved = await machine.read();
      expect(saved.defaultFFmpegId, 'manual-7.1');
      expect(saved.revision, 1);
      expect(saved.installations.map((i) => i.id), ['gyan-8.1', 'manual-7.1', 'btbn-lgpl-8.0']);
    });

    test('Add FFmpeg… adds through discovery, checks and selects the new installation', () async {
      start();
      final installation = await controller().add(added);
      expect(installation.id, 'manual-8.1');
      expect((await discovery.list()).map((i) => i.id), contains('manual-8.1'));
      expect(
        (await machine.read()).revision,
        0,
        reason: 'discovery records installations in C7 itself (B3); the app writes nothing',
      );
      expect(await cache.read('b0-fixture-manual-8.1'), isNull, reason: 'the probe caches its own result, not the app');
      expect(state().selectedId, 'manual-8.1');
      expect(state().probes, isEmpty);
      expect(state().probed.keys, ['manual-8.1']);
    });

    test('Add FFmpeg… passes discovery’s refusal on, changing nothing', () async {
      start();
      await expectLater(
        controller().add(r'C:\nope\ffmpeg.exe'),
        throwsA(isA<ServiceException>().having((e) => e.code, 'code', 'B0-FIXTURE-MISSING')),
      );
      expect((await machine.read()).revision, 0);
    });

    test('the default can’t be removed; another one can', () async {
      start();
      await expectLater(
        controller().remove('gyan-8.1'),
        throwsA(isA<ServiceException>().having((e) => e.code, 'code', 'DEFAULT-IN-USE')),
      );
      controller().select('manual-7.1');
      await controller().remove('manual-7.1');
      expect((await discovery.list()).map((i) => i.id), isNot(contains('manual-7.1')));
      expect((await machine.read()).revision, 0, reason: 'discovery updates C7 itself');
      expect(state().selectedId, isNull);
    });

    test('Scan again leaves C7 to discovery and checks the uncached', () async {
      start(withDiscovery: FakeFFmpegDiscovery(scanResults: [inst('manual-7.1')]));
      final found = await controller().scan();
      expect(found.map((i) => i.id), ['manual-7.1']);
      final saved = await machine.read();
      expect(saved.revision, 0, reason: 'discovery keeps C7 and a vanished default itself (B3)');
      expect(saved.defaultFFmpegId, 'gyan-8.1');
      expect(state().probed.keys, contains('manual-7.1'), reason: 'not in the cache, so checked');
      expect(state().scanning, isFalse);
    });

    test('Scan again with nothing new writes nothing', () async {
      start();
      await controller().scan();
      expect((await machine.read()).revision, 0);
    });

    test('a failed check is kept for the card', () async {
      final probe = StalledProbe();
      start(probe: probe);
      final running = controller().probe(inst('gyan-8.1'));
      await Future<void>.delayed(Duration.zero);
      expect(state().probes['gyan-8.1']!.completed, 18);
      await probe.finish();
      await running;
      expect(state().probes, isEmpty);
      expect(state().probeFailures['gyan-8.1'], 'ffmpeg.exe stopped responding.');
    });

    test('hardware tests stream in; the encoders show Testing until then', () async {
      start();
      final full = inst('gyan-8.1');
      final hw = hardwareEncoderIds(catalog);
      final running = controller().testHardware(full, hardwareEncoders: hw);
      expect(state().testing['gyan-8.1'], hw.toSet());
      await running;
      expect(state().testing, isEmpty);
      final results = state().testResults['gyan-8.1']!;
      expect(results['hevc_qsv']!.state, 'failed');
      expect(results['hevc_nvenc']!.tenBit, isTrue);
      expect(statusLookup(full, state())('hevc_qsv').test, isNotNull);
    });

    test('leaving cancels work still running', () async {
      final tests = StalledHardwareTests();
      start(tests: tests);
      unawaited(controller().testHardware(inst('gyan-8.1'), hardwareEncoders: const ['hevc_nvenc']));
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      disposed = true;
      expect(tests.cancelled, ['gyan-8.1']);
    });
  });
}
