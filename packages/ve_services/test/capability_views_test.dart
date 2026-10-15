import 'dart:convert';
import 'dart:io';
import 'package:ve_services/ve_services.dart';
import 'package:ve_services/src/storage.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1)
    throw ArgumentError('Pass a completed B3 runtime data root.');
  final root = Directory(args.single).absolute;
  final paths = ServicePaths(
    roaming: joinPath(root.path, 'roaming'),
    local: joinPath(root.path, 'local'),
  );
  final core = NativeVeCore();
  final uncached = NativeVeCore(cacheCapabilities: false);
  final settings = await FileMachineSettingsRepository(paths: paths).read();
  final cache = FileCapabilityCache(paths: paths, parserVersion: 2);
  final recipes = (await FilePresetLibrary(
    core: core,
    paths: paths,
  ).list()).map((p) => p.recipe).toList();
  final media = MediaDescription(
    video: VideoMedia(width: 320, height: 180, fps: [30, 1], pixfmt: 'p010le'),
    audio: AudioMedia(rate: 48000, channels: 2, sampleFmt: 'f32le'),
    durationSec: 2,
  );
  var checks = 0;
  void check(bool ok, String message) {
    checks++;
    if (!ok) throw StateError(message);
  }

  final reports = <JsonMap>[];
  for (final installation in settings.installations) {
    final caps = (await cache.read(installation.identity.key))!;
    final full = caps.toCoreCapabilities(label: installation.label);
    final compilePaths = CompilePaths(
      ffmpeg: installation.path,
      videoPipe: 'video',
      audioPipe: 'audio',
      output: 'output.mkv',
    );
    final cases = [
      ...recipes,
      for (final recipe in recipes)
        recipe.copyWith(video: recipe.video.copyWith(extra: '-g 90')),
      for (final recipe in recipes)
        recipe.copyWith(audio: [recipe.audio.first.copyWith(enabled: false)]),
    ];
    for (final recipe in cases) {
      final compact = caps.toCoreCapabilities(
        label: installation.label,
        recipe: recipe,
      );
      final expected = core.compile(
        recipe,
        media: media,
        paths: compilePaths,
        capabilities: full,
      );
      final actual = core.compile(
        recipe,
        media: media,
        paths: compilePaths,
        capabilities: compact,
      );
      check(
        canonicalJson(actual.data) == canonicalJson(expected.data),
        '${installation.version}: compact/full compile parity for ${recipe.id}',
      );
    }
    final recipe = recipes.firstWhere((r) => r.id == 'yt-h264');
    final seed = core
        .compile(recipe, media: media, paths: compilePaths, capabilities: full)
        .advancedTemplate;
    final advanced = recipe.copyWith(
      command: CommandSettings(mode: 'template', template: seed),
    );
    check(
      identical(
        full,
        caps.toCoreCapabilities(label: installation.label, recipe: advanced),
      ),
      'Advanced retains the full immutable capability view',
    );
    final compact = caps.toCoreCapabilities(
      label: installation.label,
      recipe: recipe,
    );
    check(
      identical(
        compact,
        caps.toCoreCapabilities(
          label: installation.label,
          recipe: recipe.copyWith(name: 'edited'),
        ),
      ),
      'Basic edits reuse the immutable capability view',
    );
    double benchmark(CoreCapabilities view) {
      core.compile(
        recipe,
        media: media,
        paths: compilePaths,
        capabilities: view,
      );
      final elapsed = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        core.compile(
          recipe,
          media: media,
          paths: compilePaths,
          capabilities: view,
        );
      }
      return elapsed.elapsedMicroseconds / 50000;
    }

    // Same native asset and full real maps, including the app's Basic compile.
    void edit(NativeVeCore engine, int i) {
      final draft = advanced.copyWith(
        command: advanced.command.copyWith(
          template: seed.replaceFirst(
            '\n{output}',
            '\n-metadata comment=edit$i\n{output}',
          ),
        ),
      );
      engine.lint(draft.command.template, capabilities: full);
      engine.compile(
        draft,
        media: media,
        paths: compilePaths,
        capabilities: full,
      );
      engine.compile(
        recipe,
        media: media,
        paths: compilePaths,
        capabilities: compact,
      );
    }

    final expected = uncached.compile(
      advanced,
      media: media,
      paths: compilePaths,
      capabilities: full,
    );
    check(
      canonicalJson(
            core
                .compile(
                  advanced,
                  media: media,
                  paths: compilePaths,
                  capabilities: full,
                )
                .data,
          ) ==
          canonicalJson(expected.data),
      'snapshot/inline Advanced compile parity',
    );
    check(
      canonicalJson(
            core.lint(seed, capabilities: full).map((d) => d.data).toList(),
          ) ==
          canonicalJson(
            uncached.lint(seed, capabilities: full).map((d) => d.data).toList(),
          ),
      'snapshot/inline lint parity',
    );
    check(
      canonicalJson(
            core
                .validate(advanced, media: media, capabilities: full)
                .map((d) => d.data)
                .toList(),
          ) ==
          canonicalJson(
            uncached
                .validate(advanced, media: media, capabilities: full)
                .map((d) => d.data)
                .toList(),
          ),
      'snapshot/inline validate parity',
    );
    check(
      canonicalJson(
            core
                .complete(
                  seed + ' -c:v ',
                  (seed + ' -c:v ').length,
                  capabilities: full,
                )
                .data,
          ) ==
          canonicalJson(
            uncached
                .complete(
                  seed + ' -c:v ',
                  (seed + ' -c:v ').length,
                  capabilities: full,
                )
                .data,
          ),
      'snapshot/inline completion parity',
    );
    Map<String, Object?> editBenchmark(NativeVeCore engine) {
      engine.clearCapabilitiesCache();
      final cold = Stopwatch()..start();
      edit(engine, 0);
      cold.stop();
      for (var i = 0; i < 25; i++) edit(engine, i);
      final times = <double>[];
      for (var i = 0; i < 100; i++) {
        final watch = Stopwatch()..start();
        edit(engine, i);
        watch.stop();
        times.add(watch.elapsedMicroseconds / 1000);
      }
      times.sort();
      return {
        'firstEditMs': cold.elapsedMicroseconds / 1000,
        'samples': times.length,
        'meanMs': times.reduce((a, b) => a + b) / times.length,
        'medianMs': times[50],
        'p95Ms': times[94],
      };
    }

    final inlineEdit = editBenchmark(uncached);
    final snapshotEdit = editBenchmark(core);
    final report = <String, Object?>{
      'version': installation.version,
      'advancedInlineEdit': inlineEdit,
      'advancedSnapshotEdit': snapshotEdit,
      'calls': 50,
      'fullBytes': utf8.encode(jsonEncode(full.data)).length,
      'basicBytes': utf8.encode(jsonEncode(compact.data)).length,
      'fullMeanMs': benchmark(full),
      'basicMeanMs': benchmark(compact),
    };
    reports.add(report);
    print(jsonEncode(report));
  }
  core.clearCapabilitiesCache();
  check(reports.isNotEmpty, 'completed real probe caches');
  await File(joinPath(root.path, 'snapshot-timings.json')).writeAsString(
    const JsonEncoder.withIndent(
      '  ',
    ).convert({'checks': checks, 'builds': reports}),
  );
  print(
    'B3 CAPABILITY VIEWS PASSED: $checks native parity/reuse checks on real probe caches. No FFmpeg process, fake host or VEGAS.',
  );
}
