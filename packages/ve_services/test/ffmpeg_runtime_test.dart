import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ve_services/ve_services.dart';
import 'package:ve_services/src/storage.dart';

int checks = 0;
void check(bool ok, String message) {
  checks++;
  if (!ok) throw StateError(message);
}

Future<void> main(List<String> args) async {
  if (args.isEmpty)
    throw StateError(
      'Pass explicit, user-supplied Windows FFmpeg executable paths.',
    );
  final base = Directory('../../build/test-results').absolute;
  await base.create(recursive: true);
  final root = await base.createTemp('b3-runtime-');
  final paths = ServicePaths(
    roaming: joinPath(root.path, 'roaming'),
    local: joinPath(root.path, 'local'),
  );
  final core = NativeVeCore();
  final runner = WindowsProcessExecutor();
  final services = WindowsServices(
    core: core,
    paths: paths,
    executor: runner,
    candidateFinder: FakeFFmpegCandidateFinder([]),
  );
  final reports = <JsonMap>[];
  try {
    for (final path in args) {
      print('Checking supplied FFmpeg: $path');
      final added = await services.discovery.add(path);
      print('Identity: ${added.version} / ${added.identity.key}');
      final progress = <ProbeProgress>[];
      var lastPhase = '';
      final elapsed = Stopwatch()..start();
      await for (final event in services.probe.probe(added)) {
        progress.add(event);
        if (lastPhase != event.phase) {
          print('  probe ${event.phase} (${elapsed.elapsedMilliseconds} ms)');
          lastPhase = event.phase;
        }
        if (event.phase == 'hardware' && event.message.contains(': '))
          print('  ${event.message}');
      }
      check(
        progress.last.phase == 'done',
        'real probe failed: ${progress.last.message}',
      );
      final installation = (await services.discovery.list()).firstWhere(
        (i) => i.id == added.id,
      );
      final capabilities = progress.last.capabilities!;
      check(
        installation.probedAt != null && installation.health == 'unchanged',
        'durable real probe record',
      );
      check(
        capabilities.encoders.containsKey('libx264') &&
            capabilities.encoders.containsKey('ffv1') &&
            capabilities.muxers.containsKey('matroska'),
        'real software/container facts',
      );
      check(
        capabilities.hardware.values.every(
          (v) => ['ok', 'failed', 'missing'].contains(jsonMap(v)['state']),
        ),
        'hardware facts come from completed real tests',
      );
      final available = (await services.capabilityCache.read(
        installation.identity.key,
      ))!;
      final nativeCapabilities = available.toCoreCapabilities(
        label: installation.label,
      );
      final recipes = (await services.library.list())
          .map((p) => p.recipe)
          .toList();
      for (final recipe in recipes) {
        final full = core.compile(
          recipe,
          media: MediaDescription(
            video: VideoMedia(
              width: 320,
              height: 180,
              fps: [30, 1],
              pixfmt: 'p010le',
            ),
            audio: AudioMedia(rate: 48000, channels: 2, sampleFmt: 'f32le'),
          ),
          paths: CompilePaths(
            ffmpeg: installation.path,
            videoPipe: 'video',
            audioPipe: 'audio',
            output: 'output.mkv',
          ),
          capabilities: nativeCapabilities,
        );
        final compact = core.compile(
          recipe,
          media: MediaDescription(
            video: VideoMedia(
              width: 320,
              height: 180,
              fps: [30, 1],
              pixfmt: 'p010le',
            ),
            audio: AudioMedia(rate: 48000, channels: 2, sampleFmt: 'f32le'),
          ),
          paths: CompilePaths(
            ffmpeg: installation.path,
            videoPipe: 'video',
            audioPipe: 'audio',
            output: 'output.mkv',
          ),
          capabilities: available.toCoreCapabilities(
            recipe: recipe,
            label: installation.label,
          ),
        );
        check(
          canonicalJson(full.data) == canonicalJson(compact.data),
          'compact capability view preserves all native compile facts for ${recipe.id}',
        );
      }
      final lossless = recipes.firstWhere((r) => r.id == 'ffv1-master');
      final media = MediaDescription(
        video: VideoMedia(
          width: 320,
          height: 180,
          fps: [30, 1],
          pixfmt: 'p010le',
        ),
        audio: AudioMedia(rate: 48000, channels: 2, sampleFmt: 'f32le'),
        durationSec: 2,
      );
      final previewPaths = CompilePaths(
        ffmpeg: installation.path,
        videoPipe: 'video',
        audioPipe: 'audio',
        output: 'output.mkv',
      );
      final preview = core.compile(
        lossless,
        media: media,
        paths: previewPaths,
        capabilities: nativeCapabilities,
      );
      final compact = available.toCoreCapabilities(
        recipe: lossless,
        label: installation.label,
      );
      check(
        identical(
          compact,
          available.toCoreCapabilities(
            recipe: lossless.copyWith(name: 'edited'),
            label: installation.label,
          ),
        ),
        'immutable capability views are reused across Basic edits',
      );
      final fullBytes = utf8.encode(jsonEncode(nativeCapabilities.data)).length;
      final compactBytes = utf8.encode(jsonEncode(compact.data)).length;
      double benchmark(CoreCapabilities view) {
        final watch = Stopwatch()..start();
        for (var i = 0; i < 50; i++) {
          core.compile(
            lossless,
            media: media,
            paths: previewPaths,
            capabilities: view,
          );
        }
        return watch.elapsedMicroseconds / 50000;
      }

      final fullMeanMs = benchmark(nativeCapabilities);
      final basicMeanMs = benchmark(compact);
      print(
        '  warm compile, full $fullBytes bytes: ${fullMeanMs.toStringAsFixed(3)} ms; Basic $compactBytes bytes: ${basicMeanMs.toStringAsFixed(3)} ms (50 calls)',
      );
      check(
        preview.expectedStreams?.map((s) => s.codec).join(',') ==
            'ffv1,pcm_f32le',
        'native verification facts',
      );
      final cases = [
        ...recipes,
        lossless.copyWith(
          id: 'video-only',
          audio: [lossless.audio.first.copyWith(enabled: false)],
        ),
        lossless.copyWith(
          id: 'advanced-seed',
          command: CommandSettings(
            mode: 'template',
            template: preview.advancedTemplate,
          ),
        ),
      ];
      final results = <JsonMap>[];
      for (final recipe in cases) {
        print('  preset ${recipe.id}');
        final phases = <PresetTestProgress>[];
        await for (final event in services.presetTests.test(
          recipe,
          installation,
        )) {
          phases.add(event);
        }
        final result = phases.last;
        // Bundled hardware recipes can outlive a supplied FFmpeg build/GPU.
        // Exercise their explicit refusal rather than calling it an encode pass.
        final blockedEncoders =
            [
              recipe.video.encoder,
              if (recipe.audio.first.enabled) recipe.audio.first.encoder,
            ].where((name) {
              if (!nativeCapabilities.encoders.containsKey(name)) return true;
              final encoder = jsonMap(nativeCapabilities.encoders[name]);
              final availability = jsonMap(encoder['availability'] ?? {});
              return ['missing', 'failed'].contains(availability['state']);
            }).toList();
        if (blockedEncoders.isNotEmpty) {
          check(
            result.phase == 'failed' &&
                !phases.any((p) => p.phase == 'encoding'),
            'unavailable encoders fail before encoding: ${recipe.id}',
          );
          results.add({
            'recipe': recipe.id,
            'phase': result.phase,
            'notEncoded': true,
            'unavailableEncoders': blockedEncoders,
          });
          continue;
        }
        check(
          result.phase == 'done',
          '${installation.version} ${recipe.id}: ${result.phase} ${result.message}',
        );
        check(
          result.verification?.state == 'passed' &&
              result.commandLine != null &&
              result.logPath != null,
          'verified result and full log',
        );
        check(
          phases.any((p) => p.phase == 'encoding') &&
              phases.any((p) => p.phase == 'verifying') &&
              phases.any((p) => p.log.isNotEmpty),
          'encode/verify/log stream',
        );
        final probe = await runner.run(installation.ffprobePath, [
          '-v',
          'error',
          '-count_frames',
          '-show_streams',
          '-of',
          'json',
          result.outputPath!,
        ]);
        probe.requireSuccess('Runtime test readback');
        final streams = jsonMaps(decodeJson(probe.stdout)['streams']);
        check(
          streams.firstWhere(
                (s) => s['codec_type'] == 'video',
              )['nb_read_frames'] ==
              '60',
          '60 source frames remain after encoding, including the 720p resize',
        );
        results.add({
          'recipe': recipe.id,
          'phase': result.phase,
          'verification': result.verification!.data,
          'frames': result.framesDone,
          'commandLine': result.commandLine,
        });
      }
      // Stop before generation/encoding; the terminal phase cannot imply success.
      late StreamSubscription<PresetTestProgress> subscription;
      final stopped = Completer<void>();
      subscription = services.presetTests.test(lossless, installation).listen((
        event,
      ) {
        if (event.phase == 'preparing' && !stopped.isCompleted) {
          unawaited(
            services.presetTests.cancel(event.testId).then((_) {
              stopped.complete();
            }),
          );
        }
      });
      await stopped.future;
      await subscription.cancel();
      check(
        runner.pool.active == 0,
        'preset cancellation releases all owned process slots',
      );
      // Cached readiness and the selected build identity survive repository recreation.
      final reopened = WindowsServices(
        core: core,
        paths: paths,
        executor: runner,
        candidateFinder: FakeFFmpegCandidateFinder([]),
      );
      check(
        (await reopened.capabilityCache.read(installation.identity.key)) !=
            null,
        'real capability cache survives recreation',
      );
      reports.add({
        'version': installation.version,
        'libavformatMajor': capabilities.libavformatMajor,
        'probeMs': installation.probeMs,
        'counts': installation.counts,
        'hardware': capabilities.hardware,
        'compileTiming': {
          'calls': 50,
          'fullBytes': fullBytes,
          'basicBytes': compactBytes,
          'fullMeanMs': fullMeanMs,
          'basicMeanMs': basicMeanMs,
        },
        'results': results,
      });
    }
    await File(joinPath(root.path, 'summary.json')).writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'checks': checks, 'builds': reports}),
    );
    final encoded = reports.fold<int>(
      0,
      (count, report) =>
          count +
          jsonMaps(report['results']).where((r) => r['phase'] == 'done').length,
    );
    final refused = reports.fold<int>(
      0,
      (count, report) =>
          count +
          jsonMaps(
            report['results'],
          ).where((r) => r['notEncoded'] == true).length,
    );
    print(
      'B3 REAL FFMPEG PASSED: $checks checks, ${reports.length} supplied builds, $encoded core-compiled synthetic preset encodes/readbacks/full decodes, $refused unavailable-encoder refusals. No fake host or VEGAS.',
    );
    print('Concise result: ${joinPath(root.path, 'summary.json')}');
  } catch (e) {
    print('Runtime diagnostics retained in ${root.path}');
    rethrow;
  }
}
