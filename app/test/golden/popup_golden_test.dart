// Golden images of the VEGAS popup (F5, S3, UI_SPEC §4) on the native core
// (B2), light and dark, with the platform's fake services: the fake session
// `b0-session` (origin "YouTube upload, H.264" revision 5, two changes, the
// library at revision 6, a 4K project) and requests made from it. No FFmpeg,
// no VEGAS. These use the native core's data: regenerate them when it changes.
// Regenerate with: flutter test --update-goldens test/golden/popup_golden_test.dart
// Images: test/golden/goldens/popup_<state>_<light|dark>.png

import 'package:flutter/material.dart' show TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/app/launch.dart';
import 'package:vegas_encoder/design/components/button.dart';
import 'package:vegas_encoder/features/presets/panels/extra_field.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

void main() {
  late NativeVeCore core;
  late EditSessionRequest b0;

  setUpAll(() async {
    core = NativeVeCore();
    b0 = await FakeEditSessionService().readRequest('b0-session');
  });

  Future<void> pump(
    WidgetTester tester,
    Brightness brightness, {
    EditSessionRequest? request,
    Size view = const Size(1120, 740),
    List<Override> overrides = const [],
  }) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    await pumpApp(
      tester,
      view: view,
      core: core,
      overrides: [
        launchModeProvider.overrideWithValue(const EditSessionLaunch('session')),
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        editSessionServiceProvider.overrideWithValue(FakeEditSessionService(requests: {'session': request ?? b0})),
        desktopAppLauncherProvider.overrideWithValue(WindowsDesktopAppLauncher(launch: (_, _) async {})),
        ...overrides,
      ],
    );
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  EditSessionRequest withRequest(Map<String, Object?> changes) =>
      EditSessionRequest.fromJson({...b0.toJson(), ...changes});

  for (final b in themes) {
    final theme = themeName(b);

    // The fake session: two changes in the template, the library at revision 6.
    testWidgets('$theme popup_video', (tester) async {
      await pump(tester, b);
      await expectGolden('popup_video_$theme');
    });

    testWidgets('$theme popup_update', (tester) async {
      await pump(tester, b);
      await tap(tester, find.text('Update from library'));
      await expectGolden('popup_update_$theme');
    });

    testWidgets('$theme popup_load', (tester) async {
      await pump(tester, b);
      await tap(tester, find.widgetWithText(VeButton, 'Load preset'));
      await expectGolden('popup_load_$theme');
    });

    // Made in VEGAS, and VEGAS didn't share the project's settings.
    testWidgets('$theme popup_unknown', (tester) async {
      final context = b0.context.toJson()..['media'] = null;
      await pump(tester, b, request: withRequest({'origin': null, 'baseRecipe': null, 'context': context}));
      await tap(tester, find.text('From VEGAS').first);
      await expectGolden('popup_unknown_$theme');
    });

    testWidgets('$theme popup_advanced', (tester) async {
      await pump(tester, b);
      await tap(tester, find.text('Advanced'));
      await expectGolden('popup_advanced_$theme');
    });

    testWidgets('$theme popup_errors', (tester) async {
      await pump(tester, b);
      await tester.enterText(
        find.descendant(of: find.byType(ExtraArgumentsField), matching: find.byType(TextField)),
        '-c:v libx265',
      );
      await tester.pumpAndSettle();
      await expectGolden('popup_errors_$theme');
    });

    testWidgets('$theme popup_deleted', (tester) async {
      await pump(tester, b, overrides: [presetLibraryProvider.overrideWithValue(FakePresetLibrary(presets: const []))]);
      await expectGolden('popup_deleted_$theme');
    });

    testWidgets('$theme popup_discard', (tester) async {
      await pump(tester, b);
      await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '17'), '20');
      await tester.pumpAndSettle();
      await tap(tester, find.widgetWithText(VeButton, 'Cancel'));
      await expectGolden('popup_discard_$theme');
    });

    // The popup's minimum size (UI_SPEC §1).
    testWidgets('$theme popup_min', (tester) async {
      await pump(tester, b, view: const Size(960, 640));
      await expectGolden('popup_min_$theme');
    });
  }
}
