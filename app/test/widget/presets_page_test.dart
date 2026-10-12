import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart' hide SizeEstimate;
import 'package:vegas_encoder/design/components/size_card.dart';
import 'package:vegas_encoder/features/presets/command_column.dart';
import 'package:vegas_encoder/features/presets/library_pane.dart';
import 'package:vegas_encoder/features/presets/preset_header.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

/// The Presets screen (S1) on the platform fakes (B0): no FFmpeg, no VEGAS.
void main() {
  late FakePresetLibrary library;
  late FakeWindowController window;

  Future<void> pump(WidgetTester tester) async {
    library = FakePresetLibrary(now: () => '2026-10-12T02:00:00Z');
    window = FakeWindowController();
    await pumpApp(
      tester,
      overrides: [windowControllerProvider.overrideWithValue(window), presetLibraryProvider.overrideWithValue(library)],
    );
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

  testWidgets('closing with unsaved changes asks first', (tester) async {
    await pump(tester);
    await setCrf(tester, '17');
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Save changes to “YouTube upload, H.264”?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(window.calls, isNot(contains('close')));

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Don’t save'));
    await tester.pumpAndSettle();
    expect(window.calls, contains('close'));
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
}
