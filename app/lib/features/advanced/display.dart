// Maps the core's results for an Advanced command to the editor's display
// models. Display work only: every range, role, expansion and message comes
// from the core (CONTRACTS C2: CompileResult.display with sourceStart/
// sourceEnd, Diagnostic ranges, Issue params, CompletionResult). Nothing here
// tokenizes the command, reads FFmpeg options or expands a macro.

import 'package:ve_services/ve_services.dart' as core;

import '../../design/components/command_editor.dart';
import '../../design/components/command_view.dart' show CommandRole, CommandToken;
import '../../design/components/message.dart' show VeLevel;
import '../presets/display.dart' show levelOf, quoteArgument;

/// Shown when typing inside a chip or deleting part of it.
const inputsLockedMessage =
    '{inputs} is locked. Vegas Encoder puts the VEGAS video and audio pipes here. Cut and paste moves it.';
const outputLockedMessage = '{output} is locked. Vegas Encoder writes the Render As file here. Cut and paste moves it.';

/// A token's span in the command text (CONTRACTS C2 `sourceStart`/`sourceEnd`,
/// UTF-16), when the core gives one that fits [length].
(int, int)? sourceSpan(core.CommandToken t, int length) {
  final s = t.data['sourceStart'], e = t.data['sourceEnd'];
  if (s is! int || e is! int || s < 0 || e > length || s >= e) return null;
  return (s, e);
}

CommandRole? _stage(core.TokenRole role) => switch (role) {
  core.TokenRole.global || core.TokenRole.input || core.TokenRole.map => CommandRole.inputs,
  core.TokenRole.video => CommandRole.video,
  core.TokenRole.audio => CommandRole.audio,
  core.TokenRole.mux => CommandRole.mux,
  core.TokenRole.output => CommandRole.output,
  // Advanced words come back as `extra` today: no stage is claimed.
  core.TokenRole.extra || core.TokenRole.macro || core.TokenRole.exe => null,
};

/// The editor's model for [text]: words and chips from the core's compile of
/// this text, marks from its lint plus compile issues lint doesn't repeat
/// (such as an out-of-range `{gop:Ns}`).
///
/// The core gives a word's stage and macro role only where it knows them; in
/// B2 Advanced words are all `extra`, so only option names (the command
/// view's display rule) and the locked chips stand out until it does.
CommandEditorModel templateEditorModel(
  String text, {
  core.CompileResult? compiled,
  List<core.Diagnostic> lint = const [],
}) {
  final words = <EditorWord>[];
  final chips = <EditorChip>[];
  final seen = <(int, int)>{};
  for (final t in compiled?.display ?? const <core.CommandToken>[]) {
    final span = sourceSpan(t, text.length);
    if (span == null || !seen.add(span)) continue;
    final (start, end) = span;
    switch (t.role) {
      case core.TokenRole.input:
        chips.add(EditorChip(start, end, role: CommandRole.inputs, message: inputsLockedMessage));
      case core.TokenRole.output:
        chips.add(EditorChip(start, end, role: CommandRole.output, message: outputLockedMessage));
      case core.TokenRole.macro:
        words.add(EditorWord(start, end, macro: true));
      default:
        words.add(EditorWord(start, end, flag: CommandToken(t.text).isFlag, role: _stage(t.role)));
    }
  }
  return CommandEditorModel(text: text, words: words, chips: chips, marks: advancedMarks(text, lint, compiled));
}

/// Lint diagnostics, then the compile issues with a range in the command that
/// lint didn't report (same id and range).
List<EditorMark> advancedMarks(String text, List<core.Diagnostic> lint, core.CompileResult? compiled) {
  final marks = <EditorMark>[];
  final seen = <(String, int, int)>{};
  void add(String id, core.IssueLevel level, int start, int end, String message) {
    if (start < 0 || end > text.length || start > end || !seen.add((id, start, end))) return;
    marks.add(
      EditorMark(
        start,
        end,
        level: levelOf(level),
        message: message,
        wholeCommand: text.isNotEmpty && start == 0 && end == text.length,
      ),
    );
  }

  for (final d in lint) {
    add(d.id, d.level, d.start, d.end, d.message);
  }
  for (final i in compiled?.issues ?? const <core.Issue>[]) {
    final (s, e) = (i.params['start'], i.params['end']);
    if (i.field == 'command.template' && s is int && e is int) add(i.id, i.level, s, e, i.message);
  }
  return marks;
}

