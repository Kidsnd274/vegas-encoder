// Golden images of the History screen (S5) on the platform fakes (B0 job
// records with the summaries, error tokens and logs B4 adds; see
// test/history_doubles.dart), light and dark. Regenerate with:
//   flutter test --update-goldens test/golden/history_golden_test.dart
// Images: test/golden/goldens/history_<state>_<light|dark>.png

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/features/history/job_detail.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';
import '../history_doubles.dart';

void main() {
  Future<void> open(WidgetTester tester, {Size view = const Size(1440, 900)}) async {
    final jobs = await summarisedJobs();
    await pumpApp(
      tester,
      view: view,
      overrides: [
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        jobRepositoryProvider.overrideWithValue(jobs),
        jobLogsProvider.overrideWithValue(jobs),
      ],
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Finder inDetail(Finder f) => find.descendant(of: find.byType(JobDetail), matching: f);

  final states = <String, (Size, Future<void> Function(WidgetTester))>{
    // The newest render selected: result sentence, FFmpeg, command, output check.
    'default': (const Size(1440, 900), (tester) async {}),
    // The failed AV1 render: FFmpeg's words, how it stopped, and the
    // arguments its error points at marked in the command.
    'failed': (
      const Size(1440, 900),
      (tester) async {
        await tester.tap(find.text('Small web file, AV1'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(inDetail(find.text('Command')));
        await tester.pumpAndSettle();
      },
    ),
    // The full log opened: its last 1,000 lines, opening at the end.
    'log': (
      const Size(1440, 900),
      (tester) async {
        await tester.ensureVisible(inDetail(find.text('Show log')));
        await tester.tap(inDetail(find.text('Show log')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(inDetail(find.text('The last 1,000 of 1,502 lines.')));
        await tester.pumpAndSettle();
      },
    ),
    // The minimum window: length and time-taken columns give way.
    'narrow': (const Size(1100, 700), (tester) async {}),
  };

  for (final brightness in themes) {
    final theme = themeName(brightness);
    group(theme, () {
      states.forEach((name, state) {
        final (view, act) = state;
        testWidgets('history_$name', (tester) async {
          addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          await open(tester, view: view);
          await act(tester);
          await expectGolden('history_${name}_$theme');
        });
      });
    });
  }
}
