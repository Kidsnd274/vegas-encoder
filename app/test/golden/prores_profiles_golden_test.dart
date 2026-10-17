// Shared desktop/popup controls on the native core and fake platform services.
// No VEGAS or encoder execution. Profile IDs and generated argv stay native.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/app/app.dart';
import 'package:vegas_encoder/app/launch.dart';
import 'package:vegas_encoder/design/components/field.dart';
import 'package:vegas_encoder/design/components/popover.dart';
import 'package:vegas_encoder/design/components/select.dart';
import 'package:vegas_encoder/features/presets/library_pane.dart';
import 'package:vegas_encoder/features/presets/panels/video_panel.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/editor.dart';
import 'package:vegas_encoder/state/popup.dart';
import 'package:vegas_encoder/state/popup_version.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

void main() {
  late NativeVeCore core;
  late EditSessionRequest request;

  setUpAll(() async {
    core = NativeVeCore();
    final b0 = await FakeEditSessionService().readRequest('b0-session');
    final recipe = FakeVeCore().fixtures.singleWhere((f) => f.recipe.id == 'prores-hq').recipe;
    request = EditSessionRequest.fromJson({
      ...b0.toJson(),
      'recipe': recipe.toJson(),
      'origin': null,
      'baseRecipe': null,
    });
  });

  Finder profileField() => find.ancestor(of: find.text('Profile'), matching: find.byType(VeField));

  // Other profile-based encoders share the dropdown and need no descriptions.
  for (final brightness in themes) {
    testWidgets('DNxHR profile list ${themeName(brightness)}', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await pumpApp(tester, core: core, overrides: [windowControllerProvider.overrideWithValue(FakeWindowController())]);
      await tester.tap(find.descendant(of: find.byType(LibraryPane), matching: find.text('DNxHR HQ for Avid')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: profileField(), matching: find.byType(VeSelect<String>)));
      await tester.pumpAndSettle();
      expect(find.byType(VeListbox<String>), findsOneWidget);
      await expectGolden('dnxhr_profiles_${themeName(brightness)}');
      await tester.tap(find.descendant(of: find.byType(VeListbox<String>), matching: find.text('HQX (10-bit)')));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(VeApp)));
      expect(container.read(editorProvider)!.recipe.video.profile, 'dnxhr_hqx');
      expect(tester.takeException(), isNull);
    });
  }

  for (final popup in [false, true]) {
    for (final brightness in themes) {
      final name = 'prores_${popup ? 'popup' : 'desktop'}_${themeName(brightness)}';
      testWidgets(name, (tester) async {
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await pumpApp(
          tester,
          core: core,
          view: popup ? const Size(960, 640) : const Size(1100, 700),
          overrides: [
            windowControllerProvider.overrideWithValue(FakeWindowController()),
            if (popup) ...[
              launchModeProvider.overrideWithValue(const EditSessionLaunch('prores')),
              editSessionServiceProvider.overrideWithValue(FakeEditSessionService(requests: {'prores': request})),
              popupVersionsProvider.overrideWith((ref) async => matchingPopupVersions),
            ],
          ],
        );
        if (!popup) {
          await tester.tap(find.bySemanticsLabel('Show the preset library (Ctrl+F)'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(of: find.byType(LibraryPane), matching: find.text('ProRes 422 HQ for editing')),
          );
          await tester.pumpAndSettle();
        }
        expect(find.byType(VideoPanel), findsOneWidget);
        final panel = find.byType(VideoPanel);
        expect(find.descendant(of: panel, matching: find.text('prores_ks')), findsOneWidget);
        final select = find.descendant(of: profileField(), matching: find.byType(VeSelect<String>));
        expect(select, findsOneWidget);
        await expectGolden('${name}_closed');

        await tester.tap(select);
        await tester.pumpAndSettle();
        final list = find.byType(VeListbox<String>);
        final profile = core.profiles().video.singleWhere((p) => p.id == 'prores_ks');
        expect(profile.label, 'prores_ks');
        final choices = profile.profileQuality!;
        expect(choices.descriptions.keys.toSet(), choices.values.toSet());
        for (final id in choices.values) {
          expect(find.descendant(of: list, matching: find.text(choices.names[id] as String)), findsOneWidget);
          expect(find.descendant(of: list, matching: find.text(choices.descriptions[id] as String)), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await expectGolden('${name}_list');

        await tester.tap(find.descendant(of: list, matching: find.text('422 LT')));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(tester.element(find.byType(VeApp)));
        EditorData data() => container.read(popup ? popupEditorProvider : editorProvider)!;
        expect(data().recipe.video.encoder, 'prores_ks');
        expect(data().recipe.video.profile, 'lt');
        final argv = data().compiled.value!.argv;
        expect(argv[argv.indexOf('-profile:v') + 1], 'lt');
        await tester.tap(find.bySemanticsLabel('Reset Profile'));
        await tester.pumpAndSettle();
        expect(data().recipe.video.profile, 'hq');

        // The existing listbox keyboard behavior also works in both editors.
        await tester.tap(select);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(data().recipe.video.profile, 'standard');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
