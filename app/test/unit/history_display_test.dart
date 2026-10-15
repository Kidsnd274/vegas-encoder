import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/features/history/display.dart';
import 'package:vegas_encoder/state/history.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

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
      expect(resultSentence(jobs['j-1042']!), 'Rendered 12:43 in 24:46, 0.51× realtime, 9.84\u00A0GB.');
      expect(resultSentence(jobs['j-1040']!), 'Rendered 1:35 in 0:41, 2.30× realtime, 310\u00A0MB.');
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
      expect(resultSentence(noLength), 'Rendered in 24:46, 9.84\u00A0GB.');
    });
  });

  test('realtime ratio needs both figures and some time taken', () {
    expect(realtimeRatio(jobs['j-1042']!), closeTo(763.2 / 1486, 1e-9));
    expect(realtimeRatio(jobs['j-1042']!.copyWith(elapsedSec: 0)), isNull);
    expect(realtimeRatio(jobs['j-1039']!), isNull, reason: 'a failed render didn’t encode the whole length');
    expect(realtimeRatio(jobs['j-1041']!), isNull, reason: 'nor did a cancelled one');
    expect(realtimeRatio(jobs['j-1042']!.copyWith(realtime: 0.53)), 0.53, reason: 'the recorded figure wins (B4)');
    expect(realtimeRatio(jobs['j-1039']!.copyWith(realtime: 0.2)), isNull, reason: 'still only for a finished render');
    expect(ratioLabel(0.5136), '0.51×');
    expect(ratioLabel(12.44), '12.4×');
  });

  test('size shows only for a published file', () {
    expect(sizeLabel(jobs['j-1038']!), '5.02\u00A0GB');
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

    test('the core'
        's own command line when the record has it (B4)', () {
      final r = jobs['j-1039']!.copyWith(commandLine: 'ffmpeg -as -the -core -wrote -it');
      expect(commandLine(r), 'ffmpeg -as -the -core -wrote -it');
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
      final container = ProviderContainer(
        overrides: [veCoreProvider.overrideWithValue(FakeVeCore()), servicesOverride()],
      );
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
        overrides: [
          veCoreProvider.overrideWithValue(FakeVeCore()),
          servicesOverride(),
          presetLibraryProvider.overrideWithValue(library),
        ],
      );
      addTearDown(container.dispose);
      container.listen(presetsProvider, (_, _) {});
      await container.read(presetsProvider.future);
      final controller = container.read(presetsControllerProvider.notifier);
      controller.setQuery('prores');

      final r = jobs['j-1042']!;
      final created = (await controller.createFromJob(r))!;
      expect(created.builtin, isFalse);
      expect(created.origin, 'job/j-1042', reason: 'C3 PresetTransfer.fromJob');
      expect(created.recipe.name, 'YouTube 4K upload (Lakeside)');
      expect(created.recipe.id, 'youtube-4k-upload-lakeside');
      expect(created.recipe.video.toJson(), r.recipe.video.toJson());
      final state = container.read(presetsControllerProvider);
      expect(state.selectedId, created.recipe.id);
      expect(state.query, '', reason: 'the search is cleared so the new preset shows');

      await container.read(presetsProvider.future);
      final again = (await controller.createFromJob(r))!;
      expect(again.recipe.name, 'YouTube 4K upload (Lakeside) (copy)');
      expect(again.recipe.id, isNot(created.recipe.id));
    });
  });

  group('the list reads the index', () {
    JobIndexEntry entry({String? encoder, String? project, double? duration, int? size}) => JobIndexEntry(
      id: 'j-1',
      recordFile: 'j-1.json',
      startedAt: '2026-10-12T06:00:00Z',
      status: 'succeeded',
      templateName: 'T',
      outputPath: r'D:\Renders\a.mp4',
      encoderSummary: encoder,
      project: project,
      durationSec: duration,
      sizeBytes: size,
    );

    test('summaries show as the engine wrote them; absent or blank ones stay unknown', () {
      expect(indexEncoder(entry(encoder: 'x264 CRF 18 / AAC 320 kb/s')), 'x264 CRF 18 / AAC 320 kb/s');
      expect(indexEncoder(entry(encoder: '  ')), isNull, reason: 'the engine writes "" before it knows');
      expect(indexEncoder(entry()), isNull);
      expect(indexProject(entry(project: 'Lakeside.veg')), 'Lakeside.veg');
      expect(indexProject(entry(project: '')), isNull);
      expect(indexDuration(763.2), '12:43');
      expect(indexDuration(null), isNull);
    });

    test('size: the published bytes, "No file" for zero, unknown when absent', () {
      expect(indexSize(entry(size: 9840000000)), '9.84\u00A0GB');
      expect(indexSize(entry(size: 0)), 'No file');
      expect(indexSize(entry()), isNull);
    });
  });

  group('FFmpeg’s error tokens', () {
    test('mark argv entries by zero-based index, the executable not counted', () {
      final r = jobs['j-1039']!;
      final at = r.argv.indexOf('-preset');
      final parts = commandParts(r.copyWith(errorTokenIndices: [at, at + 1]));
      expect(parts.first, (text: quoteArgument(r.ffmpeg.path), error: false));
      expect(parts.length, r.argv.length + 1);
      expect(
        [
          for (final p in parts)
            if (p.error) p.text,
        ],
        ['-preset', '14'],
      );
      expect(markedArguments(r.copyWith(errorTokenIndices: [at + 1, at])), '-preset 14');
    });

    test('indexes outside argv are ignored; none means no note', () {
      final r = jobs['j-1039']!;
      final parts = commandParts(r.copyWith(errorTokenIndices: [-1, r.argv.length, 999]));
      expect(parts.where((p) => p.error), isEmpty);
      expect(markedArguments(r.copyWith(errorTokenIndices: [r.argv.length])), isNull);
      expect(markedArguments(r), isNull);
    });
  });

  group('the full log', () {
    test('summary while reading, whole, and cut to its last lines', () {
      expect(logSummary(totalLines: 3200, shownLines: 1000, complete: false), 'Reading the log… 3,200 lines so far.');
      expect(logSummary(totalLines: 13, shownLines: 13, complete: true), '13 lines.');
      expect(logSummary(totalLines: 1, shownLines: 1, complete: true), '1 line.');
      expect(logSummary(totalLines: 12345, shownLines: 1000, complete: true), 'The last 1,000 of 12,345 lines.');
    });

    test('streams in chunks and keeps only the last lines', () async {
      final text = [for (var i = 1; i <= 2500; i++) 'line $i'].join('\r\n');
      final logs = _ChunkedLogs({'j-1': text});
      final container = testContainer(overrides: [jobLogsProvider.overrideWithValue(logs)]);
      addTearDown(container.dispose);
      final sub = container.listen(jobLogProvider('j-1'), (_, _) {});
      addTearDown(sub.close);
      final view = await container.read(jobLogProvider('j-1').future);
      // The provider's first value may be a partial read; wait for the end.
      var last = view;
      while (last != null && !last.complete) {
        await Future<void>.delayed(Duration.zero);
        last = container.read(jobLogProvider('j-1')).value;
      }
      expect(last!.totalLines, 2500);
      expect(last.shownLines, jobLogMaxLines);
      expect(last.truncated, isTrue);
      expect(last.text.split('\n').first, 'line 1501');
      expect(last.text.split('\n').last, 'line 2500');
      expect(last.text, isNot(contains('\r')));
    });

    test('a job without a log is null, not an error', () async {
      final container = testContainer(overrides: [jobLogsProvider.overrideWithValue(FakeJobRepository())]);
      addTearDown(container.dispose);
      final sub = container.listen(jobLogProvider('j-1042'), (_, _) {});
      addTearDown(sub.close);
      expect(await container.read(jobLogProvider('j-1042').future), isNull);
      expect(await container.read(jobLogLocationProvider('j-1042').future), isNull);
    });
  });
}

/// A log delivered in 4 KB chunks that split lines, as the file service does.
class _ChunkedLogs implements JobLogs {
  _ChunkedLogs(this.logs);
  final Map<String, String> logs;

  @override
  Stream<String> readLog(String id) async* {
    final text = logs[id]!;
    for (var at = 0; at < text.length; at += 4096) {
      yield text.substring(at, at + 4096 > text.length ? text.length : at + 4096);
    }
  }

  @override
  Future<String?> logLocation(String id) async => 'logs/$id.ffmpeg.log';
}
