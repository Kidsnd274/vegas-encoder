import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/design/components/button.dart';
import 'package:vegas_encoder/design/components/segmented.dart';
import 'package:vegas_encoder/features/history/display.dart';
import 'package:vegas_encoder/features/history/history_page.dart';
import 'package:vegas_encoder/features/history/job_detail.dart';
import 'package:vegas_encoder/features/history/job_list.dart';
import 'package:vegas_encoder/features/presets/library_pane.dart';
import 'package:vegas_encoder/features/presets/presets_page.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';
import '../history_doubles.dart';

/// History (S5) on the platform fakes (B0 job records): no FFmpeg, no VEGAS.
void main() {
  late FakeJobRepository jobs;
  late FakePresetLibrary library;
  late FakeFileReveal reveal;

  Future<void> keys(WidgetTester tester, LogicalKeyboardKey key, {bool control = false, bool shift = false}) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  /// History on [repo], or on the B0 records ([records]) whose index lines
  /// have no summaries.
  Future<void> pump(WidgetTester tester, {List<JobRecord>? records, JobRepository? repo}) async {
    final source = repo ?? FakeJobRepository(records: records);
    if (source is FakeJobRepository) jobs = source;
    library = FakePresetLibrary(now: () => '2026-10-14T02:00:00Z');
    reveal = FakeFileReveal();
    await pumpApp(
      tester,
      overrides: [
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        jobRepositoryProvider.overrideWithValue(source),
        jobLogsProvider.overrideWithValue(source as JobLogs),
        fileRevealProvider.overrideWithValue(reveal),
        presetLibraryProvider.overrideWithValue(library),
      ],
    );
    await keys(tester, LogicalKeyboardKey.digit3, control: true);
    expect(find.byType(HistoryPage), findsOneWidget);
  }

  Finder row(String id) => find.byKey(ValueKey('job-$id'));
  Finder inDetail(Finder f) => find.descendant(of: find.byType(JobDetail), matching: f);
  Future<void> show(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byWidgetPredicate((w) => w is VeSegmented), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every render, newest first, with figures from the index', (tester) async {
    final repo = _CountingJobs(await summarisedJobs());
    await pump(tester, repo: repo);
    expect(find.byType(JobRow), findsNWidgets(5));
    final ys = [
      for (final id in ['j-1042', 'j-1041', 'j-1040', 'j-1039', 'j-1038']) tester.getTopLeft(row(id)).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
    final first = row('j-1042');
    for (final text in [
      'Succeeded',
      'YouTube 4K upload (Lakeside)',
      'Lakeside wedding final.veg',
      'x264 CRF 18, slow / AAC 320 kb/s',
      '12:43',
      '24:46',
      '9.84\u00A0GB',
    ]) {
      expect(
        find.descendant(of: first, matching: find.text(text)),
        findsOneWidget,
        reason: text,
      );
    }
    // Speed needs the record's realtime figure: the detail has it, the list doesn't.
    expect(find.descendant(of: first, matching: find.text('0.51×')), findsNothing);
    expect(find.descendant(of: row('j-1039'), matching: find.text('No file')), findsOneWidget);
    expect(find.text('5 renders'), findsOneWidget);
    // The newest render is selected to start with.
    expect(inDetail(find.text('Rendered 12:43 in 24:46, 0.51× realtime, 9.84\u00A0GB.')), findsOneWidget);
    // Only the selected render's record was read, not one per row.
    expect(repo.read, {'j-1042'});
  });

  testWidgets('an older index line without summaries keeps them unknown', (tester) async {
    await pump(tester);
    final first = row('j-1042');
    // The B0 index has project, length, time and size, but no encoder summary.
    expect(find.descendant(of: first, matching: find.text('Lakeside wedding final.veg')), findsOneWidget);
    expect(
      find.descendant(of: first, matching: find.text('–')),
      findsOneWidget,
      reason: 'the encoder',
    );
    expect(find.descendant(of: first, matching: find.text('x264')), findsNothing);
    final bare = JobIndexEntry(
      id: 'j-0001',
      recordFile: 'j-0001.json',
      startedAt: '2026-10-01T08:00:00Z',
      status: 'succeeded',
      templateName: 'Before summaries',
      outputPath: r'D:\Renders\old.mp4',
    );
    expect(indexEncoder(bare), isNull);
    expect(indexProject(bare), isNull);
    expect(indexSize(bare), isNull);
    expect(indexDuration(bare.durationSec), isNull);
  });

  testWidgets('the status filter keeps one kind of render', (tester) async {
    await pump(tester);
    await show(tester, 'Failed');
    expect(find.byType(JobRow), findsOneWidget);
    expect(row('j-1039'), findsOneWidget);
    expect(find.text('1 of 5 renders'), findsOneWidget);
    // The failed render's detail: reason, FFmpeg's words, how it stopped.
    expect(
      inDetail(find.text('Failed after 0:03. FFmpeg exited with code 1 before reading any frames.')),
      findsOneWidget,
    );
    expect(inDetail(find.text('FFmpeg said')), findsOneWidget);
    expect(inDetail(find.textContaining('Error setting preset 14')), findsOneWidget);
    expect(inDetail(find.text('0x80004005')), findsOneWidget);
    expect(inDetail(find.text('1')), findsOneWidget, reason: 'the exit code');
  });

  testWidgets('clicking a render shows its detail; Up and Down move through the list', (tester) async {
    await pump(tester);
    await tester.tap(find.descendant(of: row('j-1038'), matching: find.text('ProRes 422 HQ for editing')));
    await tester.pumpAndSettle();
    expect(inDetail(find.text('ProRes 422 HQ for editing')), findsOneWidget);
    expect(inDetail(find.text('Rendered 3:02 in 2:40, 1.14× realtime, 5.02\u00A0GB.')), findsOneWidget);
    expect(inDetail(find.text('FFmpeg said')), findsNothing, reason: 'no stderr for a clean render');

    await keys(tester, LogicalKeyboardKey.arrowUp);
    expect(inDetail(find.text('Small web file, AV1')), findsOneWidget);
    await keys(tester, LogicalKeyboardKey.arrowUp);
    await keys(tester, LogicalKeyboardKey.arrowUp);
    expect(
      inDetail(find.text('Cancelled after 3:32. Cancelled in VEGAS at 14%. Partial file removed.')),
      findsOneWidget,
    );
    await keys(tester, LogicalKeyboardKey.arrowDown);
    expect(inDetail(find.text('YouTube upload, HEVC on GPU')), findsOneWidget);
  });

  testWidgets('Copy command and Ctrl+Shift+C copy the command that ran, quoted', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(tester);
    final failed = (await jobs.get('j-1039'))!;

    await show(tester, 'Failed');
    await tester.tap(inDetail(find.text('Copy command')));
    await tester.pumpAndSettle();
    expect(copied, commandLine(failed));
    expect(copied, endsWith(r'"D:\Renders\Channel trailer v2.ve-partial-j-1039.mkv"'));
    expect(find.text('Command copied'), findsOneWidget);

    copied = null;
    await show(tester, 'All');
    await keys(tester, LogicalKeyboardKey.keyC, control: true, shift: true);
    expect(copied, commandLine((await jobs.get('j-1042'))!));
  });

  testWidgets('Open settings as new preset opens a copy in Presets', (tester) async {
    await pump(tester);
    await tester.tap(inDetail(find.text('Open settings as new preset')));
    await tester.pumpAndSettle();
    expect(find.byType(PresetsPage), findsOneWidget);
    final made = (await library.list()).where((p) => p.recipe.name == 'YouTube 4K upload (Lakeside)').single;
    expect(made.builtin, isFalse);
    expect(
      find.descendant(of: find.byType(LibraryPane), matching: find.text('YouTube 4K upload (Lakeside)')),
      findsOneWidget,
    );
  });

  testWidgets('Open folder shows the file in Explorer; a render with no file can’t', (tester) async {
    await pump(tester);
    // The newest render published its file.
    await tester.tap(inDetail(find.text('Open folder')));
    await tester.pumpAndSettle();
    expect(reveal.revealed, [r'D:\Renders\Lakeside wedding final.mp4']);

    // The failed render published nothing and kept nothing.
    await show(tester, 'Failed');
    final button = tester.widget<VeButton>(find.widgetWithText(VeButton, 'Open folder'));
    expect(button.onPressed, isNull);
    expect(button.tooltip, 'This render left no file to show.');
  });

  testWidgets('Open folder shows a kept unfinished file', (tester) async {
    final failed = (await FakeJobRepository().get('j-1039'))!;
    await pump(
      tester,
      records: [failed.copyWith(retainedPartialPath: r'D:\Renders\Channel trailer v2.ve-partial-j-1039.mkv')],
    );
    await tester.tap(inDetail(find.text('Open folder')));
    await tester.pumpAndSettle();
    expect(reveal.revealed, [r'D:\Renders\Channel trailer v2.ve-partial-j-1039.mkv']);
  });

  testWidgets('a new record appears while History is open', (tester) async {
    await pump(tester);
    final base = (await jobs.get('j-1039'))!;
    jobs.publish(base.copyWith(id: 'j-1043', templateName: 'Client review, 1080p', startedAt: '2026-10-13T09:00:00Z'));
    await tester.pumpAndSettle();
    expect(find.byType(JobRow), findsNWidgets(6));
    expect(find.descendant(of: row('j-1043'), matching: find.text('Client review, 1080p')), findsOneWidget);
    expect(find.text('6 renders'), findsOneWidget);
  });

  testWidgets('no renders yet', (tester) async {
    await pump(tester, records: const []);
    expect(find.text('No renders yet.'), findsOneWidget);
    expect(find.text('Renders made with Vegas Encoder in VEGAS appear here.'), findsOneWidget);
    expect(find.byType(JobDetail), findsNothing);
  });

  testWidgets('a filter with no renders offers to show them all', (tester) async {
    final all = await FakeJobRepository().list();
    final repo = FakeJobRepository();
    final succeeded = [
      for (final e in all)
        if (e.status == 'succeeded') (await repo.get(e.id))!,
    ];
    await pump(tester, records: succeeded);
    await show(tester, 'Cancelled');
    expect(find.text('No cancelled renders. '), findsOneWidget);
    await tester.tap(find.text('Show all renders'));
    await tester.pumpAndSettle();
    expect(find.byType(JobRow), findsNWidgets(3));
  });

  testWidgets('a record that is missing or unreadable says so in the detail', (tester) async {
    jobs = FakeJobRepository();
    await pumpApp(
      tester,
      overrides: [
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        jobRepositoryProvider.overrideWithValue(_IndexOnly(jobs, missing: 'j-1042', broken: 'j-1041')),
      ],
    );
    await keys(tester, LogicalKeyboardKey.digit3, control: true);
    // The rows come from the index alone, so both still list normally.
    expect(find.descendant(of: row('j-1042'), matching: find.text('Lakeside wedding final.veg')), findsOneWidget);
    expect(find.descendant(of: row('j-1041'), matching: find.text('Lakeside wedding final.veg')), findsOneWidget);
    expect(inDetail(find.textContaining('record is missing')), findsOneWidget);
    await tester.tap(row('j-1041'));
    await tester.pumpAndSettle();
    expect(inDetail(find.textContaining('couldn’t be read')), findsOneWidget);
  });

  testWidgets('the command marks the arguments FFmpeg’s error points at', (tester) async {
    await pump(tester, repo: await summarisedJobs());
    await show(tester, 'Failed');
    expect(inDetail(find.text('FFmpeg’s error points at “-preset 14”, underlined above.')), findsOneWidget);
    final command = tester.widget<RichText>(
      find.descendant(
        of: find.byWidgetPredicate((w) => w is Semantics && (w.properties.label ?? '').startsWith('Command:')),
        matching: find.byType(RichText),
      ),
    );
    final marked = <String>[];
    command.text.visitChildren((span) {
      if (span is TextSpan && span.style?.decoration == TextDecoration.underline) marked.add(span.text!);
      return true;
    });
    expect(marked, ['-preset', '14']);

    // A render FFmpeg didn't name anything in has no marks and no note.
    await show(tester, 'Succeeded');
    expect(inDetail(find.textContaining('error points at')), findsNothing);
  });

  testWidgets('the full log: its last lines on request, Show in folder, and a render without one', (tester) async {
    await pump(tester, repo: await summarisedJobs());
    // The newest render (j-1042) has a 1,502-line log.
    expect(inDetail(find.text('Everything FFmpeg wrote while it rendered.')), findsOneWidget);
    await tester.ensureVisible(inDetail(find.text('Show log')));
    await tester.tap(inDetail(find.text('Show log')));
    await tester.pumpAndSettle();
    expect(inDetail(find.text('The last 1,000 of 1,502 lines.')), findsOneWidget);
    expect(inDetail(find.textContaining('muxing overhead: 0.0213%')), findsOneWidget);
    expect(
      inDetail(find.textContaining('ffmpeg version 8.1')),
      findsNothing,
      reason: 'an early line beyond the last 1,000',
    );
    await tester.tap(inDetail(find.text('Show in folder')));
    await tester.pumpAndSettle();
    expect(reveal.revealed, ['fixture/j-1042.ffmpeg.log']);
    await tester.tap(inDetail(find.text('Hide log')));
    await tester.pumpAndSettle();
    expect(inDetail(find.textContaining('muxing overhead')), findsNothing);

    // The failed render's short log, whole.
    await show(tester, 'Failed');
    await tester.ensureVisible(inDetail(find.text('Show log')));
    await tester.tap(inDetail(find.text('Show log')));
    await tester.pumpAndSettle();
    expect(inDetail(find.text('13 lines.')), findsOneWidget);
    expect(inDetail(find.textContaining('Conversion failed!')), findsWidgets);

    // The cancelled render has no log.
    await show(tester, 'Cancelled');
    expect(inDetail(find.text('FFmpeg left no log for this render.')), findsOneWidget);
    expect(inDetail(find.text('Show log')), findsNothing);
  });

  testWidgets('a log that went missing says so', (tester) async {
    final repo = await summarisedJobs();
    await pump(tester, repo: _LogGone(repo));
    await tester.ensureVisible(inDetail(find.text('Show log')));
    await tester.tap(inDetail(find.text('Show log')));
    await tester.pumpAndSettle();
    expect(inDetail(find.text('The log file isn’t there any more.')), findsOneWidget);
  });
}

