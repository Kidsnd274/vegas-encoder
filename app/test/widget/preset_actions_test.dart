import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/features/presets/display.dart' show presetFileName;
import 'package:vegas_encoder/features/presets/library_pane.dart';
import 'package:vegas_encoder/features/presets/preset_header.dart';
import 'package:vegas_encoder/features/presets/preset_test_dialog.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

/// Test this preset, Export…, Copy share string, Show in folder and Import
/// share string… / file… on the platform fakes (`FakePresetTests`, `FakePresetTransfer`,
/// `FakeFileReveal`): no FFmpeg runs and no file is written.
void main() {
  late FakePresetLibrary library;
  late FakePresetTransfer transfer;
  late FakeFileReveal reveal;
  late FakeWindowController window;
  String? clipboard;

  Future<void> pump(WidgetTester tester, {PresetTests? tests}) async {
    library = FakePresetLibrary(now: () => '2026-10-15T02:00:00Z');
    transfer = FakePresetTransfer(library);
    reveal = FakeFileReveal();
    window = FakeWindowController();
    clipboard = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String;
      if (call.method == 'Clipboard.getData') return {'text': clipboard};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpApp(
      tester,
      overrides: [
        windowControllerProvider.overrideWithValue(window),
        presetLibraryProvider.overrideWithValue(library),
        presetTransferProvider.overrideWithValue(transfer),
        fileRevealProvider.overrideWithValue(reveal),
        if (tests != null) presetTestsProvider.overrideWithValue(tests),
      ],
    );
  }

  Finder inLibrary(Finder f) => find.descendant(of: find.byType(LibraryPane), matching: f);
  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(LibraryPane)));
  Future<void> addMenu(WidgetTester tester, String action) async {
    await tester.tap(find.byWidgetPredicate((w) => w is Tooltip && w.message == 'Add a preset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String preset, String action) async {
    await tester.tap(inLibrary(find.text(preset)).last, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(action).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Test this preset runs the service, streams FFmpeg’s output and shows the result', (tester) async {
    await pump(tester);
    await tester.tap(find.descendant(of: find.byType(PresetHeader), matching: find.text('Test')));
    await tester.pumpAndSettle();
    expect(find.text('Test “YouTube upload, H.264”'), findsOneWidget);
    expect(find.text('Passed'), findsOneWidget);
    expect(find.text('Sample result from the platform’s test service: nothing ran.'), findsOneWidget);
    expect(find.text('Synthetic fixture log.'), findsOneWidget);
    expect(find.text('1 line from FFmpeg.'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(PresetTestPanel), findsNothing);
  });

  testWidgets('Stop test stops a run that is still going; a failure says why', (tester) async {
    final tests = _StalledTests();
    await pump(tester, tests: tests);
    await tester.tap(find.descendant(of: find.byType(PresetHeader), matching: find.text('Test')));
    await tester.pumpAndSettle();
    expect(find.text('Encoding: frame 30 of 60'), findsOneWidget);
    await tester.tap(find.text('Stop test'));
    await tester.pumpAndSettle();
    expect(find.text('Stopped'), findsOneWidget);
    expect(tests.cancelled, isTrue);

    tests.fail = true;
    await tester.tap(find.text('Test again'));
    await tester.pumpAndSettle();
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Probe this installation before testing a preset.'), findsOneWidget);
  });

  testWidgets('Export…, Copy share string, Show in folder, then Import share string… adds a copy', (tester) async {
    await pump(tester);
    // Built-ins have no file of their own.
    await tester.tap(inLibrary(find.text('Small web file, AV1')), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Built-in presets are part of the app.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    window.savedFile = r'D:\Shared\AV1.vepreset';
    await menu(tester, 'Small web file, AV1', 'Export…');
    expect(window.calls, contains('saveFile(Small web file, AV1.vepreset, *.vepreset)'));
    expect(transfer.exported.keys, [r'D:\Shared\AV1.vepreset']);
    expect(find.text(r'Exported “Small web file, AV1” to D:\Shared\AV1.vepreset'), findsOneWidget);

    await menu(tester, 'Small web file, AV1', 'Copy share string');
    expect(clipboard, startsWith('vepreset:1:'));

    // Import puts it in Mine and selects it; the field starts with the clipboard.
    await tester.tap(find.byWidgetPredicate((w) => w is Tooltip && w.message == 'Add a preset'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a .vepreset file to add to Mine.'), findsOneWidget);
    await tester.tap(find.text('Import share string…'));
    await tester.pumpAndSettle();
    expect(find.text(clipboard!), findsOneWidget);
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(find.text('Imported “Small web file, AV1” into Mine'), findsOneWidget);
    final imported = (await library.list()).singleWhere((p) => p.recipe.id == 'imported-preset');
    expect(imported.builtin, isFalse);
    expect(imported.origin, 'builtin/av1-small');

    // A preset in Mine has a file to show.
    await menu(tester, 'Small web file, AV1', 'Show in folder');
    expect(reveal.revealed, ['fixture-library/imported-preset.vepreset']);
  });

  testWidgets('Import file creates and selects a new preset, clears filters and never replaces the source', (
    tester,
  ) async {
    await pump(tester);
    const path = r'D:\Shared\AV1.vepreset';
    transfer.files[path] = await library.exportPreset('av1-small');
    final source = transfer.files[path];
    window.pickedFile = path;
    final c = container(tester);
    final controller = c.read(presetsControllerProvider.notifier);
    controller.setQuery('does not match');
    controller.setFilter(LibraryFilter.builtin);
    controller.toggleFavoritesOnly();
    await tester.pumpAndSettle();

    await addMenu(tester, 'Import file…');
    expect(window.calls, contains('pickFile(*.vepreset)'));
    expect(find.text('Imported “Small web file, AV1” into Mine'), findsOneWidget);
    final first = (await library.get('imported-preset'))!;
    expect(first.builtin, isFalse);
    expect(first.recipe.name, 'Small web file, AV1');
    expect(first.origin, 'builtin/av1-small');
    expect(first.revision, 1);
    final state = c.read(presetsControllerProvider);
    expect(state.selectedId, 'imported-preset');
    expect(state.query, isEmpty);
    expect(state.filter, LibraryFilter.all);
    expect(state.favoritesOnly, isFalse);

    await addMenu(tester, 'Import file…');
    expect(c.read(presetsControllerProvider).selectedId, 'imported-preset-2');
    expect((await library.get('imported-preset'))!.recipe.toJson(), first.recipe.toJson());
    expect(transfer.files[path], source, reason: 'the selected source is never changed');
  });

  testWidgets('Import file cancellation and rejected files keep the current selection and library', (tester) async {
    await pump(tester);
    final c = container(tester);
    final selected = c.read(presetsControllerProvider).selectedId;
    final before = (await library.list()).length;

    await addMenu(tester, 'Import file…');
    expect(c.read(presetsControllerProvider).selectedId, selected);
    expect(find.textContaining('Couldn’t import'), findsNothing);

    window.pickedFile = r'D:\Shared\missing.vepreset';
    await addMenu(tester, 'Import file…');
    expect(find.text('Couldn’t import the preset: Preset file is missing.'), findsOneWidget);
    window.pickedFile = r'D:\Shared\broken.vepreset';
    transfer.files[window.pickedFile!] = '{invalid JSON';
    await addMenu(tester, 'Import file…');
    expect(find.textContaining('Couldn’t import the preset:'), findsOneWidget);
    expect(c.read(presetsControllerProvider).selectedId, selected);
    expect((await library.list()).length, before);
  });

  test('the Save dialog suggests the preset’s name without characters Windows refuses', () {
    expect(presetFileName('YouTube upload, H.264'), 'YouTube upload, H.264.vepreset');
    expect(presetFileName('A/B: C?.'), 'A-B- C-.vepreset');
    expect(presetFileName(' ... '), 'Preset.vepreset');
  });
}

/// Reports encoding, then waits until cancelled; or fails at once.
class _StalledTests implements PresetTests {
  bool fail = false;
  bool cancelled = false;

  @override
  Stream<PresetTestProgress> test(Recipe recipe, FFmpegInstallation installation) {
    late StreamController<PresetTestProgress> c;
    c = StreamController<PresetTestProgress>(onCancel: () => cancelled = true);
    if (fail) {
      c.add(
        PresetTestProgress(
          testId: 't',
          phase: 'failed',
          message: 'Probe this installation before testing a preset.',
          code: 'PROBE-REQUIRED',
        ),
      );
      c.close();
    } else {
      c.add(PresetTestProgress(testId: 't', phase: 'encoding', framesDone: 30, log: 'frame=30\n'));
    }
    return c.stream;
  }

  @override
  Future<void> cancel(String testId) async => cancelled = true;
}
