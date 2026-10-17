import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/design/components/command_editor.dart';
import 'package:vegas_encoder/design/components/signal_path/signal_path.dart' show SignalPath;
import 'package:vegas_encoder/design/components/signal_path/signal_path_model.dart';
import 'package:vegas_encoder/features/advanced/display.dart';
import 'package:vegas_encoder/features/advanced/macros.dart';
import 'package:vegas_encoder/features/presets/library_pane.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/editor.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/services.dart';

import '../golden/advanced_golden_test.dart' show lintCommand;
import '../helpers.dart';

/// Advanced mode (F4, UI_SPEC §3) on the native core (B2): the command
/// editor's highlighting, locked chips, lint, macros and resolved command, the
/// switch between modes, and Advanced mode elsewhere on the screen. Fake
/// services, no FFmpeg, no VEGAS. The core's option data is B1's Windows data;
/// these tests check where its results show, not its wording.
void main() {
  late NativeVeCore core;

  setUpAll(() => core = NativeVeCore());

  Future<void> pump(WidgetTester tester) async {
    await pumpApp(
      tester,
      core: core,
      view: const Size(1440, 1000),
      overrides: [
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        presetLibraryProvider.overrideWithValue(FakePresetLibrary(now: () => '2026-10-14T02:00:00Z')),
      ],
    );
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SignalPath)));
  EditorData editor(WidgetTester tester) => container(tester).read(editorProvider)!;
  String template(WidgetTester tester) => editor(tester).recipe.command.template;
  CommandEditor commandEditor(WidgetTester tester) => tester.widget<CommandEditor>(find.byType(CommandEditor));
  CommandEditingController text(WidgetTester tester) => commandEditor(tester).controller;
  SignalPathModel diagram(WidgetTester tester) => tester.widget<SignalPath>(find.byType(SignalPath)).model;
  final editable = find.descendant(of: find.byType(CommandEditor), matching: find.byType(EditableText));

  Future<void> ctrlM(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Future<void> setCommand(WidgetTester tester, String command) async {
    container(tester).read(presetsControllerProvider.notifier).setTemplate(command);
    await tester.pumpAndSettle();
  }

  /// What typing does: the platform sends the new value; formatters run.
  Future<void> userEdit(WidgetTester tester, TextEditingValue value) async {
    await tester.showKeyboard(editable);
    tester.testTextInput.updateEditingValue(value);
    await tester.pumpAndSettle();
  }

  group('switching (SETTINGS_AND_COMMANDS §5)', () {
    testWidgets('Ctrl+M starts the command from the Basic settings and keeps both', (tester) async {
      await pump(tester);
      final basic = editor(tester).recipe;
      final seed = editor(tester).compiled.value!.advancedTemplate;
      expect(find.byType(CommandEditor), findsNothing);

      await ctrlM(tester);
      expect(editor(tester).advanced, isTrue);
      expect(template(tester), seed, reason: 'the core\'s seed from the Basic settings');
      expect(text(tester).text, seed);
      expect(commandEditor(tester).focusNode.hasFocus, isTrue, reason: 'the caret goes to the editor');
      expect(editor(tester).recipe.video.toJson(), basic.video.toJson(), reason: 'Basic settings kept');

      await ctrlM(tester);
      expect(editor(tester).advanced, isFalse);
      expect(template(tester), seed, reason: 'the command is kept, inactive');
      expect(find.text('Your command is saved. Renders use these settings until you switch back.'), findsOneWidget);
      expect(find.byType(CommandEditor), findsNothing);
    });

    testWidgets('the header switch does the same, with no "arrives in F4" notice', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Advanced').first);
      await tester.pumpAndSettle();
      expect(editor(tester).advanced, isTrue);
      expect(find.textContaining('F4'), findsNothing);
      await tester.tap(find.text('Basic').first);
      await tester.pumpAndSettle();
      expect(editor(tester).advanced, isFalse);
    });

    testWidgets('with a command saved, the seed question offers it first', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      final seed = template(tester);
      await setCommand(tester, '$seed -an');
      await ctrlM(tester);

      // From the banner: the question, defaulting to the saved command.
      await tester.tap(find.text('Switch to Advanced'));
      await tester.pumpAndSettle();
      expect(find.text('Switch to Advanced'), findsWidgets);
      expect(find.text('Use your saved command'), findsOneWidget);
      expect(find.text('Replace it with the current settings'), findsOneWidget);
      await tester.tap(find.text('Use your saved command'));
      await tester.pumpAndSettle();
      expect(editor(tester).advanced, isTrue);
      expect(template(tester), '$seed -an');

      // Esc cancels: still Basic, command untouched.
      await ctrlM(tester);
      await ctrlM(tester);
      expect(find.text('Use your saved command'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(editor(tester).advanced, isFalse);
      expect(template(tester), '$seed -an');

      // Replace: back to the current Basic settings.
      await ctrlM(tester);
      await tester.tap(find.text('Replace it with the current settings'));
      await tester.pumpAndSettle();
      expect(editor(tester).advanced, isTrue);
      expect(template(tester), seed);
    });

    testWidgets('Replace with Basic settings, with Undo', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      final seed = template(tester);
      await setCommand(tester, lintCommand);
      expect(find.textContaining('x264 slow, CRF 18, 8-bit. AAC 320 kb/s. MP4.'), findsOneWidget);

      await tester.tap(find.text('Replace with Basic settings'));
      await tester.pumpAndSettle();
      expect(template(tester), seed);
      expect(text(tester).text, seed, reason: 'the editor shows the replaced command');
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(template(tester), lintCommand);
    });
  });

  group('locked chips', () {
    testWidgets('part of a chip can\'t be deleted; the first Backspace selects it, the next deletes it', (
      tester,
    ) async {
      await pump(tester);
      await ctrlM(tester);
      final command = template(tester);
      final o = command.indexOf('{output}');
      final chip = text(tester).model.chips.singleWhere((c) => c.start == o);
      expect(chip.end, o + '{output}'.length);

      await userEdit(
        tester,
        TextEditingValue(
          text: command,
          selection: TextSelection.collapsed(offset: chip.end),
        ),
      );
      await userEdit(
        tester,
        TextEditingValue(
          text: command.replaceRange(chip.end - 1, chip.end, ''),
          selection: TextSelection.collapsed(offset: chip.end - 1),
        ),
      );
      expect(template(tester), command, reason: 'refused');
      expect(text(tester).selection, TextSelection(baseOffset: chip.start, extentOffset: chip.end));
      expect(find.text(outputLockedMessage), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(outputLockedMessage), findsNothing, reason: 'the message goes away');

      // The whole chip goes; the lint says what's missing.
      await userEdit(
        tester,
        TextEditingValue(
          text: command.replaceRange(chip.start, chip.end, ''),
          selection: TextSelection.collapsed(offset: o),
        ),
      );
      expect(template(tester), isNot(contains('{output}')));
      final missing = core.lint(template(tester)).singleWhere((d) => d.id == 'L-OUTPUT');
      expect(find.text(missing.message), findsWidgets);
    });

    testWidgets('typing over part of a chip is refused; a caret never rests inside one', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      final command = template(tester);
      final chip = text(tester).model.chips.firstWhere((c) => c.role.name == 'inputs');

      await userEdit(
        tester,
        TextEditingValue(
          text: command,
          selection: TextSelection(baseOffset: chip.start + 2, extentOffset: chip.end + 4),
        ),
      );
      await userEdit(
        tester,
        TextEditingValue(
          text: command.replaceRange(chip.start + 2, chip.end + 4, 'x'),
          selection: TextSelection.collapsed(offset: chip.start + 3),
        ),
      );
      expect(template(tester), command);
      expect(find.text(inputsLockedMessage), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      // A click inside goes to the nearer edge; an arrow step carries on.
      text(tester).selection = const TextSelection.collapsed(offset: 40);
      text(tester).selection = TextSelection.collapsed(offset: chip.start + 2);
      expect(text(tester).selection.baseOffset, chip.start);
      text(tester).selection = TextSelection.collapsed(offset: chip.start + 1);
      expect(text(tester).selection.baseOffset, chip.end);
    });

    testWidgets('cut and paste moves a chip', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      final command = template(tester);
      final chip = text(tester).model.chips.firstWhere((c) => c.role.name == 'output');
      final without = command.replaceRange(chip.start, chip.end, '');
      final moved = '{output} $without';
      await userEdit(
        tester,
        TextEditingValue(
          text: without,
          selection: TextSelection.collapsed(offset: chip.start),
        ),
      );
      await userEdit(tester, TextEditingValue(text: moved, selection: const TextSelection.collapsed(offset: 9)));
      expect(template(tester), moved);
      expect(text(tester).model.chips.where((c) => c.role.name == 'output').single.start, 0);
    });
  });

  group('lint and diagnostics', () {
    testWidgets('the core\'s findings are underlined, listed with their lines, and Go to selects them', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      await setCommand(tester, lintCommand);
      final lint = core.lint(lintCommand);
      final model = text(tester).model;
      for (final d in lint) {
        expect(model.marks.where((m) => m.start == d.start && m.end == d.end && m.message == d.message), hasLength(1));
      }
      expect(find.textContaining('1 error, 1 warning, 1 hint, 1 note'), findsOneWidget);

      final value = lint.singleWhere((d) => d.id == 'L-VALUE');
      expect(find.text('Line 4'), findsOneWidget);
      await tester.tap(find.text(value.message));
      await tester.pumpAndSettle();
      expect(text(tester).selection, TextSelection(baseOffset: value.start, extentOffset: value.end));
      expect(commandEditor(tester).focusNode.hasFocus, isTrue);
      expect(find.text(value.message), findsNWidgets(2), reason: 'the list and the message at the caret');
      expect(caretPosition(lintCommand, value.end), startsWith('Line 4, column '));
      expect(find.text(caretPosition(lintCommand, value.end)), findsOneWidget);
    });

    testWidgets('pointing at an underline shows its message', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      await setCommand(tester, lintCommand);
      final option = core.lint(lintCommand).singleWhere((d) => d.id == 'L-OPTION');
      final state = tester.state<CommandEditorState>(find.byType(CommandEditor));
      final r = state.renderEditable!;
      final box = glyphRects(r, option.start, option.end).single;
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(r.localToGlobal(box.center));
      await tester.pumpAndSettle();
      expect(find.text(option.message), findsNWidgets(2), reason: 'the bubble and the list');
      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(find.text(option.message), findsOneWidget);
    });

    testWidgets('an unterminated quote is underlined from the quote to the end', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      const command = '{inputs} -c:v libx264 "x {output}';
      await setCommand(tester, command);
      final mark = text(tester).model.marks.single;
      expect(mark.wholeCommand, isFalse);
      expect(mark.underlined, isTrue);
      expect((mark.start, mark.end), (command.indexOf('"'), command.length));
    });

    testWidgets('errors are allowed in a draft; the library marks it', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      await setCommand(tester, lintCommand);
      expect(editor(tester).hasErrors, isTrue);
      expect(find.text('Save as new preset'), findsOneWidget);
      final row = tester.widget<Semantics>(
        find.descendant(of: find.byType(LibraryPane), matching: find.bySemanticsLabel(RegExp('an error'))).first,
      );
      expect(row, isNotNull);
    });
  });

  group('macros and the resolved command', () {
    testWidgets('a macro goes in at the caret, with the core\'s value for the sample', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      final command = template(tester);
      final values = {for (final m in container(tester).read(macroEntriesProvider)!.value!) m.name: m.value};
      final data = editor(tester);
      final catalogue = core.macros(media: data.media, paths: data.paths, recipe: data.recipe);
      expect(values, {for (final macro in catalogue) macro.name: macro.value});
      expect(values['{inputs}'], contains(data.paths.videoPipe));
      expect(values['{output}'], data.paths.output);
      values.remove('{inputs}');
      values.remove('{output}');
      expect(values, {
        '{v}': '0:v:0',
        '{a}': '1:a:0',
        '{width}': '1920',
        '{height}': '1080',
        '{fps}': '30000/1001',
        '{sample_rate}': '48000',
        '{project}': 'Sample project',
        '{gop:2s}': '60',
      }, reason: 'the core\'s macro list, each expanded by the core for the sample');
      expect(find.text('1920'), findsOneWidget, reason: 'shown beside its macro');
      final at = command.indexOf('320k') + 4;
      text(tester).selection = TextSelection.collapsed(offset: at);
      await tester.tap(find.text('{width}'));
      await tester.pumpAndSettle();
      expect(template(tester), command.replaceRange(at, at, ' {width}'));
      expect(text(tester).selection.baseOffset, at + ' {width}'.length);
    });

    testWidgets('a lost {output} can be put back from the panel', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      expect(find.text('Required, locked'), findsNWidgets(2));
      await setCommand(tester, template(tester).replaceFirst('{output}', ''));
      expect(find.text('Required, missing: insert'), findsOneWidget);
      text(tester).selection = TextSelection.collapsed(offset: template(tester).length);
      await tester.tap(find.text('{output}'));
      await tester.pumpAndSettle();
      expect(template(tester), contains('{output}'));
      expect(find.text('Required, locked'), findsNWidgets(2));
    });

    testWidgets('the resolved command has the pipes, the output and expanded macros; Copy copies it', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pump(tester);
      await ctrlM(tester);
      await setCommand(tester, '{inputs}\n-c:v libx264 -g {gop:2s}\n{output}');
      final resolved = find.textContaining(r'\\.\pipe\vegas-encoder-0000-video', findRichText: true);
      expect(resolved, findsOneWidget);
      expect(find.textContaining('-g 60', findRichText: true), findsOneWidget);
      expect(find.textContaining(r'"D:\Renders\Sample project.mp4"', findRichText: true), findsOneWidget);

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(copied, editor(tester).compiled.value!.commandLine);

      await tester.tap(find.text('Resolved command'));
      await tester.pumpAndSettle();
      expect(resolved, findsNothing, reason: 'the toggle hides it');
    });
  });

  group('Advanced mode elsewhere', () {
    testWidgets('the diagram reads the command back and leaves unknown facts unknown', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      await setCommand(tester, '{inputs} -c:v libx265 -pix_fmt yuv420p10le -c:a aac -f matroska {output}');
      var d = diagram(tester);
      expect(d.fromCommand, isTrue);
      expect(d.video!.encoder, 'x265');
      expect(d.video!.outputBits, 10);
      expect(d.video!.availability, isNotNull, reason: 'the core establishes the scoped command encoder ID');
      expect(d.container.label, 'MKV');
      expect(tester.widget<SignalPath>(find.byType(SignalPath)).selected, isNull);

      await setCommand(tester, '{inputs} -c:v libx264 {output}');
      d = diagram(tester);
      expect(d.video!.conversionKnown, isFalse, reason: 'no -pix_fmt: the core doesn\'t say');
      expect(d.video!.conversion, isNull);
      expect(d.video!.formatLabel, isNull);
      expect(d.container.label, 'From file name');

      await setCommand(tester, '{inputs} -c:v copy {output}');
      expect(diagram(tester).video!.availability, isNull, reason: 'stream copy has no encoder ID');
      await setCommand(tester, '{inputs} -c:v libx264 {output}');

      // Nodes open no settings; selecting one puts the caret in the editor.
      commandEditor(tester).focusNode.unfocus();
      await tester.pump();
      await tester.tap(find.text('x264'));
      await tester.pumpAndSettle();
      expect(commandEditor(tester).focusNode.hasFocus, isTrue);
      expect(find.byType(CommandEditor), findsOneWidget);
    });

    testWidgets('no size estimate, and the library tags the draft Advanced', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      expect(find.textContaining('per minute'), findsNothing);
      final library = find.byType(LibraryPane);
      expect(find.descendant(of: library, matching: find.text('Advanced')), findsOneWidget);
      expect(find.descendant(of: library, matching: find.text('x264, your command')), findsOneWidget);
    });

    testWidgets('Copy command (Ctrl+Shift+C) copies the core\'s command line', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pump(tester);
      await ctrlM(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(copied, editor(tester).compiled.value!.commandLine);
    });
  });

  group('autocomplete (VeCore.complete)', () {
    CommandEditorState state(WidgetTester tester) => tester.state<CommandEditorState>(find.byType(CommandEditor));
    List<String> offered(WidgetTester tester) => [...?state(tester).completion?.items.map((s) => s.value)];
    const start = '{inputs}\n-c:v libx264 ';

    /// Types [typed] at the end of [before], as the platform would.
    Future<void> type(WidgetTester tester, String before, String typed, {String after = '\n{output}'}) async {
      await setCommand(tester, '$before$after');
      await userEdit(
        tester,
        TextEditingValue(
          text: '$before$after',
          selection: TextSelection.collapsed(offset: before.length),
        ),
      );
      await userEdit(
        tester,
        TextEditingValue(
          text: '$before$typed$after',
          selection: TextSelection.collapsed(offset: before.length + typed.length),
        ),
      );
    }

    Future<void> key(WidgetTester tester, LogicalKeyboardKey k, {bool control = false}) async {
      if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(k);
      if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    testWidgets('"-" opens the options; arrows move; Enter inserts and opens its values', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      await type(tester, start, '-');
      final core = NativeVeCore();
      final expected = core.complete('$start-\n{output}', start.length + 1, capabilities: editor(tester).capabilities);
      expect(offered(tester), expected.items.map((s) => s.value).toList(), reason: 'the core\'s list, in its order');
      expect(find.text('Options'), findsOneWidget);
      expect(find.text('Tab or Enter inserts'), findsOneWidget);

      final second = offered(tester)[1];
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(state(tester).activeSuggestion, 1);
      await key(tester, LogicalKeyboardKey.enter);
      expect(template(tester), '$start$second \n{output}', reason: 'the option and a space');
      expect(text(tester).selection.baseOffset, start.length + second.length + 1);
      final values = core.complete(template(tester), start.length + second.length + 1);
      if (values.kind == 'value') {
        expect(find.text('Values for $second'), findsOneWidget, reason: 'an option with values opens them next');
      } else {
        expect(state(tester).completion, isNull);
      }
    });

    testWidgets('after an option that takes values, its values; Tab inserts, Esc closes', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      await type(tester, '$start-preset', ' ');
      expect(find.text('Values for -preset'), findsOneWidget);
      final first = offered(tester).first;
      await key(tester, LogicalKeyboardKey.tab);
      expect(template(tester), '$start-preset $first \n{output}');
      expect(state(tester).completion, isNull, reason: 'a value opens nothing more');

      await type(tester, '$start-preset', ' ');
      expect(state(tester).completion, isNotNull);
      await key(tester, LogicalKeyboardKey.escape);
      expect(state(tester).completion, isNull);
      expect(editor(tester).advanced, isTrue, reason: 'Esc only closed the list');
    });

    testWidgets('typing a value filters; typing elsewhere doesn\'t open it; Ctrl+Space does', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      await type(tester, '$start-preset', ' s');
      expect(offered(tester), isNotEmpty);
      expect(offered(tester).every((v) => v.startsWith('s')), isTrue, reason: 'the core filters by what is typed');

      // A space after a value: the core offers every option, but typing
      // doesn't open them.
      await type(tester, start, ' ');
      expect(state(tester).completion, isNull, reason: 'not after "-", not a value');
      await key(tester, LogicalKeyboardKey.space, control: true);
      expect(state(tester).completion?.title, 'Options', reason: 'Ctrl+Space asks anyway');
    });

    testWidgets('a click on an entry inserts it; moving the caret closes the list', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      await type(tester, '$start-preset', ' ');
      final first = offered(tester).first;
      await tester.tap(find.text(first).last);
      await tester.pumpAndSettle();
      expect(template(tester), contains('-preset $first '));

      await type(tester, '$start-preset', ' ');
      expect(state(tester).completion, isNotNull);
      text(tester).selection = const TextSelection.collapsed(offset: 0);
      await tester.pumpAndSettle();
      expect(state(tester).completion, isNull);
    });

    testWidgets('after -c:v, encoders with their state in the chosen FFmpeg', (tester) async {
      await pump(tester);
      await ctrlM(tester);
      await type(tester, '{inputs}\n-c:v', ' ');
      final c = state(tester).completion!;
      expect(c.title, 'Values for -c:v');
      expect(offered(tester), contains('libx264'));
      final result = NativeVeCore().complete(
        '{inputs}\n-c:v \n{output}',
        '{inputs}\n-c:v '.length,
        capabilities: editor(tester).capabilities,
      );
      for (final (i, s) in result.items.indexed) {
        final shown = c.items[i].availability;
        expect(shown == null, s.availability == null || s.availability == 'unknown', reason: s.value);
      }
    });
  });
}
