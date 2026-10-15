// Golden images of the Presets screen (S1) on the platform fakes, light and
// dark. Regenerate with: flutter test --update-goldens test/golden
// Images: test/golden/goldens/presets_<state>_<light|dark>.png

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/features/presets/library_pane.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';

import '../helpers.dart';

void main() {
  Future<void> select(WidgetTester tester, String preset) async {
    await tester.tap(find.descendant(of: find.byType(LibraryPane), matching: find.text(preset)));
    await tester.pumpAndSettle();
  }

  Future<void> node(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  final states = <String, Future<void> Function(WidgetTester)>{
    // File node: the size card with the core's rate and range; no total in B0.
    'file': (tester) => node(tester, 'Sample project.mp4'),
    // ProRes: 4:2:2 conversion pip, PCM 24-bit lossless audio.
    'audio': (tester) async {
      await select(tester, 'ProRes 422 HQ for editing');
      await node(tester, 'PCM 24-bit');
    },
    // AV1 in MKV: which containers can hold AV1 and Opus.
    'container': (tester) async {
      await select(tester, 'Small web file, AV1');
      await node(tester, '.mkv');
    },
    // An edit the preview core can't work out: Edited, Reset, the notice.
    'edited': (tester) async {
      await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '18'), '17');
      await tester.pumpAndSettle();
    },
    // Bitrate mode: Mb/s with common values and what the figures mean.
    'bitrate': (tester) async {
      await tester.tap(find.text('Bitrate'));
      await tester.pumpAndSettle();
    },
    // Test this preset: the fake test service's passed run, its output.
    'test': (tester) async {
      await tester.tap(find.text('Test').first);
      await tester.pumpAndSettle();
    },
    // An FFmpeg without x264: red node, library mark, the core's error.
    'lgpl': (tester) async {
      await tester.tap(find.text('FFmpeg 8.1 full (default)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FFmpeg 8.0 LGPL').last);
      await tester.pumpAndSettle();
    },
  };

  for (final brightness in themes) {
    final theme = themeName(brightness);
    group(theme, () {
      states.forEach((name, act) {
        testWidgets('presets_$name', (tester) async {
          addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          await pumpApp(tester, overrides: [windowControllerProvider.overrideWithValue(FakeWindowController())]);
          await act(tester);
          await expectGolden('presets_${name}_$theme');
        });
      });

      // The minimum window: the library is a rail, opened here over the editor.
      testWidgets('presets_narrow', (tester) async {
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await pumpApp(
          tester,
          view: const Size(1100, 700),
          overrides: [windowControllerProvider.overrideWithValue(FakeWindowController())],
        );
        await tester.tap(find.bySemanticsLabel('Show the preset library (Ctrl+F)'));
        await tester.pumpAndSettle();
        await expectGolden('presets_narrow_$theme');
      });

      // Windows text size at 150%: the diagram grows so node text fits.
      testWidgets('presets_text150', (tester) async {
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        await pumpApp(tester, overrides: [windowControllerProvider.overrideWithValue(FakeWindowController())]);
        await expectGolden('presets_text150_$theme');
      });
    });
  }
}