/// Counts which records were read.
class _CountingJobs implements JobRepository, JobLogs {
  _CountingJobs(this._jobs);
  final FakeJobRepository _jobs;
  final Set<String> read = {};

  @override
  Future<List<JobIndexEntry>> list() => _jobs.list();
  @override
  Stream<List<JobIndexEntry>> watch() => _jobs.watch();
  @override
  Future<JobRecord?> get(String id) {
    read.add(id);
    return _jobs.get(id);
  }

  @override
  Stream<String> readLog(String id) => _jobs.readLog(id);
  @override
  Future<String?> logLocation(String id) => _jobs.logLocation(id);
}

/// The index names a log, but the file has gone (C3 `NOT-FOUND`).
class _LogGone extends _CountingJobs {
  _LogGone(super.jobs);

  @override
  Stream<String> readLog(String id) => Stream.error(const ServiceException('NOT-FOUND', 'Log file is missing.'));
}

/// The index lists [missing] and [broken], but one record is gone and the
/// other can't be read.
class _IndexOnly implements JobRepository {
  _IndexOnly(this._jobs, {required this.missing, required this.broken});
  final FakeJobRepository _jobs;
  final String missing;
  final String broken;

  @override
  Future<List<JobIndexEntry>> list() => _jobs.list();
  @override
  Stream<List<JobIndexEntry>> watch() => _jobs.watch();
  @override
  Future<JobRecord?> get(String id) async {
    if (id == missing) return null;
    if (id == broken) throw const ServiceException('JOB-RECORD', 'The record ends early.');
    return _jobs.get(id);
  }
}
