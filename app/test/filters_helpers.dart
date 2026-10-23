import 'package:flutter/material.dart' show Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/app/app.dart';
import 'package:vegas_encoder/app/launch.dart';
import 'package:vegas_encoder/design/components/button.dart';
import 'package:vegas_encoder/design/components/popover.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/editor.dart';
import 'package:vegas_encoder/state/popup.dart';
import 'package:vegas_encoder/state/popup_version.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/services.dart';

import 'helpers.dart';

/// Real core; in-memory platform services and edit sessions. No host or FFmpeg
/// process is launched. Both editors consume the same native compilation.
class FiltersHarness {
  FiltersHarness(this.core, {required this.popup});
  final NativeVeCore core;
  final bool popup;
  late FakeMachineSettingsRepository machine;
  late FakeEditSessionService sessions;

  Future<void> pump(
    WidgetTester tester, {
    VideoFilter? filter,
    String extra = '',
    bool expanded = false,
    MediaDescription? media,
    bool missingScale = false,
  }) async {
    final fixture = FakeVeCore().fixtures.firstWhere((f) => f.recipe.id == 'yt-h264');
    final preset = (await FakePresetLibrary().list()).singleWhere((p) => p.recipe.id == 'yt-h264');
    var recipe = fixture.recipe;
    recipe = recipe.copyWith(
      schema: filter == null ? recipe.schema : 2,
      video: filter == null
          ? recipe.video.copyWith(extra: extra)
          : recipe.video.copyWith(extra: extra, filters: [filter]),
    );
    final settings = await FakeMachineSettingsRepository().read();
    machine = FakeMachineSettingsRepository(
      settings: settings.copyWith(uiState: AppUiState(videoFiltersExpanded: expanded)),
    );
    final installation = settings.installations.singleWhere((i) => i.id == settings.defaultFFmpegId);
    final progress = await FakeFFmpegProbe().probe(installation).last;
    final capabilities = progress.capabilities!.copyWith(
      filters: {
        if (!missingScale)
          'scale': {
            'available': true,
            'algorithms': ['bicubic', 'bilinear', 'lanczos', 'neighbor'],
            'options': [
              for (final name in ['w', 'h', 'flags']) {'name': name},
            ],
          },
        'pad': {
          'available': true,
          'options': [
            for (final name in ['width', 'height', 'x', 'y', 'color']) {'name': name},
          ],
        },
        'setsar': {
          'available': true,
          'options': [
            {'name': 'sar'},
          ],
        },
      },
    );
    final original = await FakeEditSessionService().readRequest('b0-session');
    final request = EditSessionRequest.fromJson({
      ...original.toJson(),
      'recipe': recipe.toJson(),
      'origin': null,
      'baseRecipe': null,
      'context': {...original.context.toJson(), 'media': media?.toJson()},
    });
    sessions = FakeEditSessionService(requests: {'filters': request});
    await pumpApp(
      tester,
      core: core,
      view: popup ? const Size(1060, 820) : const Size(1240, 900),
      overrides: [
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        presetLibraryProvider.overrideWithValue(FakePresetLibrary(presets: [preset.copyWith(recipe: recipe)])),
        machineSettingsRepositoryProvider.overrideWithValue(machine),
        capabilityCacheProvider.overrideWithValue(FakeCapabilityCache(capabilities: [capabilities])),
        if (popup) ...[
          launchModeProvider.overrideWithValue(const EditSessionLaunch('filters')),
          editSessionServiceProvider.overrideWithValue(sessions),
          popupVersionsProvider.overrideWith((ref) async => matchingPopupVersions),
        ],
      ],
    );
  }

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(VeApp)));
  EditorData data(WidgetTester tester) => container(tester).read(popup ? popupEditorProvider : editorProvider)!;

  void edit(WidgetTester tester, Recipe Function(Recipe) change) {
    final scope = container(tester);
    if (popup) {
      scope.read(popupProvider.notifier).edit(change);
    } else {
      scope.read(presetsControllerProvider.notifier).edit(change);
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.last);
    await tester.pumpAndSettle();
    await tester.tap(finder.last);
    await tester.pumpAndSettle();
  }

  Future<void> expand(WidgetTester tester) =>
      tap(tester, find.bySemanticsLabel(RegExp(r'^Video filters\.')));
  Future<void> add(WidgetTester tester) async {
    await tap(tester, find.widgetWithText(VeButton, 'Add filter'));
    await tap(tester, find.descendant(of: find.byType(VeListbox<String>), matching: find.text('Resize / Upscale')));
  }

  Future<void> select(WidgetTester tester, String field, String option) async {
    await tap(tester, find.bySemanticsLabel(field));
    await tap(tester, find.descendant(of: find.byType(VeListbox<String>), matching: find.text(option)));
  }

  Future<void> apply(WidgetTester tester) => tap(tester, find.widgetWithText(VeButton, 'Apply'));
}
