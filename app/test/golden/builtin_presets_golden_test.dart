// Product built-ins with the real core and file library, then fake UI services.
// No user profile, FFmpeg or real VEGAS is accessed.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/app/launch.dart';
import 'package:vegas_encoder/design/components/button.dart';
import 'package:vegas_encoder/design/components/command_view.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/popup.dart';
import 'package:vegas_encoder/state/popup_version.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

void main() {
  late NativeVeCore core;
  late List<Preset> builtins;
  late EditSessionRequest request;

  setUpAll(() async {
    core = NativeVeCore();
    final boundary = Directory('../build/test-results').absolute;
    await boundary.create(recursive: true);
    final root = await boundary.createTemp('builtin-presets-');
    final paths = ServicePaths(roaming: '${root.path}/roaming', local: '${root.path}/local');
    builtins = await FilePresetLibrary(core: core, paths: paths).list();
    expect(builtins, hasLength(16));
    expect(builtins.every((p) => p.builtin && p.requires.known), isTrue);
    expect(File(paths.machine).existsSync(), isFalse);
    expect(Directory(paths.library).existsSync(), isFalse, reason: 'built-ins are bundled, never seeded as user files');
    request = await FakeEditSessionService().readRequest('b0-session');
  });

  testWidgets('a newer bundled recipe leaves a saved template unchanged until explicit update', (tester) async {
    final hevc = builtins.firstWhere((p) => p.recipe.id == 'hevc-10bit');
    final newer = hevc.copyWith(
      revision: 2,
      recipe: hevc.recipe.copyWith(video: hevc.recipe.video.copyWith(quality: 20)),
    );
    final saved = EditSessionRequest.fromJson({
      ...request.toJson(),
      'recipe': hevc.recipe.copyWith(name: 'My saved HEVC', video: hevc.recipe.video.copyWith(quality: 29)).toJson(),
      'origin': Origin(presetId: hevc.recipe.id, revision: 1, name: hevc.recipe.name).toJson(),
      'baseRecipe': hevc.recipe.toJson(),
    });
    await pumpApp(
      tester,
      core: core,
      view: const Size(1120, 740),
      overrides: [
        launchModeProvider.overrideWithValue(const EditSessionLaunch('session')),
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        presetLibraryProvider.overrideWithValue(FakePresetLibrary(presets: [newer])),
        editSessionServiceProvider.overrideWithValue(FakeEditSessionService(requests: {'session': saved})),
        popupVersionsProvider.overrideWith((ref) async => matchingPopupVersions),
      ],
    );
    final container = ProviderScope.containerOf(tester.element(find.widgetWithText(VeButton, 'Load preset')));
    expect(container.read(popupProvider).requireValue.recipe.video.quality, 29);
    expect(find.text('Library has revision 2'), findsOneWidget);
    await tester.tap(find.text('Update from library'));
    await tester.pumpAndSettle();
    expect(container.read(popupProvider).requireValue.recipe.video.quality, 29);
    await tester.tap(find.text('Replace with revision 2'));
    await tester.pumpAndSettle();
    final updated = container.read(popupProvider).requireValue;
    expect(updated.recipe.video.quality, 20);
    expect(updated.origin!.revision, 2);
    expect(updated.recipe.name, 'My saved HEVC');
  });

  for (final brightness in themes) {
    final theme = themeName(brightness);
    testWidgets('product 720p NVENC starter $theme', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      final preset = builtins.firstWhere((p) => p.recipe.id == 'h264-nvenc-720p-3500');
      await pumpApp(
        tester,
        core: core,
        overrides: [
          windowControllerProvider.overrideWithValue(FakeWindowController()),
          presetLibraryProvider.overrideWithValue(FakePresetLibrary(presets: [preset])),
        ],
      );
      await tester.tap(find.text('H.264 720p 3500kbps (NVENC)').first);
      await tester.pumpAndSettle();
      final command = tester
          .widget<RichText>(find.descendant(of: find.byType(CommandView), matching: find.byType(RichText)))
          .text
          .toPlainText();
      expect(command, contains('h264_nvenc'));
      expect(command, contains('3500k'));
      expect(command, contains('scale=1280:720'));
      expect(command, contains('pad=1280:720'));
      expect(command, contains('160k'));
      await expectGolden('builtins_nvenc_720p_$theme');
    });

    testWidgets('product builtin library and software HEVC $theme', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await pumpApp(
        tester,
        core: core,
        overrides: [
          windowControllerProvider.overrideWithValue(FakeWindowController()),
          presetLibraryProvider.overrideWithValue(FakePresetLibrary(presets: builtins)),
        ],
      );
      await tester.tap(find.text('H.265 / HEVC, 10-bit').first);
      await tester.pumpAndSettle();
      final command = tester
          .widget<RichText>(find.descendant(of: find.byType(CommandView), matching: find.byType(RichText)))
          .text
          .toPlainText();
      expect(command, contains('libx265'));
      expect(command, contains('aac'));
      expect(command, contains('yuv420p10le'));
      await expectGolden('builtins_hevc_$theme');
    });

    testWidgets('product popup load and linked origin $theme', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await pumpApp(
        tester,
        core: core,
        view: const Size(1120, 740),
        overrides: [
          launchModeProvider.overrideWithValue(const EditSessionLaunch('session')),
          windowControllerProvider.overrideWithValue(FakeWindowController()),
          presetLibraryProvider.overrideWithValue(FakePresetLibrary(presets: builtins)),
          editSessionServiceProvider.overrideWithValue(FakeEditSessionService(requests: {'session': request})),
          popupVersionsProvider.overrideWith((ref) async => matchingPopupVersions),
        ],
      );
      await tester.tap(find.widgetWithText(VeButton, 'Load preset'));
      await tester.pumpAndSettle();
      await expectGolden('builtins_popup_load_$theme');
      await tester.tap(find.text('H.265 / HEVC, 10-bit'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.widgetWithText(VeButton, 'Load preset')));
      final state = container.read(popupProvider).requireValue;
      expect(state.recipe.video.encoder, 'libx265');
      expect(state.recipe.video.depth, 10);
      expect(state.recipe.container.format, 'mp4');
      expect(state.origin!.presetId, 'hevc-10bit');
      expect(state.origin!.revision, 1);
      expect(state.libraryPreset!.builtin, isTrue);
      expect(state.recipe.name, request.recipe.name, reason: 'the VEGAS template keeps its own name');
      await expectGolden('builtins_popup_origin_$theme');
    });

    testWidgets('last starter loads from the scrolled popup list $theme', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await pumpApp(
        tester,
        core: core,
        view: const Size(1120, 740),
        overrides: [
          launchModeProvider.overrideWithValue(const EditSessionLaunch('session')),
          windowControllerProvider.overrideWithValue(FakeWindowController()),
          presetLibraryProvider.overrideWithValue(FakePresetLibrary(presets: builtins)),
          editSessionServiceProvider.overrideWithValue(FakeEditSessionService(requests: {'session': request})),
          popupVersionsProvider.overrideWith((ref) async => matchingPopupVersions),
        ],
      );
      await tester.tap(find.widgetWithText(VeButton, 'Load preset'));
      await tester.pumpAndSettle();
      final last = find.text('H.264 720p 3500kbps (NVENC)');
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.widgetWithText(VeButton, 'Load preset')));
      final state = container.read(popupProvider).requireValue;
      expect(state.origin!.presetId, 'h264-nvenc-720p-3500');
      expect(state.recipe.video.bitrateK, 3500);
      expect(state.recipe.video.extra, contains('scale=1280:720'));
    });
  }
}
