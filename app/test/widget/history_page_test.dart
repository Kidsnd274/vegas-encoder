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

/// History (S5) on the platform fakes (B0 job records): no FFmpeg, no VEGAS.
void main() {
  late FakeJobRepository jobs;
  late FakePresetLibrary library;

  Future<void> keys(WidgetTester tester, LogicalKeyboardKey key, {bool control = false, bool shift = false}) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, {List<JobRecord>? records}) async {
    jobs = FakeJobRepository(records: records);
    library = FakePresetLibrary(now: () => '2026-10-14T02:00:00Z');
    await pumpApp(
      tester,
      overrides: [
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        jobRepositoryProvider.overrideWithValue(jobs),
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

  testWidgets('lists every render, newest first, with figures from its record', (tester) async {
    await pump(tester);
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
      'x264',
      '12:43',
      '24:46',
      '0.51×',
      '9.84 GB',
    ]) {
      expect(
        find.descendant(of: first, matching: find.text(text)),
        findsOneWidget,
        reason: text,
      );
    }
    expect(find.descendant(of: row('j-1039'), matching: find.text('No file')), findsOneWidget);
    expect(find.text('5 renders'), findsOneWidget);
    // The newest render is selected to start with.
    expect(inDetail(find.text('Rendered 12:43 in 24:46, 0.51× realtime, 9.84 GB.')), findsOneWidget);
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
    expect(inDetail(find.text('Rendered 3:02 in 2:40, 1.14× realtime, 5.02 GB.')), findsOneWidget);
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

  testWidgets('Open folder waits for the platform’s reveal service', (tester) async {
    await pump(tester);
    final button = tester.widget<VeButton>(find.widgetWithText(VeButton, 'Open folder'));
    expect(button.onPressed, isNull);
    expect(button.tooltip, contains('reveal service'));
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

  testWidgets('a record that is missing or unreadable says so', (tester) async {
    jobs = FakeJobRepository();
    await pumpApp(
      tester,
      overrides: [
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        jobRepositoryProvider.overrideWithValue(_IndexOnly(jobs, missing: 'j-1042', broken: 'j-1041')),
      ],
    );
    await keys(tester, LogicalKeyboardKey.digit3, control: true);
    expect(find.descendant(of: row('j-1042'), matching: find.text('The record is missing')), findsOneWidget);
    expect(find.descendant(of: row('j-1041'), matching: find.text('The record couldn’t be read')), findsOneWidget);
    expect(inDetail(find.textContaining('record is missing')), findsOneWidget);
    await tester.tap(row('j-1041'));
    await tester.pumpAndSettle();
    expect(inDetail(find.textContaining('couldn’t be read')), findsOneWidget);
  });
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
