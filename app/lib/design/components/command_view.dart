import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../tokens.dart';
import 'button.dart';

/// Which part of the command a token belongs to (UI_SPEC §10 roles).
enum CommandRole { inputs, video, audio, mux, output }

/// One argument as the core compiled it, already quoted for display.
@immutable
class CommandToken {
  const CommandToken(this.text, {this.extra = false, this.error = false, this.field, this.replacedField});

  final String text;

  /// Came from Extra arguments.
  final bool extra;

  /// FFmpeg rejects it, or validation found an error at it.
  final bool error;

  /// The recipe field that produced it; clicking the token focuses it.
  final String? field;

  /// The control an Extra argument replaced; pointing at that control lights
  /// this token too.
  final String? replacedField;

  bool litBy(Set<String> fields) => fields.contains(field) || fields.contains(replacedField);

  bool get isFlag => text.length > 1 && text.startsWith('-') && RegExp(r'^-[A-Za-z]').hasMatch(text);
}

/// One group, drawn on its own line in the grouped layout.
@immutable
class CommandLine {
  const CommandLine(this.role, this.tokens);
  final CommandRole role;
  final List<CommandToken> tokens;
}

/// The compiled command in display form. [inputs] are the VEGAS pipes that
/// Vegas Encoder owns; they collapse into a chip.
@immutable
class CommandDisplay {
  const CommandDisplay({
    required this.inputs,
    required this.lines,
    required this.copyText,
    this.program = 'ffmpeg',
    this.inputsLabel = 'VEGAS video + audio',
  });

  final String program;
  final List<CommandToken> inputs;
  final String inputsLabel;

  /// Lines after the inputs. A first line with role [CommandRole.inputs]
  /// (the `-map` arguments) joins the program line.
  final List<CommandLine> lines;

  /// What Copy puts on the clipboard: the full command with real pipe names.
  final String copyText;
}

/// `CommandView` (UI_SPEC §2, §11): the live FFmpeg command, coloured by role.
/// The selected node's group is tinted; tokens for a hovered control are lit;
/// clicking a token reports its field. The inputs chip expands on click.
class CommandView extends StatefulWidget {
  const CommandView({
    super.key,
    required this.command,
    this.activeRole,
    this.litFields = const {},
    this.onTokenTap,
    this.multiline = true,
    this.maxHeight = 260,
  });

  final CommandDisplay command;
  final CommandRole? activeRole;
  final Set<String> litFields;
  final ValueChanged<CommandToken>? onTokenTap;
  final bool multiline;
  final double maxHeight;

  @override
  State<CommandView> createState() => _CommandViewState();
}

class _Range {
  _Range(this.start, this.end, {this.token, this.role, this.chip = false});
  final int start;
  final int end;
  final CommandToken? token;
  final CommandRole? role;
  final bool chip;
}

/// One piece of text in the command: a token, the program name, or the
/// inputs chip.
class _Piece {
  const _Piece(this.text, this.style, {this.token, this.role, this.chip = false});
  final String text;
  final TextStyle style;
  final CommandToken? token;
  final CommandRole? role;
  final bool chip;
}

/// Pieces that stay on one visual line: an option and its value
/// (`-profile:v high`), or a piece on its own. Joined by single spaces.
class _Unit {
  _Unit(this.pieces);
  final List<_Piece> pieces;
}

class _CommandViewState extends State<CommandView> {
  bool _inputsOpen = false;
  MouseCursor _cursor = SystemMouseCursors.basic;
  TextPainter? _painter;
  double? _laidOutWidth;

  /// Measured widths of pieces, for [_build]'s line breaking. Cleared when the
  /// text scale or the theme changes.
  final Map<(String, TextStyle), double> _widths = {};
  TextScaler? _measuredScaler;
  VeTokens? _measuredTokens;

  double _width(String text, TextStyle style, TextScaler scaler) => _widths.putIfAbsent((text, style), () {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  });

  /// The same layout RichText makes, for backgrounds and hit testing.
  TextPainter _layout(TextSpan span, double width, TextScaler scaler) {
    final p = _painter;
    if (p != null && p.text == span && p.textScaler == scaler && _laidOutWidth == width) return p;
    p?.dispose();
    _laidOutWidth = width;
    return _painter = TextPainter(text: span, textDirection: TextDirection.ltr, textScaler: scaler)
      ..layout(maxWidth: width);
  }