// ------------------------------------------------------------ diagnostics list

/// One row of the diagnostics list under the editor.
class AdvancedCheck {
  const AdvancedCheck({required this.level, required this.message, this.fix, this.start, this.end, this.line});
  final VeLevel level;
  final String message;
  final String? fix;

  /// Where "Go to" puts the selection; null for a check about the whole
  /// command or the whole recipe.
  final int? start;
  final int? end;

  /// 1-based line of [start].
  final int? line;
}

/// The command's checks for the chosen FFmpeg: the editor's marks in text
/// order, then those about the whole command, then the compile's issues that
/// aren't about the text (such as "Not tested with VEGAS yet.").
List<AdvancedCheck> advancedChecks(String text, List<EditorMark> marks, core.CompileResult? compiled) {
  final ranged = marks.where((m) => !m.wholeCommand).toList()..sort((a, b) => a.start.compareTo(b.start));
  return [
    for (final m in ranged)
      AdvancedCheck(level: m.level, message: m.message, start: m.start, end: m.end, line: lineAt(text, m.start)),
    for (final m in marks.where((m) => m.wholeCommand)) AdvancedCheck(level: m.level, message: m.message),
    for (final i in compiled?.issues ?? const <core.Issue>[])
      if (i.params['start'] is! int) AdvancedCheck(level: levelOf(i.level), message: i.message, fix: i.fix),
  ];
}

/// "1 error, 2 warnings"; empty when there are none.
String checkCounts(List<AdvancedCheck> checks) {
  String n(int count, String one) => '$count $one${count == 1 ? '' : 's'}';
  final errors = checks.where((c) => c.level == VeLevel.error).length;
  final warnings = checks.where((c) => c.level == VeLevel.warning).length;
  final hints = checks.where((c) => c.level == VeLevel.hint).length;
  final notes = checks.where((c) => c.level == VeLevel.info).length;
  return [
    if (errors > 0) n(errors, 'error'),
    if (warnings > 0) n(warnings, 'warning'),
    if (hints > 0) n(hints, 'hint'),
    if (notes > 0) n(notes, 'note'),
  ].join(', ');
}

/// 1-based line of [offset] in [text].
int lineAt(String text, int offset) {
  var line = 1;
  for (var i = 0; i < offset && i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0A) line++;
  }
  return line;
}

/// "Line 3, column 12" for a caret at [offset].
String caretPosition(String text, int offset) {
  final o = offset.clamp(0, text.length);
  final lineStart = o == 0 ? 0 : text.lastIndexOf('\n', o - 1) + 1;
  return 'Line ${lineAt(text, o)}, column ${o - lineStart + 1}';
}

// ------------------------------------------------------------ resolved command

enum ResolvedPart { generated, input, command, output }

/// One argument of the resolved command, quoted for display.
class ResolvedToken {
  const ResolvedToken(this.text, this.part, {this.error = false});
  final String text;
  final ResolvedPart part;
  final bool error;
}

