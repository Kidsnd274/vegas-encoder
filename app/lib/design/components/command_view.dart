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
  const CommandToken(this.text, {this.extra = false, this.error = false, this.field});

  final String text;

  /// Came from Extra arguments.
  final bool extra;

  /// FFmpeg rejects it, or validation found an error at it.
  final bool error;

  /// The recipe field that produced it; clicking the token focuses it.
  final String? field;

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

class _CommandViewState extends State<CommandView> {
  bool _inputsOpen = false;
  MouseCursor _cursor = SystemMouseCursors.basic;
  TextPainter? _painter;
  double? _laidOutWidth;

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
    final built = _build(t);
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

  ({TextSpan span, List<_Range> ranges}) _build(VeTokens t) {
    final c = t.colors;
    final mono = t.text.mono.copyWith(color: c.ink);
    final spans = <TextSpan>[];
    final ranges = <_Range>[];
    var offset = 0;

    void add(String text, TextStyle style, {CommandToken? token, CommandRole? role, bool chip = false}) {
      spans.add(TextSpan(text: text, style: style));
      if (token != null || chip) ranges.add(_Range(offset, offset + text.length, token: token, role: role, chip: chip));
      offset += text.length;
    }

    Color roleColor(CommandRole r) => switch (r) {
      CommandRole.video => c.videoWire,
      CommandRole.audio => c.audioWire,
      CommandRole.mux || CommandRole.output => c.containerWire,
      CommandRole.inputs => c.muted,
    };

    void tokens(List<CommandToken> list, CommandRole role) {
      final start = offset;
      for (var i = 0; i < list.length; i++) {
        final tok = list[i];
        if (i > 0) add(' ', mono);
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
        add(tok.text, style, token: tok, role: role);
      }
      ranges.add(_Range(start, offset, role: role));
    }

    final cmd = widget.command;
    final lines = [...cmd.lines];
    final mapLine = lines.isNotEmpty && lines.first.role == CommandRole.inputs ? lines.removeAt(0) : null;
    final joiner = widget.multiline ? ' ^\n  ' : ' ';

    // Program line: ffmpeg, the inputs chip (or the pipes), the maps.
    final groupStart = offset;
    add(cmd.program, mono);
    add(' ', mono);
    if (_inputsOpen) {
      tokens(cmd.inputs, CommandRole.inputs);
    } else {
      add(
        ' ${cmd.inputsLabel} ',
        t.text.caption.copyWith(color: c.text2, fontWeight: const FontWeight(600), height: 1.7 * 12.5 / 12),
        chip: true,
      );
    }
    if (mapLine != null && mapLine.tokens.isNotEmpty) {
      add(' ', mono);
      tokens(mapLine.tokens, CommandRole.inputs);
    }
    ranges.add(_Range(groupStart, offset, role: CommandRole.inputs));

    for (final line in lines) {
      if (line.tokens.isEmpty) continue;
      add(joiner, mono);
      tokens(line.tokens, line.role);
    }
    return (span: TextSpan(children: spans, style: mono), ranges: ranges);
  }
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
      for (final r in ranges.where((r) => r.token?.field != null && lit.contains(r.token!.field))) {
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