  @override
  void dispose() {
    _painter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Semantics(
      label: 'FFmpeg command',
      value: widget.command.copyText,
      readOnly: true,
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(VeRadius.lg),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: LayoutBuilder(
            builder: (context, box) {
              final scaler = MediaQuery.textScalerOf(context);
              final built = _build(t, box.maxWidth, scaler);
              final painter = _layout(built.span, box.maxWidth, scaler);
              _Range? hit(Offset p) {
                final pos = painter.getPositionForOffset(p).offset;
                for (final r in built.ranges) {
                  if ((r.token != null || r.chip) && pos >= r.start && pos < r.end) {
                    final boxes = painter.getBoxesForSelection(TextSelection(baseOffset: r.start, extentOffset: r.end));
                    if (boxes.any((b) => b.toRect().inflate(2).contains(p))) return r;
                  }
                }
                return null;
              }

              return MouseRegion(
                cursor: _cursor,
                onHover: (e) {
                  final r = hit(e.localPosition);
                  final want = r != null && (r.chip || (r.token?.field != null && widget.onTokenTap != null))
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic;
                  if (want != _cursor) setState(() => _cursor = want);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    final r = hit(d.localPosition);
                    if (r == null) return;
                    if (r.chip) {
                      setState(() => _inputsOpen = !_inputsOpen);
                    } else if (r.token != null) {
                      widget.onTokenTap?.call(r.token!);
                    }
                  },
                  child: CustomPaint(
                    painter: _CommandBackground(painter, built.ranges, widget.activeRole, widget.litFields, t),
                    child: RichText(text: built.span, textScaler: scaler),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The command as one span for [maxWidth]. Line breaks are chosen here, not
  /// by the paragraph: a line breaks only between units, so an option stays
  /// with its value, and a wrapped line starts with a hanging indent
  /// ([hangingIndent] spaces) so it reads as a continuation, not a new group.
  ({TextSpan span, List<_Range> ranges}) _build(VeTokens t, double maxWidth, TextScaler scaler) {
    final c = t.colors;
    final mono = t.text.mono.copyWith(color: c.ink);
    if (_measuredScaler != scaler || _measuredTokens != t) {
      _widths.clear();
      _measuredScaler = scaler;
      _measuredTokens = t;
    }

    Color roleColor(CommandRole r) => switch (r) {
      CommandRole.video => c.videoWire,
      CommandRole.audio => c.audioWire,
      CommandRole.mux || CommandRole.output => c.containerWire,
      CommandRole.inputs => c.muted,
    };

    _Piece piece(CommandToken tok, CommandRole role) {
      var style = mono;
      if (tok.isFlag) {
        style = style.copyWith(color: roleColor(role), fontWeight: const FontWeight(600));
      }
      if (tok.extra) style = style.copyWith(color: c.warning);
      if (tok.error) {
        style = style.copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.wavy,
          decorationColor: c.error,
        );
      }
      return _Piece(tok.text, style, token: tok, role: role);
    }

    // An option and the value after it form one unit.
    List<_Unit> units(List<CommandToken> list, CommandRole role) {
      final out = <_Unit>[];
      for (var i = 0; i < list.length; i++) {
        final glued = list[i].isFlag && i + 1 < list.length && !list[i + 1].isFlag;
        out.add(_Unit([piece(list[i], role), if (glued) piece(list[++i], role)]));
      }
      return out;
    }

    final cmd = widget.command;
    final groups = [...cmd.lines];
    final mapLine = groups.isNotEmpty && groups.first.role == CommandRole.inputs ? groups.removeAt(0) : null;

    // Program line: ffmpeg, the inputs chip (or the pipes), the maps.
    final programLine = (
      role: CommandRole.inputs,
      units: [
        _Unit([_Piece(cmd.program, mono)]),
        if (_inputsOpen)
          ...units(cmd.inputs, CommandRole.inputs)
        else
          _Unit([
            _Piece(
              ' ${cmd.inputsLabel} ',
              t.text.caption.copyWith(color: c.text2, fontWeight: const FontWeight(600), height: 1.7 * 12.5 / 12),
              chip: true,
            ),
          ]),
        if (mapLine != null) ...units(mapLine.tokens, CommandRole.inputs),
      ],
    );
    final lines = [
      programLine,
      for (final g in groups)
        if (g.tokens.isNotEmpty) (role: g.role, units: units(g.tokens, g.role)),
    ];
    // One line: everything flows as one logical line.
    final logical = widget.multiline
        ? lines
        : [
            (role: CommandRole.inputs, units: [for (final l in lines) ...l.units]),
          ];

    final spans = <TextSpan>[];
    final ranges = <_Range>[];
    var offset = 0;
    void add(String text, TextStyle style, {CommandToken? token, CommandRole? role, bool chip = false}) {
      spans.add(TextSpan(text: text, style: style));
      if (token != null || chip) ranges.add(_Range(offset, offset + text.length, token: token, role: role, chip: chip));
      offset += text.length;
    }

    final space = _width(' ', mono, scaler);
    double unitWidth(_Unit u) =>
        u.pieces.fold(0.0, (w, p) => w + _width(p.text, p.style, scaler)) + space * (u.pieces.length - 1);
    // A little slack, so the paragraph never wraps a line this fitting kept.
    final room = maxWidth - 2;
    final hang = ' ' * (widget.multiline ? hangingIndent : hangingIndent - 2);

    for (var li = 0; li < logical.length; li++) {
      final line = logical[li];
      final last = li == logical.length - 1;
      final lead = li == 0 ? '' : '  ';
      if (li > 0) add(' ^\n$lead', mono);
      var x = space * lead.length;
      // The selected node's tint: one range per visual line, so it never
      // covers the hanging indent.
      var segment = offset;
      // In the grouped layout each line but the last ends with " ^".
      final caret = widget.multiline && !last ? 2 * space : 0.0;
      for (var ui = 0; ui < line.units.length; ui++) {
        final unit = line.units[ui];
        final w = unitWidth(unit);
        final tail = ui == line.units.length - 1 ? caret : 0.0;
        if (ui > 0) {
          if (x + space + w + tail > room) {
            ranges.add(_Range(segment, offset, role: line.role));
            add('\n$hang', mono);
            segment = offset;
            x = space * hang.length;
          } else {
            add(' ', mono);
            x += space;
          }
        }
        for (var pi = 0; pi < unit.pieces.length; pi++) {
          final p = unit.pieces[pi];
          if (pi > 0) add(' ', mono);
          add(p.text, p.style, token: p.token, role: p.role, chip: p.chip);
        }
        x += w;
      }
      ranges.add(_Range(segment, offset, role: line.role));
    }
    return (span: TextSpan(children: spans, style: mono), ranges: ranges);
  }

  /// Spaces before a wrapped part of a line in the grouped layout (two in the
  /// one-line layout), past the two that start each group.
  static const int hangingIndent = 4;
}

/// Group tints, lit tokens and the inputs chip, under the text.
class _CommandBackground extends CustomPainter {
  _CommandBackground(this.text, this.ranges, this.activeRole, this.lit, this.t);
  final TextPainter text;
  final List<_Range> ranges;
  final CommandRole? activeRole;
  final Set<String> lit;
  final VeTokens t;

  /// One rectangle per visual line of the range, like an inline background.
  Iterable<Rect> _boxes(int start, int end) {
    final lines = <Rect>[];
    for (final b in text.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
      boxHeightStyle: ui.BoxHeightStyle.max,
    )) {
      final r = b.toRect();
      final i = lines.indexWhere((l) => (l.center.dy - r.center.dy).abs() < r.height / 2);
      if (i < 0) {
        lines.add(r);
      } else {
        lines[i] = lines[i].expandToInclude(r);
      }
    }
    return lines;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = t.colors;
    if (activeRole != null) {
      final tint = switch (activeRole!) {
        CommandRole.video => c.videoTint,
        CommandRole.audio => c.audioTint,
        CommandRole.mux || CommandRole.output => c.containerTint,
        CommandRole.inputs => null,
      };
      if (tint != null) {
        final paint = Paint()..color = tint;
        for (final r in ranges.where((r) => r.token == null && !r.chip && r.role == activeRole)) {
          for (final b in _boxes(r.start, r.end)) {
            canvas.drawRRect(RRect.fromRectAndRadius(b.inflate(3), const Radius.circular(4)), paint);
          }
        }
      }
    }
    if (lit.isNotEmpty) {
      final paint = Paint()..color = c.highlight;
      for (final r in ranges.where((r) => r.token?.litBy(lit) ?? false)) {
        for (final b in _boxes(r.start, r.end)) {
          canvas.drawRRect(RRect.fromRectAndRadius(b.inflate(2), const Radius.circular(3)), paint);
        }
      }
    }
    for (final r in ranges.where((r) => r.chip)) {
      for (final b in _boxes(r.start, r.end)) {
        final rect = Rect.fromLTRB(b.left, b.top + 4, b.right, b.bottom - 4);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));
        canvas.drawRRect(rrect, Paint()..color = c.fill);
        final dash = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = c.faint;
        for (final m in (Path()..addRRect(rrect.deflate(0.5))).computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 6) {
            canvas.drawPath(m.extractPath(d, d + 3), dash);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CommandBackground old) =>
      old.text != text || old.activeRole != activeRole || old.lit != lit || old.t != t;
}

/// The command column's heading: "Command" and Copy (Ctrl+Shift+C).
class CommandHeader extends StatelessWidget {
  const CommandHeader({super.key, required this.onCopy, this.title = 'Command', this.note});

  final VoidCallback? onCopy;
  final String title;

  /// Right-hand note in place of Copy, such as "from these settings".
  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Row(
      children: [
        Text(title, style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(650))),
        const Spacer(),
        if (note != null) Text(note!, style: t.text.caption.copyWith(color: t.colors.muted)),
        if (onCopy != null)
          VeButton(
            label: 'Copy',
            icon: VeIcons.copy,
            variant: VeButtonVariant.ghost,
            size: VeButtonSize.small,
            tooltip: 'Copy the command (Ctrl+Shift+C)',
            onPressed: onCopy,
          ),
      ],
    );
  }
}

/// Puts [text] on the clipboard.
Future<void> copyCommand(String text) => Clipboard.setData(ClipboardData(text: text));
