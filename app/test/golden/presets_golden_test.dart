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
    });
  }
}
