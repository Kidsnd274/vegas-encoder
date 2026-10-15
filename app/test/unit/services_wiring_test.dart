import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/app/launch.dart';
import 'package:vegas_encoder/features/presets/library_model.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/editor.dart';
import 'package:vegas_encoder/state/monitor.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/recipe_edit.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';
import '../monitor_doubles.dart';

/// F7: the app on the platform's Windows services (B3). The real services run
/// on a temporary folder, never the user's `%APPDATA%`; the native core
/// (B2). No FFmpeg runs and nothing touches VEGAS.
void main() {
  late NativeVeCore core;
  setUpAll(() => core = NativeVeCore());

  group('Windows services', () {
    late Directory root;
    late ServicePaths paths;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('ve-app-services-');
      paths = ServicePaths(roaming: '${root.path}\\Roaming', local: '${root.path}\\Local');
    });
    tearDown(() => root.delete(recursive: true));

    /// A container like the app's: the native core and the Windows services
    /// on [paths].
    Future<ProviderContainer> start({LaunchMode mode = const DesktopLaunch()}) async {
      final container = ProviderContainer(
        overrides: [
          veCoreProvider.overrideWithValue(core),
          launchModeProvider.overrideWithValue(mode),
          servicesProvider.overrideWith((ref) => WindowsAppServices(() => ref.read(veCoreProvider), paths: paths)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(presetsProvider, (_, _) {});
      container.listen(machineSettingsProvider, (_, _) {});
      await container.read(presetsProvider.future);
      await container.read(machineSettingsProvider.future);
      return container;
    }

    test('the providers are the platform\'s Windows services', () async {
      final container = await start();
      expect(container.read(presetLibraryProvider), isA<FilePresetLibrary>());
      expect(container.read(presetPreferencesProvider), isA<FilePresetLibrary>());
      expect(container.read(machineSettingsRepositoryProvider), isA<FileMachineSettingsRepository>());
      expect(container.read(ffmpegDiscoveryProvider), isA<WindowsFFmpegDiscovery>());
      expect(container.read(ffmpegProbeProvider), isA<WindowsFFmpegProbe>());
      expect(container.read(hardwareTestsProvider), isA<WindowsHardwareTests>());
      expect(container.read(jobRepositoryProvider), isA<FileJobRepository>());
      expect(container.read(jobLogsProvider), isA<FileJobRepository>());
      expect(container.read(fileRevealProvider), isA<WindowsFileReveal>());
      expect(container.read(liveStatusReaderProvider), isA<FileLiveRenderStatusReader>());
      expect(container.read(editSessionServiceProvider), isA<FileEditSessionService>());
      expect(container.read(servicesProvider).paths!.roaming, paths.roaming);

      final presets = container.read(presetsProvider).value!;
      expect(presets.where((p) => p.builtin).map((p) => p.recipe.id), [
        'yt-h264',
        'yt-hevc-nv',
        'av1-small',
        'prores-hq',
        'dnxhr-hq',
        'ffv1-master',
      ]);
      expect(await Directory(paths.roaming).exists(), isFalse, reason: 'reading writes nothing');
    });

    test('a star on a built-in survives a restart', () async {
      var container = await start();
      await container.read(presetsControllerProvider.notifier).toggleFavorite('av1-small');
      container.dispose();

      container = await start();
      final av1 = container.read(presetsProvider).value!.firstWhere((p) => p.recipe.id == 'av1-small');
      expect(av1.favorite, isTrue);
      expect(av1.revision, 1, reason: 'a built-in\'s revision never moves');
      expect(await File(paths.preferences).exists(), isTrue);
    });

    test('a copy is a file in the library with its C3 origin', () async {
      final container = await start();
      final created = (await container.read(presetsControllerProvider.notifier).duplicate('yt-h264'))!;
      expect(created.origin, 'builtin/yt-h264');
      expect(created.favorite, isFalse);
      expect(await File('${paths.library}\\${created.recipe.id}.vepreset').exists(), isTrue);
      expect(created.requires.encoders, ['libx264', 'aac'], reason: 'the library derives requirements (core)');
    });

    test('the library refuses a recipe with errors and says why; nothing is written', () async {
      final container = await start();
      final controller = container.read(presetsControllerProvider.notifier);
      final copy = (await controller.duplicate('yt-h264'))!;
      controller.select(copy.recipe.id);
      controller.edit((r) => r.withVideo((v) => v.copyWith(quality: 99)));
      final edited = controller.working(copy.recipe.id)!;
      expect(core.validate(edited).where((i) => i.level == IssueLevel.error), isNotEmpty);

      await expectLater(
        controller.save(),
        throwsA(isA<ServiceException>().having((e) => e.code, 'code', 'RECIPE-INVALID')),
      );
      expect((await container.read(presetLibraryProvider).get(copy.recipe.id))!.revision, 1);
      expect(container.read(presetsControllerProvider).drafts, contains(copy.recipe.id), reason: 'the draft stays');
    });

    test('the editor checks against the cached capabilities through a Basic view', () async {
      final fixture = (await FakeFFmpegDiscovery().list()).firstWhere((i) => i.id == 'gyan-8.1');
      // The fake probe's capabilities, as the production parser version the
      // real cache accepts.
      final capabilities = (await FakeFFmpegProbe().probe(fixture).last).capabilities!.copyWith(
        parser: WindowsFFmpegHelpParser().version,
      );
      final container = await start();
      await container.read(capabilityCacheProvider).write(capabilities);
      final repository = container.read(machineSettingsRepositoryProvider);
      final settings = await repository.read();
      await repository.save(
        settings.copyWith(installations: [fixture], defaultFFmpegId: fixture.id),
        expectedRevision: settings.revision,
      );
      // The settings file is polled (250 ms); read it again now.
      container.invalidate(machineSettingsProvider);
      await container.read(machineSettingsProvider.future);
      await container.read(capabilitiesProvider(fixture.id).future);
      container.read(presetsControllerProvider.notifier).select('yt-h264');

      final data = container.read(editorProvider)!;
      final encoders = data.capabilities!.encoders;
      expect(encoders.keys, containsAll(['libx264', 'hevc_nvenc']));
      expect(encoders['libx264'], contains('options'), reason: 'the recipe\'s own encoder keeps its options');
      expect(encoders['hevc_nvenc'], isNot(contains('options')), reason: 'others keep name and availability only');
      expect(data.compiled.ok, isTrue);
    });

    test('the progress window reads its live file and the pin without loading the core', () async {
      final live = '${root.path}\\b0-render.live.json';
      await File(live).writeAsString(jsonEncode(liveSample(RenderState.encoding).toJson()));
      final settings = FileMachineSettingsRepository(paths: paths);
      final current = await settings.read();
      await settings.save(current.copyWith(keepOnTop: true), expectedRevision: current.revision);

      var coreLoads = 0;
      final container = ProviderContainer(
        overrides: [
          launchModeProvider.overrideWithValue(RenderMonitorLaunch(live)),
          veCoreProvider.overrideWith((ref) {
            coreLoads++;
            return core;
          }),
          servicesProvider.overrideWith((ref) => WindowsAppServices(() => ref.read(veCoreProvider), paths: paths)),
        ],
      );
      addTearDown(container.dispose);

      expect(await monitorPlacement(container, live), (host: 123456, keepOnTop: true));
      container.listen(liveRenderStatusProvider, (_, _) {});
      container.listen(machineSettingsProvider, (_, _) {});
      expect((await container.read(liveRenderStatusProvider.future))?.framesDone, 7400);
      expect((await container.read(machineSettingsProvider.future)).keepOnTop, isTrue);
      expect(coreLoads, 0, reason: 'while VEGAS renders the window reads two small files and nothing else');
    });
  });

  group('fake services', () {
    test('under flutter test the real services refuse to build', () {
      final container = ProviderContainer(overrides: [coreOverride()]);
      addTearDown(container.dispose);
      expect(() => container.read(servicesProvider), throwsA(predicate((e) => '$e'.contains('servicesOverride'))));
    });

    test('the popup reads cached capabilities but never probes', () async {
      final probe = _CountingProbe();
      Future<FFmpegCapabilities?> read(LaunchMode mode) async {
        final container = testContainer(
          overrides: [launchModeProvider.overrideWithValue(mode), ffmpegProbeProvider.overrideWithValue(probe)],
        );
        addTearDown(container.dispose);
        container.listen(machineSettingsProvider, (_, _) {});
        return container.read(capabilitiesProvider('gyan-8.1').future);
      }

      expect(await read(const EditSessionLaunch('b0-session')), isNull, reason: 'not cached: unknown');
      expect(probe.calls, 0);
      expect(await read(const DesktopLaunch()), isNotNull, reason: 'the desktop checks it once');
      expect(probe.calls, 1);
    });

    test('an edit recompiles only the edited preset\'s library row', () async {
      final counting = _CountingCore(core);
      final container = testContainer(core: counting);
      addTearDown(container.dispose);
      container.listen(presetsProvider, (_, _) {});
      container.listen(machineSettingsProvider, (_, _) {});
      container.listen(capabilitiesProvider('gyan-8.1'), (_, _) {});
      container.listen(libraryEntriesProvider, (_, _) {});
      await container.read(presetsProvider.future);
      await container.read(machineSettingsProvider.future);
      await container.read(capabilitiesProvider('gyan-8.1').future);
      counting.compiles = 0;
      final first = container.read(libraryEntriesProvider);
      expect(counting.compiles, first.length, reason: 'each row compiled once');

      counting.compiles = 0;
      final controller = container.read(presetsControllerProvider.notifier)..select('yt-h264');
      controller.edit((r) => r.withVideo((v) => v.copyWith(quality: 20)));
      final rows = container.read(libraryEntriesProvider);
      expect(counting.compiles, 1, reason: 'only the edited row');
      expect(rows.firstWhere((e) => e.id == 'yt-h264').dirty, isTrue);
      expect(
        identical(rows.firstWhere((e) => e.id == 'av1-small'), first.firstWhere((e) => e.id == 'av1-small')),
        isTrue,
      );

      counting.compiles = 0;
      controller.setQuery('av1');
      container.read(libraryEntriesProvider);
      expect(counting.compiles, 0, reason: 'search reuses the rows');
    });

    test('the editor and the edited row share one compile per edit', () async {
      final counting = _CountingCore(core);
      final container = testContainer(core: counting);
      addTearDown(container.dispose);
      container.listen(presetsProvider, (_, _) {});
      container.listen(machineSettingsProvider, (_, _) {});
      container.listen(capabilitiesProvider('gyan-8.1'), (_, _) {});
      container.listen(libraryEntriesProvider, (_, _) {});
      container.listen(editorProvider, (_, _) {});
      await container.read(presetsProvider.future);
      await container.read(machineSettingsProvider.future);
      await container.read(capabilitiesProvider('gyan-8.1').future);
      final controller = container.read(presetsControllerProvider.notifier)..select('yt-h264');
      container.read(editorProvider);
      container.read(libraryEntriesProvider);

      counting.compiles = 0;
      controller.edit((r) => r.withVideo((v) => v.copyWith(quality: 21)));
      final data = container.read(editorProvider)!;
      final row = container.read(libraryEntriesProvider).firstWhere((e) => e.id == 'yt-h264');
      expect(counting.compiles, 1);
      expect(row.dirty, isTrue);
      expect(data.compiled.value!.commandLine, contains('-crf 21'));
    });
  });
}

class _CountingProbe extends FakeFFmpegProbe {
  int calls = 0;
  @override
  Stream<ProbeProgress> probe(FFmpegInstallation installation) {
    calls++;
    return super.probe(installation);
  }
}

/// The native core, counting compiles.
class _CountingCore implements VeCore {
  _CountingCore(this._core);
  final VeCore _core;
  int compiles = 0;

  @override
  CompileResult compile(
    Recipe recipe, {
    required MediaDescription media,
    required CompilePaths paths,
    CoreCapabilities? capabilities,
  }) {
    compiles++;
    return _core.compile(recipe, media: media, paths: paths, capabilities: capabilities);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Function.apply(
    switch (invocation.memberName) {
      #version => () => _core.version,
      #profiles => _core.profiles,
      #normalize => _core.normalize,
      #validate => _core.validate,
      #lint => _core.lint,
      #complete => _core.complete,
      #estimate => _core.estimate,
      #diff => _core.diff,
      #encodePayload => _core.encodePayload,
      #decodePayload => _core.decodePayload,
      _ => throw UnimplementedError('${invocation.memberName}'),
    },
    invocation.positionalArguments,
    invocation.namedArguments,
  );
}