/// The command as the core resolved it for the sample context (real pipe
/// names, the output path, macros expanded), laid out like the user's text:
/// the parts Vegas Encoder adds first, then one line per line of the command.
List<List<ResolvedToken>> resolvedLines(core.CompileResult compiled, String text) {
  final errors = {
    for (final i in compiled.issues)
      if (i.level == core.IssueLevel.error) ...i.tokenIndices,
  };
  final lines = <int, List<ResolvedToken>>{};
  final display = compiled.display;
  for (var index = 0; index < display.length; index++) {
    final t = display[index];
    final span = sourceSpan(t, text.length);
    final line = span == null ? 0 : lineAt(text, span.$1);
    final part = switch (t.role) {
      core.TokenRole.exe || core.TokenRole.global => ResolvedPart.generated,
      core.TokenRole.input => ResolvedPart.input,
      core.TokenRole.output => ResolvedPart.output,
      _ => ResolvedPart.command,
    };
    (lines[line] ??= []).add(ResolvedToken(quoteArgument(t.text), part, error: errors.contains(index)));
  }
  return [for (final k in lines.keys.toList()..sort()) lines[k]!];
}

// ------------------------------------------------------------ macros

/// A macro for the macros panel.
class MacroEntry {
  const MacroEntry({required this.name, required this.description, this.value, this.required = false});

  /// "{gop:2s}"
  final String name;
  final String description;

  /// What it expands to for the sample context, from the core; null if the
  /// core gave none.
  final String? value;

  /// `{inputs}` and `{output}`: Vegas Encoder owns them.
  final bool required;
}

/// What each macro is for (UI copy; the core lists the macros and expands
/// them). Unknown names use the core's own description.
const macroDescriptions = <String, String>{
  '{inputs}': 'VEGAS video and audio pipes, with their format, size and rate. Added by Vegas Encoder.',
  '{output}': 'The file name chosen in Render As. Vegas Encoder writes to a temporary name and publishes on success.',
  '{v}': 'The VEGAS video stream, for -map and filter graphs.',
  '{a}': 'The VEGAS audio stream, when the render has audio.',
  '{width}': 'Delivered frame width in pixels.',
  '{height}': 'Delivered frame height in pixels.',
  '{fps}': 'Delivered frame rate as a fraction.',
  '{gop:2s}': 'Frames in the given number of seconds at the delivered rate. Change 2 to any number of seconds.',
  '{sample_rate}': 'Delivered audio sample rate.',
  '{project}': 'VEGAS project file name without extension.',
};

const requiredMacros = {'{inputs}', '{output}'};

/// The macros the core offers (`VeCore.complete` after "{"), with the values
/// the core expanded them to in [probe]: a compile of [probeText], the names
/// joined by spaces, so the word starting at each name's offset is its value.
List<MacroEntry> macroEntries(core.CompletionResult offered, String probeText, core.CompileResult? probe) {
  final values = <int, String>{};
  for (final t in probe?.display ?? const <core.CommandToken>[]) {
    final span = sourceSpan(t, probeText.length);
    if (span != null && t.role != core.TokenRole.input) values.putIfAbsent(span.$1, () => t.text);
  }
  final out = <MacroEntry>[];
  var offset = 0;
  for (final s in offered.items) {
    final name = s.value;
    final value = values[offset];
    out.add(
      MacroEntry(
        name: name,
        description: macroDescriptions[name] ?? s.description,
        value: requiredMacros.contains(name) || value == name ? null : value,
        required: requiredMacros.contains(name),
      ),
    );
    offset += name.length + 1;
  }
  return out;
}

/// The probe command for [macroEntries]: the offered names, space-separated.
String macroProbeText(core.CompletionResult offered) => offered.items.map((s) => s.value).join(' ');

// ------------------------------------------------------------ Basic summary

/// "x264 slow, CRF 18, 8-bit. AAC 320 kb/s. MP4." from the core's summary of
/// the recipe compiled as Basic.
String basicSummaryLine(Map<String, Object?> summary) {
  String? s(String key) {
    final v = summary[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  final video = [
    [s('videoEncoder'), s('speed')].whereType<String>().join(' '),
    ?s('videoQuality'),
    ?s('depth'),
  ].where((p) => p.isNotEmpty).join(', ');
  final audio = s('audio');
  final audioLine = audio == null || audio == 'No audio' ? 'No audio' : [audio, ?s('audioQuality')].join(' ');
  return [video, audioLine, ?s('container')].where((p) => p.isNotEmpty).map((p) => '$p.').join(' ');
}
