import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart' as core;
import 'package:vegas_encoder/design/components/command_editor.dart';
import 'package:vegas_encoder/design/components/command_view.dart' show CommandRole;
import 'package:vegas_encoder/design/components/message.dart' show VeLevel;
import 'package:vegas_encoder/design/components/status.dart' show VeAvailability;
import 'package:vegas_encoder/features/advanced/display.dart';
import 'package:vegas_encoder/features/presets/display.dart' show signalPathModel;
import 'package:vegas_encoder/state/preview.dart';

/// Advanced mode's display mapping (F4): every range, role and value comes
/// from the core's results, built here by hand in the contract's shapes
/// (CONTRACTS C2), so the mapping is checked without the core.
void main() {
  Map<String, Object?> token(String text, String role, [int? start, int? end]) => {
    'text': text,
    'role': role,
    'field': role == 'exe' || role == 'global' || role == 'input' ? null : 'command.template',
    'sourceStart': ?start,
    'sourceEnd': ?end,
  };

  core.CompileResult compiled({
    List<Map<String, Object?>> display = const [],
    List<Map<String, Object?>> issues = const [],
    Map<String, Object?> summary = const {},
    Map<String, Object?>? signalPath,
  }) => core.CompileResult.fromJson({
    'executable': 'ffmpeg',
    'argv': <String>[],
    'display': display,
    'commandLine': 'ffmpeg …',
    'advancedTemplate': '',
    'resolved': null,
    'signalPath': signalPath,
    'issues': issues,
    'summary': summary,
    'overriddenFields': <String>[],
  });

  Map<String, Object?> issue(String id, String level, String message, {Map<String, Object?> params = const {}}) => {
    'id': id,
    'level': level,
    'field': params.isEmpty ? '' : 'command.template',
    'message': message,
    'params': params,
    'fix': null,
    'tokenIndices': <int>[],
  };

  core.Diagnostic diagnostic(String id, String level, int start, int end, String message) =>
      core.Diagnostic.fromJson({'id': id, 'level': level, 'start': start, 'end': end, 'message': message});

  //                0         1         2         3
  //                0123456789012345678901234567890123456
  const command = '{inputs}\n-c:v libx264 -g {gop:2s}\n{output}';

  group('templateEditorModel', () {
    test('chips and option markers come from the core; missing markers stay unknown', () {
      final result = compiled(
        display: [
          token('ffmpeg', 'exe'),
          token('-hide_banner', 'global'),
          token('-f', 'input', 0, 8),
          token('rawvideo', 'input', 0, 8),
          {...token('-c:v', 'extra', 9, 13), 'isOption': true},
          token('libx264', 'extra', 14, 21),
          {...token('-g', 'extra', 22, 24), 'isOption': true},
          token('60', 'extra', 25, 33),
          token(r'D:\out.mp4', 'output', 34, 42),
        ],
      );
      final m = templateEditorModel(command, compiled: result);
      expect(m.chips.map((c) => (c.start, c.end, c.role)), [(0, 8, CommandRole.inputs), (34, 42, CommandRole.output)]);
      expect(m.chips.first.message, inputsLockedMessage);
      expect(m.words.map((w) => (w.start, w.end, w.flag, w.role)), [
        (9, 13, true, null),
        (14, 21, false, null),
        (22, 24, true, null),
        (25, 33, false, null),
      ]);
    });

    test('stage and macro metadata show when the core gives them', () {
      final result = compiled(
        display: [
          {...token('-c:v', 'video', 9, 13), 'stage': 'video', 'isOption': true},
          {...token('-c:a', 'extra', 14, 18), 'stage': 'audio', 'isOption': true},
          {
            ...token('60', 'macro', 25, 33),
            'stage': 'video',
            'macros': ['{gop:2s}'],
          },
        ],
      );
      final m = templateEditorModel(command, compiled: result);
      expect(m.words.map((w) => (w.role, w.macro)), [
        (CommandRole.video, false),
        (CommandRole.audio, false),
        (CommandRole.video, true),
      ]);
    });

    test('negative and quoted values are not options; embedded macros keep their stage', () {
      const text = '-crf -1 -metadata "-x{project}" -unknown';
      final result = compiled(
        display: [
          {...token('-crf', 'video', 0, 4), 'stage': 'video', 'isOption': true},
          {...token('-1', 'video', 5, 7), 'stage': 'video', 'isOption': false},
          {...token('-metadata', 'extra', 8, 17), 'isOption': true},
          {
            ...token('-xSample project', 'macro', 18, 31),
            'stage': 'mux',
            'isOption': false,
            'macros': ['{project}'],
          },
          token('-unknown', 'extra', 32, 40),
        ],
      );
      final m = templateEditorModel(text, compiled: result);
      expect(m.words.map((w) => (w.flag, w.macro, w.role)), [
        (true, false, CommandRole.video),
        (false, false, CommandRole.video),
        (true, false, null),
        (false, true, CommandRole.mux),
        (false, false, null),
      ]);
    });

    test('spans outside the text are ignored', () {
      final result = compiled(display: [token('-x', 'extra', 40, 99), token('-y', 'extra', 5, 5)]);
      expect(templateEditorModel(command, compiled: result).words, isEmpty);
    });
  });

  group('marks and checks', () {
    final lint = [
      diagnostic('L-OPTION', 'warn', 22, 24, 'Unknown option.'),
      diagnostic('L-OUTPUTS', 'warn', 0, command.length, 'Only {output} is published.'),
      diagnostic('L-INPUTS', 'error', 0, 0, 'Add {inputs}.'),
    ];
    final result = compiled(
      issues: [
        issue('L-OPTION', 'warn', 'Unknown option.', params: {'start': 22, 'end': 24}),
        issue('L-GOP', 'error', 'Keyframe macro is out of range.', params: {'start': 25, 'end': 33}),
        issue('V-UNTESTED', 'info', 'Not tested with VEGAS yet.'),
      ],
    );

    test('lint first, then compile issues lint didn\'t repeat; the whole command is not underlined', () {
      final marks = advancedMarks(command, lint, result);
      expect(marks.map((m) => (m.message, m.level, m.underlined, m.wholeCommand)), [
        ('Unknown option.', VeLevel.warning, true, false),
        ('Only {output} is published.', VeLevel.warning, false, true),
        ('Add {inputs}.', VeLevel.error, false, false),
        ('Keyframe macro is out of range.', VeLevel.error, true, false),
      ]);
    });

    test('checks in text order with lines, then the whole command, then the recipe', () {
      final checks = advancedChecks(command, advancedMarks(command, lint, result), result);
      expect(checks.map((c) => (c.message, c.line, c.start)), [
        ('Add {inputs}.', 1, 0),
        ('Unknown option.', 2, 22),
        ('Keyframe macro is out of range.', 2, 25),
        ('Only {output} is published.', null, null),
        ('Not tested with VEGAS yet.', null, null),
      ]);
      expect(checkCounts(checks), '2 errors, 2 warnings, 1 note');
      expect(checkCounts(const []), '');
    });

    test('lines and columns', () {
      expect(lineAt(command, 0), 1);
      expect(lineAt(command, 9), 2);
      expect(lineAt(command, command.length), 3);
      expect(caretPosition(command, 0), 'Line 1, column 1');
      expect(caretPosition(command, 14), 'Line 2, column 6');
      expect(caretPosition(command, command.length), 'Line 3, column 9');
    });

    test('the most severe mark at a caret, touching either end', () {
      final m = CommandEditorModel(text: command, marks: advancedMarks(command, lint, result));
      expect(m.markAt(22)?.message, 'Unknown option.');
      expect(m.markAt(24)?.message, 'Unknown option.');
      expect(m.markAt(28)?.message, 'Keyframe macro is out of range.');
      expect(m.markAt(5), isNull, reason: 'whole-command marks are listed, not at a caret');
    });
  });

  test('the resolved command follows the user\'s lines, quoted, with errors marked', () {
    final result = core.CompileResult.fromJson({
      ...compiled().toJson(),
      'display': [
        token('ffmpeg', 'exe'),
        token('-nostdin', 'global'),
        token('-i', 'input', 0, 8),
        token(r'\\.\pipe\v', 'input', 0, 8),
        token('-c:v', 'extra', 9, 13),
        token('libx264', 'extra', 14, 21),
        token('-g', 'extra', 22, 24),
        token('60', 'extra', 25, 33),
        token(r'D:\Renders\Sample project.mp4', 'output', 34, 42),
      ],
      'issues': [
        {
          ...issue('L-GOP', 'error', 'x'),
          'tokenIndices': <int>[7],
        },
      ],
    });
    final lines = resolvedLines(result, command);
    expect(lines.map((l) => l.map((t) => t.text).join(' ')), [
      'ffmpeg -nostdin',
      r'-i \\.\pipe\v',
      '-c:v libx264 -g 60',
      r'"D:\Renders\Sample project.mp4"',
    ]);
    expect(lines[0].first.part, ResolvedPart.generated);
    expect(lines[1].first.part, ResolvedPart.input);
    expect(lines[3].single.part, ResolvedPart.output);
    expect(lines[2].map((t) => t.error), [false, false, false, true]);
  });

  test('macros retain catalogue values and required markers, including unknown names', () {
    final entries = macroEntries([
      core.MacroDefinition(name: '{inputs}', description: 'Inputs', value: '-i video', required: true),
      core.MacroDefinition(name: '{v}', description: 'Video', value: '0:v:0'),
      core.MacroDefinition(name: '{gop:2s}', description: 'GOP', value: '60'),
      core.MacroDefinition(name: '{output}', description: 'Output', value: r'D:\x.mp4', required: true),
      core.MacroDefinition(name: '{new}', description: 'A future macro', required: true),
    ]);
    expect(entries.map((e) => (e.name, e.value, e.required)), [
      ('{inputs}', '-i video', true),
      ('{v}', '0:v:0', false),
      ('{gop:2s}', '60', false),
      ('{output}', r'D:\x.mp4', true),
      ('{new}', null, true),
    ]);
    expect(entries[1].description, macroDescriptions['{v}']);
    expect(entries.last.description, 'A future macro', reason: 'the core\'s text for a macro the app has no copy for');
  });

  group('autocomplete', () {
    core.CompletionResult result(
      String kind, {
      String? of,
      int start = 0,
      int end = 0,
      List<Map<String, Object?>>? items,
    }) => core.CompletionResult.fromJson({
      'kind': kind,
      'of': of,
      'start': start,
      'end': end,
      'items':
          items ??
          [
            {
              'value': '-preset',
              'description': 'Set the encoding preset',
              'type': 'string',
              'defaultValue': 'medium',
              'source': 'libx264',
            },
            {'value': '-b', 'description': 'Bitrate', 'source': 'FFmpeg'},
          ],
    });

    test('typing opens options only after "-"; Ctrl+Space opens them anyway', () {
      const text = '-c:v libx264 -';
      expect(editorCompletion(result('option', start: 13, end: 14), text, 14, manual: false), isNotNull);
      const plain = '-c:v libx264 x';
      expect(editorCompletion(result('option', start: 13, end: 14), plain, 14, manual: false), isNull);
      expect(editorCompletion(result('option', start: 13, end: 14), plain, 14, manual: true), isNotNull);
      expect(editorCompletion(result('none', items: const []), text, 14, manual: true), isNull);
    });

    test('options: the core\'s entries with type, default and where they come from', () {
      final c = editorCompletion(result('option', start: 13, end: 14), '-c:v libx264 -', 14, manual: false)!;
      expect(c.title, 'Options');
      expect(c.source, 'libx264 and FFmpeg');
      expect((c.start, c.end), (13, 14));
      expect(c.items.map((s) => (s.value, s.description, s.detail)), [
        ('-preset', 'Set the encoding preset', 'string, default medium'),
        ('-b', 'Bitrate', ''),
      ]);
    });

    test('values open after their option; encoders carry their state', () {
      final values = editorCompletion(
        result(
          'value',
          of: '-tune',
          start: 19,
          end: 19,
          items: [
            {'value': 'film', 'description': 'film', 'source': 'libx264'},
          ],
        ),
        '-c:v libx264 -tune ',
        19,
        manual: false,
      )!;
      expect(values.title, 'Values for -tune');
      expect(values.items.single.description, '', reason: 'a description that only repeats the value is dropped');
      expect(values.footer, 'Values this option takes.');

      final encoders = editorCompletion(
        result(
          'value',
          of: '-c:v',
          start: 5,
          end: 5,
          items: [
            {'value': 'libx264', 'description': 'x264', 'availability': 'ok'},
            {'value': 'h264_nvenc', 'description': 'NVENC', 'availability': 'failed'},
            {'value': 'libsvtav1', 'description': 'SVT-AV1', 'availability': 'missing'},
            {'value': 'libvpx-vp9', 'description': 'VP9', 'availability': 'unknown'},
          ],
        ),
        '-c:v ',
        5,
        manual: false,
      )!;
      expect(encoders.items.map((s) => s.availability), [
        VeAvailability.ready,
        VeAvailability.failed,
        VeAvailability.missing,
        null,
      ]);
      expect(encoders.footer, 'Encoders, with their state in the chosen FFmpeg.');
    });

    test('macros after "{"', () {
      final c = editorCompletion(
        result(
          'value',
          start: 0,
          end: 1,
          items: [
            {'value': '{v}', 'description': 'VEGAS media or output macro', 'source': 'Macro'},
          ],
        ),
        '{',
        1,
        manual: false,
      )!;
      expect(c.title, 'Macros');
    });
  });

  test('the Basic summary line', () {
    expect(
      basicSummaryLine({
        'videoEncoder': 'x264',
        'speed': 'slow',
        'videoQuality': 'CRF 18',
        'depth': '8-bit',
        'audio': 'AAC',
        'audioQuality': '320 kb/s',
        'container': 'MP4',
      }),
      'x264 slow, CRF 18, 8-bit. AAC 320 kb/s. MP4.',
    );
    expect(basicSummaryLine({'videoEncoder': 'FFV1', 'audio': 'No audio', 'container': 'MKV'}), 'FFV1. No audio. MKV.');
  });

  group('signal path in Advanced mode', () {
    final fake = core.FakeVeCore();
    final catalog = fake.profiles();
    final basic = fake.fixtures.first.recipe;
    final recipe = basic.copyWith(
      command: basic.command.copyWith(mode: 'template', template: command),
    );
    Map<String, Object?> stream({int? outBits, bool? conversion, String support = 'unknown'}) => {
      'inputFormat': 'p010le',
      'outputFormat': outBits == null ? null : 'yuv420p10le',
      'inputBits': 10,
      'outputBits': outBits,
      'inputChroma': '4:2:0',
      'outputChroma': outBits == null ? null : '4:2:0',
      'chromaChanged': outBits == null ? null : false,
      'conversion': conversion,
      'containerSupport': support,
    };

    test('unknown facts stay unknown, and the Basic settings never show', () {
      final m = signalPathModel(
        recipe: recipe,
        catalog: catalog,
        media: SamplePreview.media,
        compiled: compiled(
          summary: {'videoEncoder': '', 'video': 'From command', 'videoQuality': 'From command', 'container': ''},
          signalPath: {'video': stream(), 'audio': <Object?>[], 'source': null},
        ),
      );
      expect(m.fromCommand, isTrue);
      expect(m.video!.encoder, 'From command', reason: 'not ${basic.video.encoder}, the inactive Basic encoder');
      expect(m.video!.availability, isNull);
      expect(m.video!.conversionKnown, isFalse);
      expect(m.video!.formatLabel, isNull);
      expect(m.video!.outputBits, 10, reason: 'the wire keeps VEGAS\'s depth');
      expect(m.audio, isNull, reason: 'the core has no audio stream');
      expect(m.container.label, 'From file name');
    });

    test('known facts fill the nodes', () {
      final m = signalPathModel(
        recipe: recipe,
        catalog: catalog,
        media: SamplePreview.media,
        compiled: compiled(
          summary: {
            'videoEncoder': 'x265',
            'video': 'HEVC',
            'videoQuality': 'From command',
            'speed': 'slow',
            'container': catalog.containers.firstWhere((c) => c.id == 'mkv').label,
          },
          signalPath: {
            'video': stream(outBits: 10, conversion: true, support: 'ok'),
            'audio': <Object?>[],
            'source': null,
          },
        ),
      );
      expect(m.video!.encoder, 'x265');
      expect(m.video!.detail, 'From command, slow');
      expect(m.video!.conversion?.label, 'p010le to yuv420p10le');
      expect(m.video!.formatLabel, '10-bit 4:2:0');
      expect(m.container.label, 'MKV');
    });

    test('without a compile result only what VEGAS delivers is known', () {
      final m = signalPathModel(recipe: recipe, catalog: catalog, media: SamplePreview.media);
      expect(m.video!.encoder, 'From command');
      expect(m.video!.conversionKnown, isFalse);
      expect(m.audio, isNotNull);
      expect(m.audio!.formatLabel, isNull);
    });

    test('availability uses only nullable summary encoder IDs, not labels or Basic encoders', () {
      final installation = core.FFmpegInstallation.fromJson({
        'label': 'Selected FFmpeg',
        'availability': {
          basic.video.encoder: {'state': 'ok'},
          'hevc_nvenc': {'state': 'failed'},
          'libopus': {'state': 'missing'},
        },
      });
      final withIds = compiled(
        summary: {'videoEncoder': 'x264', 'videoEncoderId': 'hevc_nvenc', 'audioEncoderId': 'libopus'},
      );
      final known = signalPathModel(
        recipe: recipe,
        catalog: catalog,
        media: SamplePreview.media,
        compiled: withIds,
        installation: installation,
      );
      expect(known.video!.availability, VeAvailability.failed);
      expect(known.audio!.availability, VeAvailability.missing);

      final unknown = signalPathModel(
        recipe: recipe,
        catalog: catalog,
        media: SamplePreview.media,
        compiled: compiled(summary: {'videoEncoder': 'x264', 'videoEncoderId': null, 'audioEncoderId': null}),
        installation: installation,
      );
      expect(unknown.video!.availability, isNull);
      expect(unknown.audio!.availability, isNull);
    });
  });

  group('editing', () {
    test('the replaced range sits where the edit was', () {
      TextEditingValue v(String text, int caret) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: caret),
      );
      expect(replacedRange(v('x}}', 3), v('x}', 2)), (2, 3), reason: 'Backspace after a repeated character');
      expect(replacedRange(v('}}x', 2), v('}x', 1)), (1, 2));
      expect(replacedRange(v('a{{b', 1), v('a{b', 1)), (1, 2), reason: 'Delete before a repeated character');
      expect(replacedRange(v('ab', 1), v('axb', 2)), (1, 1), reason: 'typing inserts');
      expect(
        replacedRange(
          const TextEditingValue(text: 'abcdef', selection: TextSelection(baseOffset: 1, extentOffset: 4)),
          v('aXef', 2),
        ),
        (1, 4),
        reason: 'typing over a selection',
      );
      expect(replacedRange(v('{inputs} x', 10), v('{output} {inputs} x', 9)), (
        0,
        0,
      ), reason: 'a paste before a chip that starts with the same character');
    });

    test('a caret moved into a chip goes to its edge', () {
      final controller = CommandEditingController(
        text: command,
        describe: (t) => CommandEditorModel(
          text: t,
          chips: const [EditorChip(0, 8, role: CommandRole.inputs, message: '')],
        ),
      );
      addTearDown(controller.dispose);
      controller.selection = const TextSelection.collapsed(offset: 20);
      controller.selection = const TextSelection.collapsed(offset: 3);
      expect(controller.selection.baseOffset, 0, reason: 'a click goes to the nearer edge');
      controller.selection = const TextSelection.collapsed(offset: 1);
      expect(controller.selection.baseOffset, 8, reason: 'an arrow step carries on');
      controller.selection = const TextSelection.collapsed(offset: 7);
      expect(controller.selection.baseOffset, 0, reason: 'and back');
      controller.selection = const TextSelection(baseOffset: 2, extentOffset: 12);
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 12),
        reason: 'ranges are left alone',
      );
    });
  });
}
