// Product built-ins with the real core and file library, then fake UI services.
// No user profile, FFmpeg or real VEGAS is accessed.
import 'dart:convert';
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
  late Preset personal720p;
  late EditSessionRequest request;
  late FakeCapabilityCache capabilities;

  setUpAll(() async {
    core = NativeVeCore();
    final boundary = Directory('../build/test-results').absolute;
    await boundary.create(recursive: true);
    final root = await boundary.createTemp('builtin-presets-');
    final paths = ServicePaths(roaming: '${root.path}/roaming', local: '${root.path}/local');
    builtins = await FilePresetLibrary(core: core, paths: paths).list();
    personal720p = Preset.fromJson(
      jsonMap(jsonDecode(await File('../schema/fixtures/retired-presets/h264-nvenc-720p-3500.v2.json').readAsString())),
    ).copyWith(builtin: false);
    expect(builtins, hasLength(12));
    expect(builtins.every((p) => p.builtin && p.requires.known), isTrue);
    expect(File(paths.machine).existsSync(), isFalse);
    expect(Directory(paths.library).existsSync(), isFalse, reason: 'built-ins are bundled, never seeded as user files');
    request = await FakeEditSessionService().readRequest('b0-session');
    final settings = await FakeMachineSettingsRepository().read();
    final installation = settings.installations.singleWhere((i) => i.id == settings.defaultFFmpegId);
    final progress = await FakeFFmpegProbe().probe(installation).last;
    capabilities = FakeCapabilityCache(
      capabilities: [
        progress.capabilities!.copyWith(
          filters: {
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
        ),
      ],
    );
  });

  testWidgets('a newer bundled recipe leaves a saved template unchanged until explicit update', (tester) async {
    final hevc = builtins.firstWhere((p) => p.recipe.id == 'hevc-10bit');
    final previous = hevc.recipe.copyWith(audio: [hevc.recipe.audio.single.copyWith(bitrateK: 320)]);
    final saved = EditSessionRequest.fromJson({
      ...request.toJson(),
      'recipe': previous.copyWith(name: 'My saved HEVC', video: previous.video.copyWith(quality: 29)).toJson(),
      'origin': Origin(presetId: hevc.recipe.id, revision: 2, name: hevc.recipe.name).toJson(),
      'baseRecipe': previous.toJson(),
    });
    await pumpApp(
      tester,
      core: core,
      view: const Size(1120, 740),
      overrides: [
        launchModeProvider.overrideWithValue(const EditSessionLaunch('session')),
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        presetLibraryProvider.overrideWithValue(FakePresetLibrary(presets: [hevc])),
        editSessionServiceProvider.overrideWithValue(FakeEditSessionService(requests: {'session': saved})),
        popupVersionsProvider.overrideWith((ref) async => matchingPopupVersions),
      ],
    );
    final container = ProviderScope.containerOf(tester.element(find.widgetWithText(VeButton, 'Load preset')));
    expect(container.read(popupProvider).requireValue.recipe.video.quality, 29);
    expect(container.read(popupProvider).requireValue.recipe.audio.single.bitrateK, 320);
    expect(find.text('Library has revision 3'), findsOneWidget);
    await tester.tap(find.text('Update from library'));
    await tester.pumpAndSettle();
    expect(container.read(popupProvider).requireValue.recipe.video.quality, 29);
    await tester.tap(find.text('Replace with revision 3'));
    await tester.pumpAndSettle();
    final updated = container.read(popupProvider).requireValue;
    expect(updated.recipe.video.quality, hevc.recipe.video.quality);
    expect(updated.recipe.audio.single.bitrateK, 256);
    expect(updated.origin!.revision, 3);
    expect(updated.recipe.name, 'My saved HEVC');
  });

  for (final brightness in themes) {
    final theme = themeName(brightness);
    testWidgets('personal 720p NVENC export remains editable $theme', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      final preset = personal720p;
      expect(builtins.any((p) => p.recipe.id == preset.recipe.id), isFalse);
      await pumpApp(
        tester,
        core: core,
        overrides: [
          windowControllerProvider.overrideWithValue(FakeWindowController()),
          presetLibraryProvider.overrideWithValue(FakePresetLibrary(presets: [preset])),
          capabilityCacheProvider.overrideWithValue(capabilities),
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
      expect(preset.revision, 2);
      expect(preset.recipe.schema, 2);
      expect(preset.recipe.video.extra, isEmpty);
      expect(preset.recipe.video.filters.single.width, 1280);
      expect(preset.recipe.video.filters.single.height, 720);
      expect(command, contains('scale='));
      expect(command, contains('flags=bicubic'));
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
      await tester.tap(find.text('HEVC (CPU)').first);
      await tester.pumpAndSettle();
      final command = tester
          .widget<RichText>(find.descendant(of: find.byType(CommandView), matching: find.byType(RichText)))
          .text
          .toPlainText();
      expect(command, contains('libx265'));
      expect(command, contains('aac'));
      expect(command, contains('256k'));
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
      await tester.tap(find.text('HEVC (CPU)'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.widgetWithText(VeButton, 'Load preset')));
      final state = container.read(popupProvider).requireValue;
      expect(state.recipe.video.encoder, 'libx265');
      expect(state.recipe.video.depth, 10);
      expect(state.recipe.container.format, 'mp4');
      expect(state.origin!.presetId, 'hevc-10bit');
      expect(state.recipe.audio.single.bitrateK, 256);
      expect(state.origin!.revision, 3);
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
      final last = find.text('VP9 (CPU)');
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.widgetWithText(VeButton, 'Load preset')));
      final state = container.read(popupProvider).requireValue;
      expect(state.origin!.presetId, 'vp9-webm');
      expect(state.recipe.video.encoder, 'libvpx-vp9');
      expect(state.recipe.video.quality, 31);
      expect(state.recipe.container.format, 'webm');
      expect(state.recipe.video.extra, isEmpty);
      expect(state.recipe.video.filters, isEmpty);
      expect(state.recipe.schema, 1);
    });
  }
}
