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
  final settings = await FileMachineSettingsRepository(paths: paths).read();
  final cache = GpuAwareCapabilityCache(
    backend: FileCapabilityCache(paths: paths, parserVersion: 2),
    gpu: WindowsGpuIdentity(),
  );
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
    final recipe = recipes.firstWhere((r) => r.id == 'ffv1-master');
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

    final report = <String, Object?>{
      'version': installation.version,
      'calls': 50,
      'fullBytes': utf8.encode(jsonEncode(full.data)).length,
      'basicBytes': utf8.encode(jsonEncode(compact.data)).length,
      'fullMeanMs': benchmark(full),
      'basicMeanMs': benchmark(compact),
    };
    reports.add(report);
    print(jsonEncode(report));
  }
  check(reports.isNotEmpty, 'completed real probe caches');
  await File(joinPath(root.path, 'view-timings.json')).writeAsString(
    const JsonEncoder.withIndent(
      '  ',
    ).convert({'checks': checks, 'builds': reports}),
  );
  print(
    'B3 CAPABILITY VIEWS PASSED: $checks native parity/reuse checks on real probe caches. No FFmpeg process, fake host or VEGAS.',
  );
}
