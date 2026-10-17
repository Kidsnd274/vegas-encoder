// Selected-file import's enabled add-menu action, in both themes. The
// Windows file dialog belongs to the runner and is not part of this image.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';

import '../helpers.dart';

void main() {
  for (final brightness in themes) {
    final theme = themeName(brightness);
    testWidgets('preset_import_menu_$theme', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await pumpApp(tester, overrides: [windowControllerProvider.overrideWithValue(FakeWindowController())]);
      await tester.tap(find.byWidgetPredicate((w) => w is Tooltip && w.message == 'Add a preset'));
      await tester.pumpAndSettle();
      await expectGolden('preset_import_menu_$theme');
    });
  }
}
