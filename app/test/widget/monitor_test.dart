import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/app/app.dart';
import 'package:vegas_encoder/design/components/button.dart';
import 'package:vegas_encoder/features/monitor/monitor_window.dart';
import 'package:vegas_encoder/features/monitor/monitor_precision.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/monitor.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';
import '../monitor_doubles.dart';

/// F6: the render progress window (UI_SPEC §12) on the platform's fake live
/// status reader (C5) and job repository (C6). No VEGAS, no FFmpeg, no file.
void main() {
  const view = Size(380, 340);

  Future<
    ({FakeWindowController window, FakeLiveRenderStatusReader live, FakeJobRepository jobs, FakeFileReveal reveal})
  >
  pump(
    WidgetTester tester, {
    LiveRenderStatus? status,
    JobRecord? record,
    DesktopAppLauncher? launcher,
    FakeJobRepository? jobs,
  }) async {
    final window = FakeWindowController();
    final m = monitorOverrides(status: status, record: record, window: window, launcher: launcher, repository: jobs);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await pumpApp(tester, view: view, overrides: m.overrides);
    return (window: window, live: m.live, jobs: m.jobs, reveal: m.reveal);
  }

  Finder rich(String text) => find.text(text, findRichText: true);
  bool closed(FakeWindowController w) => w.calls.contains('close');

  testWidgets('header precision follows C5 facts, preserving unknowns without loading core or library', (tester) async {
    final initial = liveAt(
      RenderState.encoding,
      10,
    ).copyWith(outputBitDepth: null, pixelFormatConversionReducesPrecision: null);
    final m = monitorOverrides(status: initial);
    tester.view.physicalSize = view;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servicesOverride(),
          ...m.overrides,
          veCoreProvider.overrideWith((ref) => throw StateError('Monitor must not load core during a render')),
          presetLibraryProvider.overrideWith(
            (ref) => throw StateError('Monitor must not read library during a render'),
          ),
        ],
        child: const VeApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MonitorPrecision), findsNothing, reason: 'encoder text cannot supply missing depth');

    Future<void> publish(int sequence, int? depth, bool? reduces) async {
      m.live.publish(
        liveFile,
        initial.copyWith(sequence: sequence, outputBitDepth: depth, pixelFormatConversionReducesPrecision: reduces),
      );
      await tester.pumpAndSettle();
    }

    await publish(11, 8, true);
    var glyph = tester.widget<MonitorPrecision>(find.byType(MonitorPrecision));
    expect(glyph.outputBitDepth, 8);
    expect(glyph.conversionReducesPrecision, isTrue);
    expect(find.bySemanticsLabel('8-bit at encoder input. Pixel-format conversion reduces precision.'), findsOneWidget);

    await publish(12, 10, false);
    glyph = tester.widget<MonitorPrecision>(find.byType(MonitorPrecision));
    expect(glyph.outputBitDepth, 10);
    expect(glyph.conversionReducesPrecision, isFalse);

    await publish(13, 10, null);
    glyph = tester.widget<MonitorPrecision>(find.byType(MonitorPrecision));
    expect(glyph.conversionReducesPrecision, isNull);
    expect(find.bySemanticsLabel('10-bit at encoder input. Pixel-format precision change is unknown.'), findsOneWidget);

    await publish(14, null, null);
    expect(find.byType(MonitorPrecision), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('follows the live file from start to finish', (tester) async {
    final m = await pump(tester);
    expect(find.text('Waiting for the render to start.'), findsOneWidget);
    expect(find.text('Cancel the render in VEGAS.'), findsOneWidget);

    Future<void> publish(RenderState state, int sequence) async {
      m.live.publish(liveFile, liveAt(state, sequence));
      await tester.pumpAndSettle();
    }

    await publish(RenderState.starting, 10);
    expect(find.text('Starting the render'), findsOneWidget);

    await publish(RenderState.encoding, 11);
    expect(find.text('Rendering, 32%'), findsOneWidget);
    expect(find.text('Frame 7,400 of 22,873'), findsOneWidget);
    expect(rich('61.8 fps'), findsOneWidget);
    expect(rich('about 2.93\u00A0GB'), findsOneWidget);
    expect(rich('4:10 of 8:14'), findsOneWidget);
    expect(find.bySemanticsLabel('Render progress'), findsOneWidget);

    await publish(RenderState.finishing, 12);
    expect(find.text('Finishing the file'), findsOneWidget);
    await publish(RenderState.verifying, 13);
    expect(find.text('Checking the output'), findsOneWidget);
    expect(find.text('Cancel the render in VEGAS.'), findsOneWidget, reason: 'no cancel here, ever');

    m.jobs.publish(await recordFor(RenderState.done));
    await publish(RenderState.done, 14);
    expect(find.text('Rendered'), findsOneWidget);
    expect(find.text(r'D:\Renders'), findsOneWidget);
    expect(find.textContaining('Rendered 12:43 in 4:07, 3.09× realtime, 2.93\u00A0GB.'), findsOneWidget);
    expect(find.text('Cancel the render in VEGAS.'), findsNothing);
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('an older or repeated status changes nothing', (tester) async {
    final m = await pump(tester, status: liveAt(RenderState.encoding, 20));
    expect(
      () => m.live.publish(liveFile, liveAt(RenderState.done, 19)),
      throwsA(isA<ServiceException>()),
      reason: 'the fake refuses it, as the real reader ignores it',
    );
    await tester.pumpAndSettle();
    expect(find.text('Rendering, 32%'), findsOneWidget);
  });

  group('done', () {
    testWidgets('closes itself after 10 s', (tester) async {
      final m = await pump(tester, status: liveSample(RenderState.done), record: await recordFor(RenderState.done));
      expect(find.text('Closes in 10 s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Closes in 7 s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(closed(m.window), isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(closed(m.window), isTrue);
    });

    testWidgets('stays open while the pointer is over it', (tester) async {
      final m = await pump(tester, status: liveSample(RenderState.done), record: await recordFor(RenderState.done));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(190, 150));
      await tester.pump();
      expect(find.text('Stays open while the pointer is here'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(closed(m.window), isFalse);

      await mouse.removePointer();
      await tester.pump();
      expect(find.text('Closes in 10 s'), findsOneWidget, reason: 'the count picks up where it was');
      await tester.pump(const Duration(seconds: 10));
      expect(closed(m.window), isTrue);
    });

    testWidgets('Open folder shows the file in Explorer; Close closes', (tester) async {
      final m = await pump(tester, status: liveSample(RenderState.done), record: await recordFor(RenderState.done));
      await tester.tap(find.widgetWithText(VeButton, 'Open folder'));
      await tester.pump();
      expect(m.reveal.revealed, [r'D:\Renders\Lakeside wedding final.mp4']);
      await tester.tap(find.widgetWithText(VeButton, 'Close'));
      await tester.pump();
      expect(m.window.calls, contains('close'));
    });

    testWidgets('without its record it says what the live file says', (tester) async {
      await pump(tester, status: liveSample(RenderState.done));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Rendered in 4:07, 2.06× realtime.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });
  });

  testWidgets('cancelled: says so and closes after 5 s', (tester) async {
    final m = await pump(
      tester,
      status: liveSample(RenderState.cancelled),
      record: await recordFor(RenderState.cancelled),
    );
    expect(find.text('Render cancelled'), findsOneWidget);
    expect(find.text('Cancelled in VEGAS after 1:12.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(closed(m.window), isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(closed(m.window), isTrue);
  });

  group('failed', () {
    testWidgets('highlights the cause, hides trailing warnings and stays open until dismissed', (tester) async {
      final m = await pump(tester, status: liveSample(RenderState.failed), record: await recordFor(RenderState.failed));
      expect(find.text('Render failed'), findsOneWidget);
      expect(find.text('Why it failed'), findsOneWidget);
      expect(find.text("FFmpeg: No such filter: 'vegas_encoder_deliberate_failure'"), findsOneWidget);
      expect(find.textContaining('Conversion failed!'), findsNothing);
      expect(find.textContaining('thread_queue_size'), findsNothing);
      expect(find.text('Stays open until you close it.'), findsOneWidget);
      await tester.pump(const Duration(minutes: 10));
      expect(closed(m.window), isFalse);
      await tester.tap(find.widgetWithText(VeButton, 'Close'));
      await tester.pump();
      expect(closed(m.window), isTrue);
    });

    testWidgets('shows the live cause immediately without waiting for the job record', (tester) async {
      const cause = "FFmpeg: No such filter: 'vegas_encoder_deliberate_failure'";
      final m = await pump(tester, status: liveSample(RenderState.failed).copyWith(message: cause));
      expect(find.text(cause), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(cause), findsOneWidget);
      await tester.pump(const Duration(minutes: 10));
      expect(closed(m.window), isFalse);
    });

    testWidgets('a failure cancels a pending automatic-close countdown', (tester) async {
      final m = await pump(tester, status: liveAt(RenderState.done, 10), record: await recordFor(RenderState.done));
      await tester.pump(const Duration(seconds: 3));
      m.live.publish(liveFile, liveAt(RenderState.failed, 11));
      await tester.pumpAndSettle();
      expect(find.text('Stays open until you close it.'), findsOneWidget);
      await tester.pump(const Duration(minutes: 10));
      expect(closed(m.window), isFalse);
    });

    testWidgets('long errors can be scrolled without truncating the cause or hiding Close', (tester) async {
      final cause = 'FFmpeg: No such filter: ${List.filled(40, 'long filter name').join(' ')} END';
      final m = await pump(tester, status: liveSample(RenderState.failed).copyWith(message: cause));
      expect(find.text(cause), findsOneWidget);
      final text = tester.widget<Text>(find.text(cause));
      expect(text.maxLines, isNull);
      final panel = find.byKey(const ValueKey('monitor-failure-cause'));
      await tester.drag(
        find.descendant(of: panel, matching: find.byType(SingleChildScrollView)),
        const Offset(0, -600),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(VeButton, 'Close').hitTestable(), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(closed(m.window), isFalse);
    });

    testWidgets('Show log shows FFmpeg\'s log in Explorer', (tester) async {
      final m = await pump(tester, status: liveSample(RenderState.failed), record: await recordFor(RenderState.failed));
      await tester.tap(find.widgetWithText(VeButton, 'Show log'));
      await tester.pump();
      expect(m.reveal.revealed, ['fixture/b0-render.ffmpeg.log']);
    });

    testWidgets('no log: Show log is off and says why', (tester) async {
      final record = JobRecord.fromJson({...(await recordFor(RenderState.failed)).toJson(), 'logFile': null});
      final m = await pump(tester, status: liveSample(RenderState.failed), record: record);
      final button = tester.widget<VeButton>(find.widgetWithText(VeButton, 'Show log'));
      expect(button.onPressed, isNull);
      expect(button.tooltip, 'FFmpeg left no log for this render.');
      expect(m.reveal.revealed, isEmpty);
    });

    testWidgets('Show in History waits on a way to start the desktop app', (tester) async {
      await pump(tester, status: liveSample(RenderState.failed), record: await recordFor(RenderState.failed));
      final button = tester.widget<VeButton>(find.widgetWithText(VeButton, 'Show in History'));
      expect(button.onPressed, isNull);
      expect(button.tooltip, contains('History'));
    });

    testWidgets('Show in History opens the job when the app can be started', (tester) async {
      final launcher = _Launcher();
      await pump(
        tester,
        status: liveSample(RenderState.failed),
        record: await recordFor(RenderState.failed),
        launcher: launcher,
      );
      await tester.tap(find.widgetWithText(VeButton, 'Show in History'));
      await tester.pump();
      expect(launcher.jobs, ['b0-render']);
    });

    testWidgets('Show in History reports launch failure separately and keeps the render cause open', (tester) async {
      final launcher = _Launcher()..fail = true;
      final m = await pump(
        tester,
        status: liveSample(RenderState.failed),
        record: await recordFor(RenderState.failed),
        launcher: launcher,
      );
      await tester.tap(find.widgetWithText(VeButton, 'Show in History'));
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t open Vegas Encoder: The desktop app could not be started.'), findsOneWidget);
      expect(find.text("FFmpeg: No such filter: 'vegas_encoder_deliberate_failure'").hitTestable(), findsOneWidget);
      expect(find.text('Stays open until you close it.'), findsOneWidget);
      await tester.pump(const Duration(minutes: 1));
      expect(closed(m.window), isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a record arriving after two seconds updates failure details and enables its log', (tester) async {
    final jobs = _CountingJobs(logs: {'b0-render': 'FFmpeg failure log'});
    final m = await pump(tester, status: liveAt(RenderState.encoding, 10), jobs: jobs);
    await tester.pump(const Duration(seconds: 3));
    expect(jobs.reads, 0, reason: 'no C6 or index reads during encoding');

    m.live.publish(liveFile, liveAt(RenderState.failed, 11).copyWith(message: 'Immediate live cause'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.pump(monitorRecordInterval);
      await tester.pump();
    }
    expect(find.text('Immediate live cause'), findsOneWidget);
    expect(jobs.reads, greaterThan(3));
    expect(jobs.logReads, 0, reason: 'log access waits for the record');

    jobs.publish((await recordFor(RenderState.failed)).copyWith(message: 'Delayed recorded cause'));
    await tester.pump(monitorRecordInterval);
    await tester.pumpAndSettle();
    expect(find.text('Delayed recorded cause'), findsOneWidget);
    expect(find.text('Immediate live cause'), findsNothing);
    expect(jobs.logReads, 1);
    await tester.tap(find.widgetWithText(VeButton, 'Show log'));
    await tester.pump();
    expect(m.reveal.revealed, ['fixture/b0-render.ffmpeg.log']);
    final reads = jobs.reads;
    await tester.pump(const Duration(minutes: 10));
    expect(jobs.reads, reads, reason: 'record lookup stops after success');
    expect(closed(m.window), isFalse, reason: 'late record leaves failure retention unchanged');
  });

  testWidgets('disposing a monitor cancels missing-record lookup', (tester) async {
    final jobs = _CountingJobs();
    await pump(tester, status: liveSample(RenderState.failed), jobs: jobs);
    expect(jobs.reads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final reads = jobs.reads;
    await tester.pump(const Duration(minutes: 10));
    expect(jobs.reads, reads);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pin keeps the window on top and is remembered (C7)', (tester) async {
    final m = await pump(tester, status: liveSample(RenderState.encoding));
    await tester.tap(find.bySemanticsLabel('Keep on top'));
    await tester.pumpAndSettle();
    expect(m.window.calls, contains('setKeepOnTop(true)'));
    final container = ProviderScope.containerOf(tester.element(find.byType(MonitorWindow)));
    expect((await container.read(machineSettingsRepositoryProvider).read()).keepOnTop, isTrue);

    await tester.tap(find.bySemanticsLabel('Keep on top'));
    await tester.pumpAndSettle();
    expect(m.window.calls, contains('setKeepOnTop(false)'));
    expect((await container.read(machineSettingsRepositoryProvider).read()).keepOnTop, isFalse);
  });

  testWidgets('no news for a while is said, and a new status clears it', (tester) async {
    final m = await pump(tester, status: liveAt(RenderState.encoding, 10));
    await tester.pump(staleAfter - const Duration(seconds: 1));
    expect(find.textContaining('No news'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('No news from the render for 30 s'), findsOneWidget);
    expect(find.text('Rendering, 32%'), findsOneWidget, reason: 'a quiet file never ends the render');

    m.live.publish(liveFile, liveAt(RenderState.encoding, 11).copyWith(framesDone: 8000));
    await tester.pumpAndSettle();
    expect(find.textContaining('No news'), findsNothing);
    expect(find.text('Rendering, 34%'), findsOneWidget);
  });

  testWidgets('checking the output is not "no news"', (tester) async {
    await pump(tester, status: liveSample(RenderState.verifying));
    await tester.pump(const Duration(minutes: 3));
    expect(find.textContaining('No news'), findsNothing, reason: 'ffprobe can take minutes on a long file');
  });

  group('placement before the first frame', () {
    test('VEGAS\'s window from the live file and the remembered pin', () async {
      final container = testContainer(overrides: monitorOverrides(status: liveSample(RenderState.starting)).overrides);
      addTearDown(container.dispose);
      final settings = container.read(machineSettingsRepositoryProvider);
      final current = await settings.read();
      await settings.save(current.copyWith(keepOnTop: true), expectedRevision: current.revision);
      expect(await monitorPlacement(container, liveFile), (host: 123456, keepOnTop: true));
    });

    test('no file yet: the runner\'s placement and the pin off', () async {
      final container = testContainer(overrides: monitorOverrides().overrides);
      addTearDown(container.dispose);
      expect(await monitorPlacement(container, liveFile), (host: null, keepOnTop: false));
    });
  });
}

class _Launcher implements DesktopAppLauncher {
  final List<String> jobs = [];
  bool fail = false;
  @override
  Future<void> openPreset(String presetId) async {}
  @override
  Future<void> openJob(String jobId) async {
    if (fail) throw const ServiceException('APP-LAUNCH', 'The desktop app could not be started.');
    jobs.add(jobId);
  }
}

class _CountingJobs extends FakeJobRepository {
  _CountingJobs({super.logs}) : super(records: const []);
  int reads = 0;
  int logReads = 0;

  @override
  Future<JobRecord?> get(String id) {
    reads++;
    return super.get(id);
  }

  @override
  Future<String?> logLocation(String id) {
    logReads++;
    return super.logLocation(id);
  }
}
