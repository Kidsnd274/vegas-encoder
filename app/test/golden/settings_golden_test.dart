// Golden images of the Settings screen on the platform fakes, light and dark.
// Regenerate with: flutter test --update-goldens test/golden/settings_golden_test.dart
// Images: test/golden/goldens/settings_<state>_<light|dark>.png

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

typedef _State = ({List<Override> Function() overrides, Future<void> Function(WidgetTester tester)? act});

void main() {
  final states = <String, _State>{
    // The sample machine settings: three installations, 8.1 full the default.
    'default': (overrides: () => [], act: null),
    // Scrolled to the end: the rendering note and About.
    'about': (
      overrides: () => [],
      act: (tester) async {
        await tester.ensureVisible(find.text('Services'));
        await tester.pumpAndSettle();
      },
    ),
    // Nothing set up yet: renders need a default FFmpeg.
    'no_ffmpeg': (
      overrides: () => [
        machineSettingsRepositoryProvider.overrideWithValue(FakeMachineSettingsRepository(settings: MachineSettings())),
      ],
      act: null,
    ),
  };

  for (final brightness in themes) {
    final theme = themeName(brightness);
    group(theme, () {
      states.forEach((name, s) {
        testWidgets('settings_$name', (tester) async {
          addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          await pumpApp(
            tester,
            overrides: [windowControllerProvider.overrideWithValue(FakeWindowController()), ...s.overrides()],
          );
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pumpAndSettle();
          await s.act?.call(tester);
          await expectGolden('settings_${name}_$theme');
        });
      });
    });
  }
}
