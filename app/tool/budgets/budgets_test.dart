// Measures the app's TECH_ARCHITECTURE §9.3 edit and library budgets on real
// data: the native core (B2), the Windows services (B3) on a temporary folder,
// a 500-preset file library, and a capability cache a real probe wrote on this
// PC. Not part of `flutter test`; run it on purpose:
//
//   $env:VE_BUDGET_CACHE = '<a capability cache .json written by a probe>'
//   flutter test tool/budgets/budgets_test.dart --reporter expanded
//
// Figures are from the flutter test VM (JIT), so they are an upper bound for
// the AOT release build. Results print as `BUDGET <name> ...` lines. No FFmpeg
// runs, nothing touches VEGAS or the user's own library and settings.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/app/launch.dart';
import 'package:vegas_encoder/features/presets/library_model.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/editor.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/preview.dart';
import 'package:vegas_encoder/state/recipe_edit.dart';
import 'package:vegas_encoder/state/services.dart';

void main() {
  final cacheFile = Platform.environment['VE_BUDGET_CACHE'];
  late NativeVeCore core;
  late Directory root;
  late ServicePaths paths;
  late FFmpegCapabilities capabilities;
  late FFmpegInstallation installation;

  setUpAll(() async {
    core = NativeVeCore();
    root = await Directory.systemTemp.createTemp('ve-budgets-');
    paths = ServicePaths(roaming: '${root.path}\\Roaming', local: '${root.path}\\Local');
    final envelope = jsonDecode(await File(cacheFile!).readAsString()) as Map<String, Object?>;
    capabilities = FFmpegCapabilities.fromJson(jsonMap(envelope['capabilities']));
    // The probe's cache file, as the real service would find it.
    await Directory(paths.cache).create(recursive: true);
    await File(cacheFile).copy('${paths.cache}\\${capabilities.identityKey}.json');
    final fixture = (await FakeFFmpegDiscovery().list()).first;
    installation = fixture.copyWith(
      id: capabilities.installationId,
      label: 'FFmpeg ${capabilities.version}',
      version: capabilities.version,
      identity: fixture.identity.copyWith(key: capabilities.identityKey),
    );
    final services = WindowsAppServices(() => core, paths: paths);
    final settings = await services.machineSettings.read();
    await services.machineSettings.save(
      settings.copyWith(installations: [installation], defaultFFmpegId: installation.id),
      expectedRevision: settings.revision,
    );
    // 500 presets: the six built-ins and 494 copies in Mine.
    final builtins = await services.library.list();
    for (var i = 0; i < 494; i++) {
      final source = builtins[i % builtins.length];
      await services.library.save(
        Preset(
          updatedAt: source.updatedAt,
          origin: 'builtin/${source.recipe.id}',
          requires: source.requires,
          recipe: source.recipe.copyWith(id: 'copy-$i', name: '${source.recipe.name} $i', tags: ['Client ${i % 37}']),
        ),
      );
    }
  });

  tearDownAll(() => root.delete(recursive: true));

  Future<ProviderContainer> start() async {
    final container = ProviderContainer(
      overrides: [
        veCoreProvider.overrideWithValue(core),
        launchModeProvider.overrideWithValue(const DesktopLaunch()),
        servicesProvider.overrideWith((ref) => WindowsAppServices(() => ref.read(veCoreProvider), paths: paths)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(presetsProvider, (_, _) {});
    container.listen(machineSettingsProvider, (_, _) {});
    container.listen(capabilitiesProvider(installation.id), (_, _) {});
    await container.read(presetsProvider.future);
    await container.read(machineSettingsProvider.future);
    expect(await container.read(capabilitiesProvider(installation.id).future), isNotNull);
    return container;
  }

  /// Median and 95th percentile of [runs] timings of [body], in ms, after
  /// [warmup] untimed runs.
  ({double median, double p95}) time(void Function(int i) body, {int runs = 60, int warmup = 10}) {
    for (var i = 0; i < warmup; i++) {
      body(i);
    }
    final ms = <double>[];
    for (var i = 0; i < runs; i++) {
      final watch = Stopwatch()..start();
      body(warmup + i);
      ms.add(watch.elapsedMicroseconds / 1000);
    }
    ms.sort();
    return (median: ms[ms.length ~/ 2], p95: ms[(ms.length * 0.95).floor().clamp(0, ms.length - 1)]);
  }

  void report(String name, ({double median, double p95}) t, String budget) =>
      print('BUDGET $name median ${t.median.toStringAsFixed(2)} ms, p95 ${t.p95.toStringAsFixed(2)} ms ($budget)');

  test('edit to updated command and checks (Basic)', () async {
    final container = await start();
    final controller = container.read(presetsControllerProvider.notifier)..select('yt-h264');
    container.listen(editorProvider, (_, _) {});
    final view = container.read(editorProvider)!.capabilities!;

    print(
      'BUDGET view: ${jsonEncode(view.data).length} chars for the Basic view, '
      '${jsonEncode(capabilities.toCoreCapabilities().data).length} for the full map',
    );
    container.listen(libraryEntriesProvider, (_, _) {});
    report(
      'basic edit, editor and library row (one shared compile + two estimates, Basic view)',
      time((i) {
        controller.edit((r) => r.withVideo((v) => v.copyWith(quality: 17 + i % 2)));
        container.read(editorProvider)!.compiled.value!;
        container.read(libraryEntriesProvider);
      }),
      '≤ 4 ms per change',
    );
    final split = {'edit': <double>[], 'editor': <double>[], 'library': <double>[]};
    for (var i = 0; i < 60; i++) {
      final w = Stopwatch()..start();
      controller.edit((r) => r.withVideo((v) => v.copyWith(quality: 17 + i % 2)));
      split['edit']!.add(w.elapsedMicroseconds / 1000);
      w.reset();
      container.read(editorProvider)!.compiled.value!;
      split['editor']!.add(w.elapsedMicroseconds / 1000);
      w.reset();
      container.read(libraryEntriesProvider);
      split['library']!.add(w.elapsedMicroseconds / 1000);
    }
    for (final e in split.entries) {
      final ms = e.value..sort();
      print('BUDGET   split ${e.key} median ${ms[30].toStringAsFixed(2)} ms');
    }
    final edited = container.read(editorProvider)!;
    report(
      '  of which compile (Basic view)',
      time(
        (i) => core.compile(
          edited.recipe.withVideo((v) => v.copyWith(quality: 17 + i % 2)),
          media: SamplePreview.media,
          paths: SamplePreview.paths('mp4'),
          capabilities: edited.capabilities,
        ),
      ),
      'part of the edit',
    );
    report(
      '  of which the two estimates',
      time((i) {
        core.estimate(edited.recipe, media: SamplePreview.media);
        core.estimate(edited.recipe, media: SamplePreview.media, durationSec: 600);
      }),
      'part of the edit',
    );
    final recipe = container.read(editorProvider)!.recipe;
    final full = capabilities.toCoreCapabilities(label: installation.label);
    report(
      'basic compile with the full map (before F7)',
      time(
        (i) => core.compile(recipe, media: SamplePreview.media, paths: SamplePreview.paths('mp4'), capabilities: full),
      ),
      'for comparison',
    );
  });

  test('edit to updated command and checks (Advanced)', () async {
    final container = await start();
    final controller = container.read(presetsControllerProvider.notifier)..select('yt-h264');
    container.listen(editorProvider, (_, _) {});
    final seed = container.read(editorProvider)!.compiled.value!.advancedTemplate;
    controller.setMode(advanced: true, template: seed);
    report(
      'advanced keystroke (lint + compile + Basic compile, full map)',
      time((i) {
        controller.setTemplate('$seed${i.isEven ? ' ' : ''}');
        container.read(editorProvider)!.compiled;
      }),
      '≤ 4 ms per change',
    );
  });

  test('library of 500 presets', () async {
    final container = await start();
    container.listen(libraryEntriesProvider, (_, _) {});
    final controller = container.read(presetsControllerProvider.notifier)..select('copy-0');
    expect(container.read(libraryEntriesProvider), hasLength(500));
    report(
      'library rows after an edit (one row recompiled)',
      time((i) {
        controller.edit((r) => r.withVideo((v) => v.copyWith(quality: 17 + i % 2)));
        container.read(libraryEntriesProvider);
      }),
      'part of the 4 ms edit',
    );
    // Every row compiled, as each edit did before F7: a fresh container has
    // no row cache. Only building the rows is timed.
    final scratch = <double>[];
    for (var i = 0; i < 4; i++) {
      final fresh = await start();
      final watch = Stopwatch()..start();
      fresh.listen(libraryEntriesProvider, (_, _) {});
      expect(fresh.read(libraryEntriesProvider), hasLength(500));
      scratch.add(watch.elapsedMicroseconds / 1000);
      fresh.dispose();
    }
    scratch.sort();
    print(
      'BUDGET library rows built from scratch (500 compiles; each edit before F7) median '
      '${scratch[scratch.length ~/ 2].toStringAsFixed(0)} ms (for comparison)',
    );
    final entries = container.read(libraryEntriesProvider);
    const queries = ['h264', 'client 12', 'prores 4', 'av1 small 3', 'zzz'];
    report('search 500 presets', time((i) => groupLibrary(entries, query: queries[i % queries.length])), '< 150 ms');
    report('group 500 presets, no search', time((i) => groupLibrary(entries)), '60 fps scrolling needs < 16 ms');
  });

  test('one library watch tick (the file library re-reads every preset each 250 ms)', () async {
    final services = WindowsAppServices(() => core, paths: paths);
    final ms = <double>[];
    for (var i = 0; i < 12; i++) {
      final watch = Stopwatch()..start();
      final list = await services.library.list();
      ms.add(watch.elapsedMicroseconds / 1000);
      expect(list, hasLength(500));
    }
    ms
      ..removeRange(0, 2)
      ..sort();

    print(
      'BUDGET library list() for 500 presets median ${ms[ms.length ~/ 2].toStringAsFixed(1)} ms, '
      'max ${ms.last.toStringAsFixed(1)} ms (every 250 ms while the library is watched, on the UI isolate)',
    );
  });
}
