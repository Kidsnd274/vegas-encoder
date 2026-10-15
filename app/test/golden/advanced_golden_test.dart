// Golden images of Advanced mode (F4, UI_SPEC §3) on the native core (B2),
// light and dark. Fake services, no FFmpeg, no VEGAS. The highlighting, lint,
// signal facts, macro values and resolved command are the core's; its
// profile and option data are B1's Windows data (regenerated 2026-10-14);
// regenerate these images when the core's data or wording changes, and when it
// starts giving Advanced words their stage and macro roles.
// Regenerate with: flutter test --update-goldens test/golden/advanced_golden_test.dart
// Images: test/golden/goldens/advanced_<state>_<light|dark>.png

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/design/components/command_editor.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

/// A command with one of each kind of finding: a hint (-hide_banner), an
/// unknown option (warning), an option without its value (error), a macro.
const lintCommand =
    'ffmpeg -hide_banner {inputs}\n'
    '  -map {v} -map {a}\n'
    '  -c:v libx265 -preset slow -crf 18 -pix_fmt yuv420p10le -g {gop:2s} -foo 1\n'
    '  -c:a aac -b:a 320k -tune\n'
    '  -f matroska {output}';

void main() {
  late NativeVeCore core;

  setUpAll(() => core = NativeVeCore());

  Future<void> pump(WidgetTester tester, {Size view = const Size(1440, 900)}) => pumpApp(
    tester,
    core: core,
    view: view,
    overrides: [
      windowControllerProvider.overrideWithValue(FakeWindowController()),
      presetLibraryProvider.overrideWithValue(FakePresetLibrary(now: () => '2026-10-14T02:00:00Z')),
    ],
  );

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(CommandEditor)));

  Future<void> advanced(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  final states = <String, (Size, Future<void> Function(WidgetTester))>{
    // "YouTube upload, H.264" switched to Advanced: the command starts from
    // the Basic settings; dashed nodes read back from it.
    'seeded': (const Size(1440, 900), advanced),
    // Underlines, line marks and messages for an error, a warning and a hint;
    // the diagnostics list with Go to; the caret on the error.
    'lint': (
      const Size(1440, 1000),
      (tester) async {
        await advanced(tester);
        container(tester).read(presetsControllerProvider.notifier).setTemplate(lintCommand);
        await tester.pumpAndSettle();
        final editor = tester.widget<CommandEditor>(find.byType(CommandEditor));
        editor.controller.selection = TextSelection.collapsed(offset: lintCommand.indexOf('-tune') + 2);
        await tester.pumpAndSettle();
      },
    ),
    // Back in Basic: the command is kept and the banner says so.
    'banner': (
      const Size(1440, 900),
      (tester) async {
        await advanced(tester);
        await advanced(tester);
      },
    ),
    // The narrow window: the library is a rail; the editor wraps.
    'narrow': (const Size(1100, 900), advanced),
    // Backspace into {output}: refused, the chip selected, the lock message.
    'locked': (
      const Size(1440, 900),
      (tester) async {
        await advanced(tester);
        final editable = find.descendant(of: find.byType(CommandEditor), matching: find.byType(EditableText));
        final command = tester.widget<CommandEditor>(find.byType(CommandEditor)).controller.text;
        final end = command.indexOf('{output}') + '{output}'.length;
        await tester.showKeyboard(editable);
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: command,
            selection: TextSelection.collapsed(offset: end),
          ),
        );
        await tester.pump();
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: command.replaceRange(end - 1, end, ''),
            selection: TextSelection.collapsed(offset: end - 1),
          ),
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      },
    ),
    // Autocomplete: a space after -tune opens the core's values for x265.
    'suggestions': (
      const Size(1440, 900),
      (tester) async {
        await advanced(tester);
        const before = '{inputs}\n-map {v} -map {a}\n-c:v libx265 -preset slow -crf 18 -tune';
        const after = '\n-c:a aac -b:a 320k\n{output}';
        final controller = tester.widget<CommandEditor>(find.byType(CommandEditor)).controller;
        controller.value = const TextEditingValue(
          text: '$before$after',
          selection: TextSelection.collapsed(offset: before.length),
        );
        await tester.pumpAndSettle();
        final editable = find.descendant(of: find.byType(CommandEditor), matching: find.byType(EditableText));
        await tester.showKeyboard(editable);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '$before $after',
            selection: TextSelection.collapsed(offset: before.length + 1),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Values for -tune'), findsOneWidget);
      },
    ),
    // Back to Advanced with a command saved: the question, its default last.
    'question': (
      const Size(1440, 900),
      (tester) async {
        await advanced(tester);
        await advanced(tester);
        await advanced(tester);
      },
    ),
  };

  for (final brightness in themes) {
    final theme = themeName(brightness);
    group(theme, () {
      states.forEach((name, state) {
        testWidgets('advanced_$name', (tester) async {
          EditableText.debugDeterministicCursor = true;
          addTearDown(() => EditableText.debugDeterministicCursor = false);
          addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          await pump(tester, view: state.$1);
          await state.$2(tester);
          await expectGolden('advanced_${name}_$theme');
          // Let the lock message's timer run out.
          await tester.pump(const Duration(seconds: 3));
        });
      });
    });
  }
}
