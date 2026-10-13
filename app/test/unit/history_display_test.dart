import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/features/history/display.dart';
import 'package:vegas_encoder/state/history.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/services.dart';

/// History's mapping (S5) from the platform's sample job records (B0 fakes).
void main() {
  late Map<String, JobRecord> jobs;
  final catalog = FakeVeCore().profiles();

  setUpAll(() async {
    final repo = FakeJobRepository();
    jobs = {for (final e in await repo.list()) e.id: (await repo.get(e.id))!};
  });

  group('result sentence', () {
    test('a finished render: length, time taken, realtime and size', () {
      expect(resultSentence(jobs['j-1042']!), 'Rendered 12:43 in 24:46, 0.51× realtime, 9.84 GB.');
      expect(resultSentence(jobs['j-1040']!), 'Rendered 1:35 in 0:41, 2.30× realtime, 310 MB.');
    });

    test('failed and cancelled renders give the record’s reason', () {
      expect(
        resultSentence(jobs['j-1039']!),
        'Failed after 0:03. FFmpeg exited with code 1 before reading any frames.',
      );
      expect(resultSentence(jobs['j-1041']!), 'Cancelled after 3:32. Cancelled in VEGAS at 14%. Partial file removed.');
      expect(resultSentence(jobs['j-1039']!.copyWith(message: '')), 'Failed after 0:03.');
    });

    test('without a project length there is no realtime figure', () {
      final r = jobs['j-1042']!;
      final noLength = r.copyWith(media: MediaDescription.fromJson({...r.media.toJson(), 'durationSec': null}));
      expect(realtimeRatio(noLength), isNull);
      expect(resultSentence(noLength), 'Rendered in 24:46, 9.84 GB.');
    });
  });

  test('realtime ratio needs both figures and some time taken', () {
    expect(realtimeRatio(jobs['j-1042']!), closeTo(763.2 / 1486, 1e-9));
    expect(realtimeRatio(jobs['j-1042']!.copyWith(elapsedSec: 0)), isNull);
    expect(realtimeRatio(jobs['j-1039']!), isNull, reason: 'a failed render didn’t encode the whole length');
    expect(realtimeRatio(jobs['j-1041']!), isNull, reason: 'nor did a cancelled one');
    expect(ratioLabel(0.5136), '0.51×');
    expect(ratioLabel(12.44), '12.4×');
  });

  test('size shows only for a published file', () {
    expect(sizeLabel(jobs['j-1038']!), '5.02 GB');
    expect(sizeLabel(jobs['j-1039']!), 'No file');
  });

  group('encoder', () {
    test('the catalog’s name for the recipe’s video encoder', () {
      expect(encoderLabel(jobs['j-1042']!, catalog), 'x264');
      expect(encoderLabel(jobs['j-1040']!, catalog), catalog.video.firstWhere((e) => e.id == 'hevc_nvenc').label);
    });

    test('an Advanced command never claims its unused Basic settings', () {
      final r = jobs['j-1042']!;
      final advanced = r.copyWith(
        recipe: r.recipe.copyWith(
          command: CommandSettings(mode: 'template', template: '{inputs} -c:v libx265 {output}'),
        ),
      );
      expect(encoderLabel(advanced, catalog), 'Advanced command');
    });

    test('video off names the audio encoder', () {
      final r = jobs['j-1042']!;
      final audioOnly = r.copyWith(recipe: r.recipe.copyWith(video: r.recipe.video.copyWith(enabled: false)));
      expect(encoderLabel(audioOnly, catalog), catalog.audio.firstWhere((e) => e.id == 'aac').label);
    });
  });

  group('command line', () {
    test('quotes arguments the way the Windows C runtime reads them', () {
      expect(quoteArgument('-crf'), '-crf');
      expect(quoteArgument(''), '""');
      expect(quoteArgument(r'\\.\pipe\vegas-encoder-j-1-video'), r'\\.\pipe\vegas-encoder-j-1-video');
      expect(quoteArgument(r'D:\Renders\Channel trailer v2.mkv'), r'"D:\Renders\Channel trailer v2.mkv"');
      expect(quoteArgument('say "hi"'), r'"say \"hi\""');
      expect(quoteArgument(r'C:\with space\'), r'"C:\with space\\"');
      expect(quoteArgument(r'a\"b'), r'"a\\\"b"');
      expect(quoteArgument('tab\there'), '"tab\there"');
    });

    test('the executable, then every argument', () {
      final r = jobs['j-1039']!;
      final line = commandLine(r);
      expect(line, startsWith('${r.ffmpeg.path} -hide_banner -nostdin'));
      expect(line, contains(r' -i \\.\pipe\vegas-encoder-j-1039-video '));
      expect(line, endsWith(r' -f matroska "D:\Renders\Channel trailer v2.ve-partial-j-1039.mkv"'));
    });
  });

  test('labels: status, verification, hashes, times', () {
    expect(JobOutcome.of('failed').label, 'Failed');
    expect(JobOutcome.of('later-status'), JobOutcome.other);
    expect(verificationLabel(VerificationResult(state: 'passed')), 'Passed');
    expect(verificationLabel(VerificationResult()), 'Not checked');
    expect(shortHash('1' * 64), '11111111…11111111');
    final local = DateTime.utc(2026, 10, 12, 6).toLocal();
    final hm = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    expect(jobTime('2026-10-12T06:00:00Z'), '${local.day} Oct, $hm');
    expect(jobTime('2026-10-12T06:00:00Z', year: true), '${local.day} Oct 2026, $hm');
    expect(jobTime('not a time'), 'not a time');
  });

  group('history state', () {
    test('the filter keeps its status; the selection falls back to the first shown', () async {
      final container = ProviderContainer(overrides: [veCoreProvider.overrideWithValue(FakeVeCore())]);
      addTearDown(container.dispose);
      container.listen(historyViewProvider, (_, _) {});
      await container.read(jobsProvider.future);
      var view = container.read(historyViewProvider).value!;
      expect(view.shown.map((e) => e.id), ['j-1042', 'j-1041', 'j-1040', 'j-1039', 'j-1038']);
      expect(view.selectedId, 'j-1042');

      container.read(historyControllerProvider.notifier).select('j-1040');
      container.read(historyControllerProvider.notifier).setFilter(HistoryFilter.failed);
      view = container.read(historyViewProvider).value!;
      expect(view.shown.map((e) => e.id), ['j-1039']);
      expect(view.selectedId, 'j-1039', reason: 'the picked job is filtered out');

      container.read(historyControllerProvider.notifier).setFilter(HistoryFilter.all);
      expect(container.read(historyViewProvider).value!.selectedId, 'j-1040', reason: 'and comes back');
    });

    test('Open settings as new preset makes a preset in Mine, named after the template', () async {
      final library = FakePresetLibrary(now: () => '2026-10-14T00:00:00Z');
      final container = ProviderContainer(
        overrides: [veCoreProvider.overrideWithValue(FakeVeCore()), presetLibraryProvider.overrideWithValue(library)],
      );
      addTearDown(container.dispose);
      container.listen(presetsProvider, (_, _) {});
      await container.read(presetsProvider.future);
      final controller = container.read(presetsControllerProvider.notifier);
      controller.setQuery('prores');

      final r = jobs['j-1042']!;
      final created = (await controller.createFromRecipe(r.recipe, name: r.templateName))!;
      expect(created.builtin, isFalse);
      expect(created.origin, isNull);
      expect(created.recipe.name, 'YouTube 4K upload (Lakeside)');
      expect(created.recipe.id, 'youtube-4k-upload-lakeside');
      expect(created.recipe.video.toJson(), r.recipe.video.toJson());
      final state = container.read(presetsControllerProvider);
      expect(state.selectedId, created.recipe.id);
      expect(state.query, '', reason: 'the search is cleared so the new preset shows');

      await container.read(presetsProvider.future);
      final again = (await controller.createFromRecipe(r.recipe, name: r.templateName))!;
      expect(again.recipe.name, 'YouTube 4K upload (Lakeside) (copy)');
      expect(again.recipe.id, isNot(created.recipe.id));
    });
  });
}
