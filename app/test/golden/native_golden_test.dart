// Golden images of the Presets screen on the native core (B2), light and dark,
// and of the window when the core didn't load. Fake services, no FFmpeg, no
// VEGAS. The core's profile data is B0/Linux bootstrap, not Windows-qualified:
// its figures and wording will move when platform's B1 lands, so regenerate
// these images then.
// Regenerate with: flutter test --update-goldens test/golden/native_golden_test.dart
// Images: test/golden/goldens/presets_native_<state>_<light|dark>.png and
// core_unavailable_<light|dark>.png

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/features/presets/panels/extra_field.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

void main() {
  late NativeVeCore core;

  setUpAll(() => core = NativeVeCore());

  Future<void> pump(WidgetTester tester, {Size? view}) => pumpApp(
    tester,
    core: core,
    view: view ?? const Size(1440, 900),
    overrides: [
      windowControllerProvider.overrideWithValue(FakeWindowController()),
      presetLibraryProvider.overrideWithValue(FakePresetLibrary(now: () => '2026-10-14T02:00:00Z')),
    ],
  );

  /// The two notes make the video panel taller than a 900 px window; a taller
  /// view shows it whole instead of scrolled.
  const views = {'extra': Size(1440, 960)};

  final states = <String, Future<void> Function(WidgetTester)>{
    // "YouTube upload, H.264", video node: the live command, the checks and
    // the keyframes read-out "2 s (60 frames at 29.97 fps)".
    'video': (tester) async {
      expect(find.text('2 s (60 frames at 29.97 fps)', findRichText: true), findsOneWidget);
    },
    // Extra arguments replace -preset and -g: "Set in Extra arguments." under
    // Encoder speed and Keyframes every, "120 frames at 29.97 fps", the Extra
    // tokens in the command. The caret stays on, so the image doesn't depend
    // on where its blink is.
    'extra': (tester) async {
      EditableText.debugDeterministicCursor = true;
      addTearDown(() => EditableText.debugDeterministicCursor = false);
      final extra = find.descendant(of: find.byType(ExtraArgumentsField), matching: find.byType(TextField));
      await tester.enterText(extra, '-preset fast -g 120');
      await tester.pumpAndSettle();
      expect(find.text('Set in Extra arguments.'), findsNWidgets(2));
      expect(find.text('120 frames at 29.97 fps', findRichText: true), findsOneWidget);
    },
    // File node at the default 10:00: the core's total and its range for 10:00.
    'file': (tester) async {
      await tester.tap(find.text('Sample project.mp4').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('for 10:00.'), findsOneWidget);
    },
  };

  for (final brightness in themes) {
    final theme = themeName(brightness);
    group(theme, () {
      states.forEach((name, act) {
        testWidgets('presets_native_$name', (tester) async {
          addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          await pump(tester, view: views[name]);
          await act(tester);
          await expectGolden('presets_native_${name}_$theme');
        });
      });

      // The core didn't load: the window says so in place of the screens.
      testWidgets('core_unavailable', (tester) async {
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await pumpApp(
          tester,
          core: const UnavailableCore(
            CoreException('NATIVE-LOAD', 'Cannot load the product core: ve_core.dll not found'),
          ),
          overrides: [windowControllerProvider.overrideWithValue(FakeWindowController())],
        );
        await expectGolden('core_unavailable_$theme');
      });
    });
  }
}
