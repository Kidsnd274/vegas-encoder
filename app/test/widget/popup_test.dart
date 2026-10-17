import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/app/app.dart' show VeApp;
import 'package:vegas_encoder/app/launch.dart';
import 'package:vegas_encoder/design/components/button.dart';
import 'package:vegas_encoder/design/components/command_editor.dart' show CommandEditor;
import 'package:vegas_encoder/design/components/signal_path/signal_path.dart';
import 'package:vegas_encoder/features/popup/popup_editor.dart' show LibrarySection;
import 'package:vegas_encoder/features/presets/panels/extra_field.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/popup.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

/// The VEGAS popup (F5, UI_SPEC §4) on the native core (B2) and the
/// platform's fake services: requests and results through a fake
/// EditSessionService, the fake library (`yt-h264` at revision 6). No FFmpeg,
/// no VEGAS: VEGAS's own Apply/OK commit (A6) is not here.
void main() {
  late NativeVeCore core;
  late EditSessionRequest b0;
  late FakeEditSessionService sessions;
  late FakeWindowController window;
  late FakePresetLibrary library;

  setUpAll(() async {
    core = NativeVeCore();
    b0 = await FakeEditSessionService().readRequest('b0-session');
  });

  Future<void> pump(
    WidgetTester tester, {
    EditSessionRequest? request,
    bool noRequest = false,
    FakeEditSessionService? service,
    FakePresetLibrary? presets,
    Size view = const Size(1120, 740),
    List<Override> overrides = const [],
  }) async {
    sessions = service ?? FakeEditSessionService(requests: noRequest ? {} : {'session': request ?? b0});
    window = FakeWindowController();
    library = presets ?? FakePresetLibrary(now: () => '2026-10-14T03:00:00Z');
    await pumpApp(
      tester,
      view: view,
      core: core,
      overrides: [
        launchModeProvider.overrideWithValue(const EditSessionLaunch('session')),
        windowControllerProvider.overrideWithValue(window),
        editSessionServiceProvider.overrideWithValue(sessions),
        presetLibraryProvider.overrideWithValue(library),
        ...overrides,
      ],
    );
  }

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(VeApp)));
  PopupState state(WidgetTester tester) => container(tester).read(popupProvider).requireValue;
  EditSessionResult? result() => sessions.resultFor('session');
  Finder rich(String text) => find.textContaining(text, findRichText: true);
  Finder extraField() => find.descendant(of: find.byType(ExtraArgumentsField), matching: find.byType(TextField));
  Finder fieldWith(String text) =>
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text, description: 'field "$text"');
  SignalPathModel strip(WidgetTester tester) => tester.widget<SignalPath>(find.byType(SignalPath)).model;
  VeButton button(WidgetTester tester, String label) => tester.widget<VeButton>(find.widgetWithText(VeButton, label));

  Future<void> keys(WidgetTester tester, LogicalKeyboardKey key, {bool control = false}) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  EditSessionRequest withRequest(Map<String, Object?> changes) =>
      EditSessionRequest.fromJson({...b0.toJson(), ...changes});

  group('opening', () {
    testWidgets('the template, its origin and the VEGAS facts in the strip', (tester) async {
      await pump(tester);
      expect(find.text('YouTube 4K upload (Lakeside)'), findsOneWidget);
      expect(rich('From YouTube upload, H.264, revision 5. 2 changes in this template'), findsOneWidget);
      expect(find.text('Show changes'), findsOneWidget);
      expect(rich('Rename in VEGAS to change the saved template name.'), findsOneWidget);
      final m = strip(tester);
      expect(m.source.frameSize, '3840×2160', reason: 'the project VEGAS shared');
      expect(m.source.stripVideo, '29.97 fps, 10-bit');
      expect(m.marks[SignalNode.video]!.changed, isTrue, reason: 'CRF 17, slower: changed in this template');
      expect(m.marks[SignalNode.audio]!.libraryRevision, 6, reason: 'the library changed the audio bitrate');
      expect(find.text('Library has revision 6'), findsOneWidget);
      expect(find.text('Vegas Encoder, editing a VEGAS render template'), findsOneWidget);
    });

    testWidgets('project facts VEGAS didn’t share are “Set by the project”; the preview is a sample', (tester) async {
      final context = b0.context.toJson()..['media'] = null;
      await pump(tester, request: withRequest({'context': context}));
      final m = strip(tester);
      expect(m.source.frameSize, 'Set by the project');
      expect(m.source.stripVideo, startsWith('Sample: '));
      await tap(tester, find.text('From VEGAS').first);
      expect(find.text('Set by the project'), findsWidgets);
      expect(rich('VEGAS didn’t share this project’s settings. The command and checks use a sample:'), findsOneWidget);
      expect(container(tester).read(popupEditorProvider)!.compiled.ok, isTrue, reason: 'still compiled, on the sample');
    });

    testWidgets('a missing request is shown, and closing it is a Cancel with no result', (tester) async {
      await pump(tester, noRequest: true);
      expect(rich('Vegas Encoder couldn’t open this template: No request fixture for this directory.'), findsOneWidget);
      expect(find.text('Closing this window leaves the template as it was.'), findsOneWidget);
      expect(button(tester, 'Apply to template').onPressed, isNull);
      await tap(tester, find.widgetWithText(VeButton, 'Cancel'));
      expect(window.calls, contains('close'));
      expect(result(), isNull, reason: 'no session to answer (C4: no result means cancel)');
      expect(await tester.binding.handleRequestAppExit(), AppExitResponse.exit);
    });

    testWidgets('--edit-session without a directory is shown in the popup', (tester) async {
      await pumpApp(
        tester,
        view: const Size(1120, 740),
        overrides: [
          launchModeProvider.overrideWithValue(
            const LaunchError('--edit-session', '--edit-session needs a path after it.'),
          ),
          windowControllerProvider.overrideWithValue(FakeWindowController()),
        ],
      );
      expect(find.text('--edit-session needs a path after it.'), findsOneWidget);
    });

    testWidgets('a narrow popup docks the library and command at the bottom, collapsed', (tester) async {
      await pump(tester, view: const Size(960, 640));
      expect(find.text('Library and command'), findsOneWidget);
      expect(find.text('Library has revision 6. No errors.'), findsOneWidget);
      expect(find.text('Update from library'), findsNothing, reason: 'collapsed');
      await tap(tester, find.text('Library and command'));
      expect(find.text('Update from library'), findsOneWidget);
      expect(find.text('Command'), findsOneWidget, reason: 'the side column, docked');
    });

    test('the owner window is the request’s decimal HWND', () {
      expect(ownerHwndOf(b0), 123456);
      expect(ownerHwndOf(withRequest({'ownerHwnd': 'nope'})), isNull);
      expect(ownerHwndOf(withRequest({'ownerHwnd': '0'})), isNull);
    });
  });

  group('Apply and Cancel', () {
    testWidgets('Apply (Ctrl+Enter) writes the complete settings and the origin, once, then closes', (tester) async {
      await pump(tester);
      await tester.enterText(fieldWith('17'), '19');
      await tester.pumpAndSettle();
      await keys(tester, LogicalKeyboardKey.enter, control: true);
      final r = result()!;
      expect(r.action, 'apply');
      expect(r.sessionId, 'b0-edit-session');
      expect(r.recipe!.video.quality, 19);
      expect(r.recipe!.name, 'YouTube 4K upload (Lakeside)');
      expect(r.origin!.toJson(), b0.origin!.toJson());
      expect(window.calls, contains('close'));
      expect(await tester.binding.handleRequestAppExit(), AppExitResponse.exit, reason: 'answered: closing is free');
      await keys(tester, LogicalKeyboardKey.enter, control: true);
      expect(result()!.recipe!.video.quality, 19, reason: 'one final result per session');
    });

    testWidgets('Cancel with nothing changed writes a cancel at once', (tester) async {
      await pump(tester);
      await tap(tester, find.widgetWithText(VeButton, 'Cancel'));
      expect(result()!.action, 'cancel');
      expect(result()!.recipe, isNull);
      expect(result()!.origin, isNull);
      expect(window.calls, contains('close'));
    });

    testWidgets('Apply remembers the restored physical size before closing', (tester) async {
      await pump(tester);
      window.restored = (bounds: (x: -1100, y: 70, width: 1280, height: 800), maximized: false);
      await keys(tester, LogicalKeyboardKey.enter, control: true);
      final saved = await container(tester).read(machineSettingsRepositoryProvider).read();
      expect(saved.uiState!.popupWindowSize!.width, 1280);
      expect(saved.uiState!.popupWindowSize!.height, 800);
      expect(window.calls, contains('close'));
    });

    testWidgets('Cancel remembers size without saving the template changes', (tester) async {
      await pump(tester);
      window.restored = (bounds: (x: 70, y: 80, width: 1180, height: 760), maximized: false);
      await tap(tester, find.widgetWithText(VeButton, 'Cancel'));
      final saved = await container(tester).read(machineSettingsRepositoryProvider).read();
      expect(saved.uiState!.popupWindowSize!.width, 1180);
      expect(saved.uiState!.popupWindowSize!.height, 760);
      expect(result()!.action, 'cancel');
      expect(window.calls, contains('close'));
    });

    testWidgets('Esc with changes asks first; Keep editing keeps the popup open', (tester) async {
      await pump(tester);
      await tester.enterText(fieldWith('17'), '20');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await keys(tester, LogicalKeyboardKey.escape);
      expect(find.text('Discard changes to this template?'), findsOneWidget);
      await tap(tester, find.text('Keep editing'));
      expect(result(), isNull);
      expect(window.calls, isNot(contains('close')));
      await tap(tester, find.widgetWithText(VeButton, 'Cancel'));
      await tap(tester, find.text('Discard changes'));
      expect(result()!.action, 'cancel');
      expect(window.calls, contains('close'));
    });

    testWidgets('the title bar’s close and Alt+F4 behave as Cancel, with the same question', (tester) async {
      await pump(tester);
      await tester.enterText(fieldWith('17'), '21');
      await tester.pumpAndSettle();
      final exit = tester.binding.handleRequestAppExit();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes to this template?'), findsOneWidget);
      await tap(tester, find.text('Discard changes'));
      expect(await exit, AppExitResponse.cancel, reason: 'the popup closes itself once the cancel is written');
      expect(result()!.action, 'cancel');
      expect(window.calls, contains('close'));

      expect(find.bySemanticsLabel('Cancel'), findsWidgets, reason: 'the title bar’s close is labelled Cancel');
    });

    testWidgets('a cancel that can’t be written still closes, without asking twice', (tester) async {
      await pump(tester, service: _FailingSessions({'session': b0}));
      await tester.enterText(fieldWith('17'), '22');
      await tester.pumpAndSettle();
      await tap(tester, find.widgetWithText(VeButton, 'Cancel'));
      await tap(tester, find.text('Discard changes'));
      expect(window.calls, contains('close'));
      expect(await tester.binding.handleRequestAppExit(), AppExitResponse.exit, reason: 'no second question');
      expect(find.text('Discard changes to this template?'), findsNothing);
    });
    testWidgets('errors turn Apply off and say why; Ctrl+Enter writes nothing', (tester) async {
      await pump(tester);
      // Extra arguments can't choose the encoder: the core's error.
      await tester.enterText(extraField(), '-c:v libx265');
      await tester.pumpAndSettle();
      expect(container(tester).read(popupEditorProvider)!.hasErrors, isTrue);
      expect(button(tester, 'Apply to template').onPressed, isNull);
      expect(find.text('Fix the errors first. The template can’t render with them.'), findsOneWidget);
      await keys(tester, LogicalKeyboardKey.enter, control: true);
      expect(result(), isNull);
      await tester.enterText(extraField(), '');
      await tester.pumpAndSettle();
      expect(button(tester, 'Apply to template').onPressed, isNotNull);
    });
  });

  group('origin and library', () {
    testWidgets('Load preset replaces the settings at once, with Undo', (tester) async {
      await pump(tester);
      await tap(tester, find.widgetWithText(VeButton, 'Load preset'));
      expect(find.text('Loading replaces the template’s settings right away. You can undo it.'), findsOneWidget);
      await tap(tester, find.text('Lossless master, FFV1'));
      final s = state(tester);
      expect(s.recipe.video.encoder, 'ffv1');
      expect(s.recipe.name, 'YouTube 4K upload (Lakeside)', reason: 'the template keeps its own name');
      expect(s.origin!.presetId, 'ffv1-master');
      expect(find.text('Loaded “Lossless master, FFV1”.'), findsOneWidget);
      expect(rich('From preset Lossless master, FFV1, revision 1.'), findsOneWidget);
      await tap(tester, find.text('Undo'));
      expect(state(tester).recipe.video.encoder, 'libx264');
      expect(state(tester).origin!.revision, 5);
      expect(find.text('Library has revision 6'), findsOneWidget);
    });

    testWidgets('Update from library: what you get, what you keep, and “Take library changes, keep mine”', (
      tester,
    ) async {
      await pump(tester);
      await tap(tester, find.text('Update from library'));
      expect(find.text('Changes in the library since revision 5'), findsOneWidget);
      expect(find.text('Your changes in this template'), findsOneWidget);
      expect(find.text('Audio bitrate'), findsOneWidget);
      expect(find.text('320 kb/s'), findsOneWidget);
      expect(find.text('CRF 18'), findsOneWidget);
      expect(find.text('CRF 17'), findsOneWidget);
      expect(find.text('Encoder speed'), findsWidgets);
      expect(button(tester, 'Take library changes, keep mine').onPressed, isNotNull, reason: 'no setting in both');
      await tap(tester, find.text('Take library changes, keep mine'));
      final s = state(tester);
      expect(s.recipe.audio.first.bitrateK, 320, reason: 'the library’s change');
      expect(s.recipe.video.quality, 17, reason: 'mine kept');
      expect(s.recipe.video.speed, 'slower');
      expect(s.origin!.revision, 6);
      expect(find.text('Took the revision 6 changes and kept yours.'), findsOneWidget);
      expect(find.text('Library has revision 6'), findsNothing);
      expect(rich('From YouTube upload, H.264, revision 6. 2 changes in this template'), findsOneWidget);
    });

    testWidgets('Replace with revision 6 takes the library’s settings and keeps the name', (tester) async {
      await pump(tester);
      await tap(tester, find.text('Update from library'));
      await tap(tester, find.text('Replace with revision 6'));
      final s = state(tester);
      expect(s.recipe.video.quality, 18);
      expect(s.recipe.audio.first.bitrateK, 320);
      expect(s.recipe.name, 'YouTube 4K upload (Lakeside)');
      expect(rich('From preset YouTube upload, H.264, revision 6.'), findsOneWidget);
      await tap(tester, find.text('Undo'));
      expect(state(tester).recipe.video.quality, 17);
    });

    testWidgets('a setting changed in both places turns off “keep mine”', (tester) async {
      final recipe = b0.recipe.toJson();
      (recipe['audio'] as List).first['bitrateK'] = 192;
      await pump(tester, request: withRequest({'recipe': recipe}));
      await tap(tester, find.text('Update from library'));
      final merge = button(tester, 'Take library changes, keep mine');
      expect(merge.onPressed, isNull);
      expect(merge.tooltip, 'Some settings changed in both places.');
    });

    testWidgets('without a copy of its revision, only Replace is offered', (tester) async {
      await pump(tester, request: withRequest({'baseRecipe': null}));
      expect(rich('From preset YouTube upload, H.264, revision 5.'), findsOneWidget, reason: 'changes unknown');
      await tap(tester, find.text('Update from library'));
      expect(rich('This template doesn’t carry a copy of revision 5'), findsOneWidget);
      expect(find.text('Take library changes, keep mine'), findsNothing);
      expect(find.text('Replace with revision 6'), findsOneWidget);
      expect(find.text('This template and revision 6'), findsOneWidget);
    });

    testWidgets('Show changes lists the template’s own changes', (tester) async {
      await pump(tester);
      await tap(tester, find.text('Show changes'));
      expect(find.text('Changes in this template'), findsOneWidget);
      expect(find.text('Quality'), findsWidgets);
      expect(find.text('slower'), findsWidgets);
      await tap(tester, find.widgetWithText(VeButton, 'Close'));
      expect(find.text('Changes in this template'), findsNothing);
    });

    testWidgets('made in VEGAS: no origin, and nothing to update', (tester) async {
      await pump(tester, request: withRequest({'origin': null, 'baseRecipe': null}));
      expect(rich('Made in VEGAS'), findsWidgets);
      await tap(tester, find.widgetWithText(VeButton, 'Save to library'));
      expect(find.text('This template has no preset in the library to update.'), findsOneWidget);
    });

    testWidgets('an origin the library no longer has keeps all its settings', (tester) async {
      await pump(tester, presets: FakePresetLibrary(presets: const []));
      expect(
        rich(
          'Preset YouTube upload, H.264 no longer exists in your library. This template still has all its settings.',
        ),
        findsWidgets,
      );
      expect(find.text('Not in the library'), findsOneWidget);
    });

    testWidgets('Save as new preset… adds it to Mine and makes it the origin', (tester) async {
      await pump(tester);
      await tap(tester, find.widgetWithText(VeButton, 'Save to library'));
      expect(find.text('Built-in presets can’t be changed.'), findsOneWidget, reason: 'Update is off for built-ins');
      await tap(tester, find.text('Save as new preset…'));
      await tester.enterText(find.byType(EditableText).last, 'Lakeside upload');
      await tap(tester, find.widgetWithText(VeButton, 'Save'));
      final saved = (await library.list()).where((p) => !p.builtin).single;
      expect(saved.recipe.name, 'Lakeside upload');
      expect(saved.origin, 'builtin/yt-h264');
      expect(saved.recipe.video.quality, 17);
      expect(state(tester).origin!.presetId, saved.recipe.id);
      expect(find.text('Saved “Lakeside upload” to the library.'), findsOneWidget);
      await tap(tester, find.widgetWithText(VeButton, 'Save to library'));
      expect(find.text('Update “Lakeside upload” (revision 1 → 2)'), findsOneWidget);
    });

    testWidgets('Save to library warns first and saves nothing while the settings have errors', (tester) async {
      await pump(tester);
      await tester.enterText(extraField(), '-c:v libx265');
      await tester.pumpAndSettle();
      await tap(tester, find.widgetWithText(VeButton, 'Save to library'));
      await tap(tester, find.text('Save as new preset…'));
      expect(find.text('Fix the errors before saving'), findsOneWidget, reason: 'owner decision, 2026-10-15');
      await tap(tester, find.text('Keep editing'));
      expect(find.text('Save as new preset'), findsNothing, reason: 'no name asked for');
      expect((await library.list()).where((p) => !p.builtin), isEmpty);
    });

    testWidgets('Update “origin” saves the template’s settings at the preset’s next revision', (tester) async {
      final mine = Preset(
        revision: 3,
        updatedAt: '2026-10-13T00:00:00Z',
        requires: PresetRequirements(),
        recipe: b0.baseRecipe!.copyWith(id: 'client-h264', name: 'Client H.264'),
      );
      await pump(
        tester,
        presets: FakePresetLibrary(presets: [mine], now: () => '2026-10-14T03:00:00Z'),
        request: withRequest({'origin': Origin(presetId: 'client-h264', revision: 3, name: 'Client H.264').toJson()}),
      );
      await tap(tester, find.widgetWithText(VeButton, 'Save to library'));
      await tap(tester, find.text('Update “Client H.264” (revision 3 → 4)'));
      final saved = (await library.get('client-h264'))!;
      expect(saved.revision, 4);
      expect(saved.recipe.video.quality, 17);
      expect(saved.recipe.name, 'Client H.264', reason: 'the preset keeps its own name');
      expect(state(tester).origin!.revision, 4);
      expect(find.text('Updated “Client H.264” to revision 4.'), findsOneWidget);
    });

    testWidgets('Open in Vegas Encoder waits for a platform service', (tester) async {
      await pump(tester);
      final open = button(tester, 'Open in Vegas Encoder');
      expect(open.onPressed, isNull);
      expect(open.tooltip, contains('needs a platform service'));
    });

    testWidgets('Open in Vegas Encoder opens the origin preset when a service can', (tester) async {
      final launcher = _Launcher();
      await pump(tester, overrides: [desktopAppLauncherProvider.overrideWithValue(launcher)]);
      await tap(tester, find.descendant(of: find.byType(LibrarySection), matching: find.text('Open in Vegas Encoder')));
      expect(launcher.opened, ['yt-h264']);
    });
  });

  group('Advanced mode', () {
    testWidgets('Ctrl+M: the compact editor, the resolved command closed, diagnostics counted in the side', (
      tester,
    ) async {
      await pump(tester);
      await keys(tester, LogicalKeyboardKey.keyM, control: true);
      expect(find.byType(CommandEditor), findsOneWidget);
      expect(state(tester).recipe.command.mode, 'template');
      expect(find.text('Resolved command'), findsOneWidget);
      expect(find.text('ffmpeg -hide_banner', findRichText: true), findsNothing, reason: 'closed in the popup');
      expect(rich('Edit it below the diagram.'), findsOneWidget);
      expect(find.text('Macros'), findsNothing, reason: 'no desktop side column');
      expect(strip(tester).fromCommand, isTrue);

      final text = state(tester).recipe.command.template;
      final editor = find.descendant(of: find.byType(CommandEditor), matching: find.byType(EditableText));
      await tester.enterText(editor, text.replaceAll('{output}', ''));
      await tester.pumpAndSettle();
      expect(button(tester, 'Apply to template').onPressed, isNull, reason: 'the lint’s error blocks Apply');
      expect(find.text('Fix the errors first. The template can’t render with them.'), findsOneWidget);
    });
  });
}

class _Launcher implements DesktopAppLauncher {
  final List<String> opened = [];
  @override
  Future<void> openPreset(String presetId) async => opened.add(presetId);
  @override
  Future<void> openJob(String jobId) async => opened.add('job/$jobId');
}

/// A session whose result can't be written (a locked or vanished folder).
class _FailingSessions extends FakeEditSessionService {
  _FailingSessions(Map<String, EditSessionRequest> requests) : super(requests: requests);
  @override
  Future<void> writeResult(String directory, EditSessionResult result) async =>
      throw const ServiceException('FILE-WRITE', 'The session folder is gone.');
}
