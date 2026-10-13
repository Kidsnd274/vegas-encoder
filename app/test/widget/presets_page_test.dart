import 'dart:ui' show AppExitResponse;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart' hide SizeEstimate;
import 'package:vegas_encoder/design/components/field.dart' show VeField;
import 'package:vegas_encoder/design/components/size_card.dart';
import 'package:vegas_encoder/design/components/command_view.dart' show CommandView;
import 'package:vegas_encoder/design/components/signal_path/signal_path.dart' show SignalPath;
import 'package:vegas_encoder/features/presets/command_column.dart';
import 'package:vegas_encoder/features/presets/library_pane.dart';
import 'package:vegas_encoder/features/presets/panels/other_panels.dart' show ContainerPanel;
import 'package:vegas_encoder/features/presets/panels/video_panel.dart' show VideoPanel;
import 'package:vegas_encoder/features/presets/preset_header.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

/// The Presets screen (S1) on the platform fakes (B0): no FFmpeg, no VEGAS.
void main() {
  late FakePresetLibrary library;
  late FakeWindowController window;
  late FakeMachineSettingsRepository machine;

  Future<void> pump(
    WidgetTester tester, {
    Size view = const Size(1440, 900),
    MachineSettings? settings,
    ({WindowBounds bounds, bool maximized})? restored,
  }) async {
    library = FakePresetLibrary(now: () => '2026-10-12T02:00:00Z');
    window = FakeWindowController(const WindowState(), restored);
    machine = settings == null ? FakeMachineSettingsRepository() : FakeMachineSettingsRepository(settings: settings);
    await pumpApp(
      tester,
      view: view,
      overrides: [
        windowControllerProvider.overrideWithValue(window),
        presetLibraryProvider.overrideWithValue(library),
        machineSettingsRepositoryProvider.overrideWithValue(machine),
      ],
    );
  }

  Future<void> keys(WidgetTester tester, LogicalKeyboardKey key, {bool control = false, bool shift = false}) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  /// Whether keyboard focus is inside a widget of type [T].
  bool focusIn<T>() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    var found = false;
    context.visitAncestorElements((e) {
      found = e.widget is T;
      return !found;
    });
    return found;
  }

  Finder inHeader(String text) => find.descendant(of: find.byType(PresetHeader), matching: find.text(text));
  Finder inLibrary(Finder f) => find.descendant(of: find.byType(LibraryPane), matching: f);
  Finder inCommand(Finder f) => find.descendant(of: find.byType(CommandColumn), matching: f);
  Finder fieldWith(String text) =>
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text, description: 'field "$text"');

  Future<void> setCrf(WidgetTester tester, String value) async {
    await tester.enterText(fieldWith('18'), value);
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the first favorite; the diagram opens each node\'s settings', (tester) async {
    await pump(tester);
    expect(inHeader('YouTube upload, H.264'), findsOneWidget);
    expect(find.text('Encodes the frames'), findsOneWidget, reason: 'the video node is selected first');
    expect(inCommand(find.text('Checks')), findsOneWidget);

    await tester.tap(find.text('Sample project.mp4'));
    await tester.pumpAndSettle();
    expect(find.byType(SizeQualityCard), findsOneWidget);
    expect(find.text('About 53.7 MB per minute, typically 32.2 MB to 85.9 MB.'), findsOneWidget);
    expect(
      find.text('Total not available yet', findRichText: true),
      findsOneWidget,
      reason: 'B0 has no total for a typed length',
    );
    expect(find.text(r'D:\Renders\Sample project.mp4'), findsOneWidget);

    await tester.tap(find.text('320 kb/s').first);
    await tester.pumpAndSettle();
    expect(find.text('Encodes the samples'), findsOneWidget);
    expect(find.text('Kilobits per second for all channels together.'), findsOneWidget);

    await tester.tap(find.text('Fast start').first);
    await tester.pumpAndSettle();
    expect(find.text('Joins the streams into one file'), findsOneWidget);
    expect(find.text('Can’t hold H.264'), findsWidgets, reason: 'WebM can\'t hold H.264');

    await tester.tap(find.text('29.97 fps').first);
    await tester.pumpAndSettle();
    expect(find.text('What the project delivers'), findsOneWidget);
    expect(find.text('29.97 fps (30000/1001)'), findsOneWidget);
  });

  testWidgets('an edit marks the preset and explains the preview core; Revert and Undo', (tester) async {
    await pump(tester);
    await setCrf(tester, '17');
    expect(inHeader('Edited'), findsOneWidget);
    expect(find.text('CRF 17, slow'), findsOneWidget, reason: 'the diagram follows the recipe');
    expect(inCommand(find.textContaining('preview core only knows the built-in presets')), findsOneWidget);
    expect(inCommand(find.textContaining('Revert to see the shipped command')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('YouTube upload, H.264, unsaved changes')), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget, reason: 'the changed field has its own reset');

    await tester.tap(find.text('Revert'));
    await tester.pumpAndSettle();
    expect(inHeader('Edited'), findsNothing);
    expect(find.text('Reverted “YouTube upload, H.264”'), findsOneWidget);
    expect(inCommand(find.text('Copy')), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(inHeader('Edited'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(inHeader('Edited'), findsNothing, reason: 'resetting the only change makes the preset clean');
  });

  testWidgets('a built-in is saved as a new preset in Mine', (tester) async {
    await pump(tester);
    await setCrf(tester, '17');
    await tester.tap(find.text('Save as new preset'));
    await tester.pumpAndSettle();
    expect(find.text('Saved as a new preset in Mine'), findsOneWidget);
    expect(inHeader('YouTube upload, H.264 (copy)'), findsOneWidget);
    expect(inLibrary(find.text('Mine')), findsWidgets);
    expect(inHeader('Edited'), findsNothing);
    expect(find.text('Save preset'), findsOneWidget);
    final mine = (await library.list()).where((p) => !p.builtin).single;
    expect(mine.origin, 'builtin/yt-h264');
    expect(
      inCommand(find.textContaining('can’t build the command for this preset')),
      findsOneWidget,
      reason: 'the fake core knows only the built-ins as shipped',
    );
  });

  testWidgets('search, filters and an empty result', (tester) async {
    await pump(tester);
    await tester.enterText(inLibrary(find.byType(TextField)), 'nvenc');
    await tester.pumpAndSettle();
    expect(inLibrary(find.text('YouTube upload, HEVC on GPU')), findsOneWidget);
    expect(inLibrary(find.text('Small web file, AV1')), findsNothing);

    await tester.enterText(inLibrary(find.byType(TextField)), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No presets match “zzz”.'), findsOneWidget);
    await tester.tap(find.text('Show all presets'));
    await tester.pumpAndSettle();
    expect(inLibrary(find.text('Small web file, AV1')), findsOneWidget);
    expect(fieldWith(''), findsWidgets, reason: 'the search box is cleared too');

    await tester.tap(inLibrary(find.text('Mine')));
    await tester.pumpAndSettle();
    expect(find.text('No presets to show.'), findsOneWidget);
  });

  testWidgets('choosing an FFmpeg without x264 flags the preset and shows the core\'s error', (tester) async {
    await pump(tester);
    await tester.tap(find.text('FFmpeg 8.1 full (default)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FFmpeg 8.0 LGPL').last);
    await tester.pumpAndSettle();
    expect(inLibrary(find.text('Needs x264: not in this FFmpeg')), findsOneWidget);
    expect(inCommand(find.textContaining('isn’t in FFmpeg 8.0 LGPL')), findsOneWidget);
    expect(find.text('Not in this FFmpeg'), findsWidgets, reason: 'the picker and the node say so');
    expect(inCommand(find.text('FFmpeg 8.0 LGPL')), findsOneWidget);
  });

  testWidgets('"Show setting" opens the node that holds the field', (tester) async {
    await pump(tester);
    await tester.tap(inCommand(find.text('Show setting')).last);
    await tester.pumpAndSettle();
    expect(find.text('Joins the streams into one file'), findsOneWidget);
  });

  testWidgets('audio can be turned off and on again from its node', (tester) async {
    await pump(tester);
    await tester.tap(find.text('320 kb/s').first);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Audio'));
    await tester.pumpAndSettle();
    expect(find.text('Audio is off. The file has video only.'), findsOneWidget);
    expect(inHeader('Edited'), findsOneWidget);
    await tester.tap(find.text('29.97 fps').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audio is off. The file has video only.'));
    await tester.pumpAndSettle();
    expect(find.text('Encodes the samples'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Audio'));
    await tester.pumpAndSettle();
    expect(inHeader('Edited'), findsNothing);
  });

  testWidgets('the context menu duplicates; built-ins can\'t be renamed or deleted', (tester) async {
    await pump(tester);
    await tester.tap(inLibrary(find.text('Small web file, AV1')), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Built-in presets can’t be deleted.'), findsOneWidget);
    await tester.tap(find.text('Duplicate').last);
    await tester.pumpAndSettle();
    expect(find.text('Duplicated into Mine'), findsOneWidget);
    expect(inHeader('Small web file, AV1 (copy)'), findsOneWidget);

    await tester.tap(inLibrary(find.text('Small web file, AV1 (copy)')), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Web, small');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(inHeader('Web, small'), findsOneWidget);

    await tester.tap(inLibrary(find.text('Web, small')), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete…'));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Web, small”?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(inLibrary(find.text('Web, small')), findsNothing);
    expect(inHeader('YouTube upload, H.264'), findsOneWidget, reason: 'the first favorite is selected again');
  });

  testWidgets('a preset changed in another window: banner, keep editing, then choose on save', (tester) async {
    await pump(tester);
    await tester.tap(inLibrary(find.text('Small web file, AV1')), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate').last);
    await tester.pumpAndSettle();
    await tester.enterText(fieldWith('32'), '30');
    await tester.pumpAndSettle();

    final id = (await library.list()).where((p) => !p.builtin).single.recipe.id;
    final other = (await library.get(id))!;
    await tester.runAsync(
      () => library.save(
        other.copyWith(recipe: other.recipe.copyWith(notes: 'Edited in the popup')),
        expectedRevision: 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This preset changed in another window.'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('This preset changed in another window.'), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('“Small web file, AV1 (copy)” changed in another window'), findsOneWidget);
    await tester.tap(find.text('Replace it'));
    await tester.pumpAndSettle();
    expect(find.text('Preset saved'), findsOneWidget);
    final saved = (await library.get(id))!;
    expect(saved.revision, 3);
    expect(saved.recipe.video.quality, 30);
  });

  testWidgets('closing with unsaved changes asks first, however the window is closed', (tester) async {
    await pump(tester);
    expect(await tester.binding.handleRequestAppExit(), AppExitResponse.exit, reason: 'nothing to save');
    await setCrf(tester, '17');

    // The title bar's Close asks the runner to close; the engine then asks the
    // framework, as it does for Alt+F4 and the taskbar.
    await tester.tap(find.bySemanticsLabel('Close'));
    expect(window.calls, contains('close'));
    var response = tester.binding.handleRequestAppExit();
    await tester.pumpAndSettle();
    expect(find.text('Save changes to “YouTube upload, H.264”?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await response, AppExitResponse.cancel);

    response = tester.binding.handleRequestAppExit();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Don’t save'));
    await tester.pumpAndSettle();
    expect(await response, AppExitResponse.exit);
  });

  testWidgets('Save on close saves a built-in as a new preset, then exits', (tester) async {
    await pump(tester);
    await setCrf(tester, '17');
    final response = tester.binding.handleRequestAppExit();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(await response, AppExitResponse.exit);
    expect((await library.list()).where((p) => !p.builtin).single.recipe.video.quality, 17);
  });

  testWidgets('Ctrl+K opens a preset by name', (tester) async {
    await pump(tester);
    await keys(tester, LogicalKeyboardKey.keyK, control: true);
    expect(find.text('Open a preset by name, encoder or tag'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'prores');
    await tester.pumpAndSettle();
    await keys(tester, LogicalKeyboardKey.enter);
    expect(inHeader('ProRes 422 HQ for editing'), findsOneWidget);
    expect(find.text('Open a preset by name, encoder or tag'), findsNothing);
  });

  testWidgets('F6 and Shift+F6 move between the panes', (tester) async {
    await pump(tester);
    await keys(tester, LogicalKeyboardKey.f6);
    expect(focusIn<LibraryPane>(), isTrue);
    await keys(tester, LogicalKeyboardKey.f6);
    expect(focusIn<SignalPath>(), isTrue);
    await keys(tester, LogicalKeyboardKey.f6);
    expect(focusIn<VideoPanel>(), isTrue);
    await keys(tester, LogicalKeyboardKey.f6);
    expect(focusIn<CommandColumn>(), isTrue);
    await keys(tester, LogicalKeyboardKey.f6, shift: true);
    expect(focusIn<VideoPanel>(), isTrue);
  });

  testWidgets('"Show setting" focuses the control that holds the field', (tester) async {
    await pump(tester);
    await tester.tap(inCommand(find.text('Show setting')).last);
    await tester.pumpAndSettle();
    expect(focusIn<ContainerPanel>(), isTrue);
    await tester.tap(inCommand(find.text('Show setting')).first);
    await tester.pumpAndSettle();
    expect(focusIn<VideoPanel>(), isTrue);
  });

  testWidgets('bitrate modes take Mb/s with common values and say what they mean', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Bitrate'));
    await tester.pumpAndSettle();
    expect(find.text('Average bitrate'), findsOneWidget);
    expect(find.text('12 Mb/s average, no peak cap'), findsOneWidget);
    await tester.tap(find.text('Common').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('8 Mb/s').last);
    await tester.pumpAndSettle();
    expect(find.text('8 Mb/s average, no peak cap'), findsOneWidget);
    await tester.enterText(
      find.descendant(of: find.widgetWithText(VeField, 'Peak bitrate'), matching: find.byType(TextField)),
      '12',
    );
    await tester.pumpAndSettle();
    expect(find.text('8 Mb/s average, 12 Mb/s peak'), findsOneWidget);
  });

  testWidgets('an empty search offers a new preset', (tester) async {
    await pump(tester);
    await tester.enterText(inLibrary(find.byType(TextField)), 'zzz');
    await tester.pumpAndSettle();
    await tester.tap(find.text('New preset'));
    await tester.pumpAndSettle();
    expect(inHeader('New preset'), findsOneWidget);
    expect(find.text('Started a new preset in Mine from “YouTube upload, H.264”'), findsOneWidget);
    expect(inLibrary(find.text('New preset')), findsOneWidget, reason: 'the search was cleared');
  });

  testWidgets('presets with errors for the chosen FFmpeg are marked in the library', (tester) async {
    await pump(tester);
    expect(find.bySemanticsLabel(RegExp('YouTube upload, H.264, an error')), findsNothing);
    await tester.tap(find.text('FFmpeg 8.1 full (default)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FFmpeg 8.0 LGPL').last);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('YouTube upload, H.264, an error')), findsOneWidget);
  });

  testWidgets('the command switches between grouped lines and one line', (tester) async {
    await pump(tester);
    String plain() => tester
        .widget<RichText>(find.descendant(of: find.byType(CommandView), matching: find.byType(RichText)))
        .text
        .toPlainText();
    expect(plain(), contains(' ^\n'));
    await tester.tap(find.text('One line'));
    await tester.pumpAndSettle();
    expect(plain(), isNot(contains('^')));
    expect(find.text('Grouped'), findsOneWidget);
  });

  testWidgets('a narrow window collapses the library to a rail that opens over the editor', (tester) async {
    await pump(tester, view: const Size(1100, 760));
    expect(find.byType(LibraryPane), findsNothing);
    await tester.tap(find.bySemanticsLabel('Show the preset library (Ctrl+F)'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryPane), findsOneWidget);
    await tester.tap(inLibrary(find.text('Small web file, AV1')));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryPane), findsNothing);
    expect(inHeader('Small web file, AV1'), findsOneWidget);
    await keys(tester, LogicalKeyboardKey.keyF, control: true);
    expect(find.byType(LibraryPane), findsOneWidget);
    expect(focusIn<LibraryPane>(), isTrue);
  });

  testWidgets('Ctrl+Shift+C copies the core\'s command line', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(copied, startsWith('ffmpeg -hide_banner'));
    expect(copied, endsWith(r'"D:\Renders\Sample project.mp4"'));
    expect(find.text('Command copied'), findsOneWidget);
  });

  testWidgets('clicking a command token opens and focuses the setting that made it', (tester) async {
    await pump(tester);
    final view = find.byType(CommandView);
    final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: view, matching: find.byType(RichText)));
    final text = paragraph.text.toPlainText();
    Offset at(String token) {
      final start = text.indexOf(token);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + token.length),
      );
      return paragraph.localToGlobal(boxes.first.toRect().center);
    }

    await tester.tapAt(at('+faststart'));
    await tester.pumpAndSettle();
    expect(find.text('Joins the streams into one file'), findsOneWidget);
    expect(focusIn<ContainerPanel>(), isTrue);
  });

  testWidgets('pointing at a control lights the tokens it produces', (tester) async {
    await pump(tester);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.text('Encoder speed')));
    await tester.pumpAndSettle();
    expect(tester.widget<CommandView>(find.byType(CommandView)).litFields, {'video.speed'});
    await gesture.moveTo(const Offset(5, 890));
    await tester.pumpAndSettle();
    expect(tester.widget<CommandView>(find.byType(CommandView)).litFields, isEmpty);
  });

  testWidgets('the size card keeps the length as typed, for next time', (tester) async {
    await pump(
      tester,
      settings: MachineSettings(uiState: AppUiState(lastSizeLengthText: '1:30')),
    );
    await tester.tap(find.text('Sample project.mp4'));
    await tester.pumpAndSettle();
    expect(fieldWith('1:30'), findsOneWidget, reason: 'the remembered text, not 10:00');
    await tester.enterText(fieldWith('1:30'), '20:');
    await tester.pump(const Duration(milliseconds: 700));
    expect((await machine.read()).uiState?.lastSizeLengthText, '20:', reason: 'kept exactly, even unfinished');
    await tester.pumpAndSettle();
  });

  testWidgets('closing remembers where the window was', (tester) async {
    await pump(tester, restored: (bounds: (x: -1500, y: 80, width: 1500, height: 950), maximized: true));
    expect(await tester.binding.handleRequestAppExit(), AppExitResponse.exit);
    final ui = (await machine.read()).uiState!;
    expect(ui.desktopWindowBounds!.x, -1500, reason: 'another monitor to the left');
    expect(ui.desktopWindowBounds!.width, 1500);
    expect(ui.desktopMaximized, isTrue);
  });
}
