// Golden images of the History screen (S5) on the platform fakes (B0 job
// records), light and dark. Regenerate with:
//   flutter test --update-goldens test/golden/history_golden_test.dart
// Images: test/golden/goldens/history_<state>_<light|dark>.png

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';

import '../helpers.dart';

void main() {
  Future<void> open(WidgetTester tester, {Size view = const Size(1440, 900)}) async {
    await pumpApp(tester, view: view, overrides: [windowControllerProvider.overrideWithValue(FakeWindowController())]);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  final states = <String, (Size, Future<void> Function(WidgetTester))>{
    // The newest render selected: result sentence, FFmpeg, command, output check.
    'default': (const Size(1440, 900), (tester) async {}),
    // The failed AV1 render: FFmpeg's words and how it stopped.
    'failed': (
      const Size(1440, 900),
      (tester) async {
        await tester.tap(find.text('Small web file, AV1'));
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
