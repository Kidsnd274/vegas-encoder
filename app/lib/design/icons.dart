import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// One shape of an icon, in the 16-unit (or 18-unit) icon box.
sealed class _Shape {
  const _Shape({this.fill = false});
  final bool fill;
}

class _PathShape extends _Shape {
  const _PathShape(this.d, {super.fill});
  final String d;
}

class _Circle extends _Shape {
  const _Circle(this.cx, this.cy, this.r, {super.fill});
  final double cx, cy, r;
}

class _Rect extends _Shape {
  const _Rect(this.x, this.y, this.w, this.h, this.rx);
  final double x, y, w, h, rx;
}

/// A stroked line icon from `signal-flow.html` (the `I` table): 16-unit box,
/// round caps and joins, drawn in the current text colour.
@immutable
class VeIconData {
  const VeIconData._(this.name, this._shapes, {this.stroke = 1.5, this.defaultSize = 16});
  final String name;
  final List<_Shape> _shapes;
  final double stroke;
  final double defaultSize;
}

abstract final class VeIcons {
  static const lock = VeIconData._('lock', [
    _Rect(3.5, 7, 9, 6.5, 1.5),
    _PathShape('M5.5 7V5a2.5 2.5 0 0 1 5 0v2'),
  ], defaultSize: 14);
  static const chevronDown = VeIconData._('chevronDown', [_PathShape('M4.5 6.5 8 10l3.5-3.5')], defaultSize: 14);
  static const chevronRight = VeIconData._('chevronRight', [_PathShape('M6.5 4.5 10 8l-3.5 3.5')], defaultSize: 14);
  static const search = VeIconData._('search', [_Circle(7, 7, 4.5), _PathShape('m10.5 10.5 3 3')]);
  static const star = VeIconData._('star', [
    _PathShape('m8 2 1.8 3.8 4.2.5-3.1 2.9.8 4.1L8 11.3l-3.7 2 .8-4.1L2 6.3l4.2-.5z'),
  ], defaultSize: 15);
  static const starFilled = VeIconData._(
    'starFilled',
    [_PathShape('m8 2 1.8 3.8 4.2.5-3.1 2.9.8 4.1L8 11.3l-3.7 2 .8-4.1L2 6.3l4.2-.5z', fill: true)],
    stroke: 1.2,
    defaultSize: 15,
  );
  static const error = VeIconData._('error', [_Circle(8, 8, 6.5), _PathShape('M8 4.8v3.6M8 10.9v.2')]);
  static const warning = VeIconData._('warning', [
    _PathShape('M8 2.2 14.3 13.3H1.7z'),
    _PathShape('M8 6.5v3M8 11.3v.2'),
  ]);
  static const info = VeIconData._('info', [_Circle(8, 8, 6.5), _PathShape('M8 7.3v3.9M8 4.9v.2')]);
  static const hint = VeIconData._('hint', [
    _PathShape('M6 13.5h4M6.5 11.5h3M8 2a4 4 0 0 0-2.4 7.2c.5.4.9 1 .9 1.6v.2h3v-.2c0-.6.4-1.2.9-1.6A4 4 0 0 0 8 2z'),
  ]);
  static const check = VeIconData._('check', [_PathShape('m3.5 8.5 3 3 6-7')]);
  static const dash = VeIconData._('dash', [_PathShape('M4 8h8')]);
  static const copy = VeIconData._('copy', [
    _Rect(5.5, 5.5, 8, 8, 1.5),
    _PathShape('M10.5 5.5v-2a1 1 0 0 0-1-1h-6a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2'),
  ], defaultSize: 14);
  static const plus = VeIconData._('plus', [_PathShape('M8 3v10M3 8h10')], defaultSize: 14);
  static const refresh = VeIconData._('refresh', [
    _PathShape('M13.2 8a5.2 5.2 0 1 1-1.6-3.8M13.2 2.5v3h-3'),
  ], defaultSize: 14);
  static const flask = VeIconData._('flask', [
    _PathShape('M6 2h4M6.5 2v4.2L3.2 12.6A1.2 1.2 0 0 0 4.3 14.4h7.4a1.2 1.2 0 0 0 1.1-1.8L9.5 6.2V2M4.6 10h6.8'),
  ], defaultSize: 14);
  static const folder = VeIconData._('folder', [
    _PathShape('M2 4.5a1 1 0 0 1 1-1h3l1.5 1.5H13a1 1 0 0 1 1 1V12a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1z'),
  ], defaultSize: 14);
  static const layers = VeIconData._('layers', [
    _PathShape('M8 2 14 5 8 8 2 5z'),
    _PathShape('m2 8 6 3 6-3M2 11l6 3 6-3'),
  ], defaultSize: 14);
  static const save = VeIconData._('save', [
    _PathShape('M3 2.5h8l2.5 2.5v8.5H3z'),
    _PathShape('M5.5 2.5v3h4v-3M5.5 13.5v-4h5v4'),
  ], defaultSize: 14);
  static const pin = VeIconData._('pin', [_PathShape('M6 2.5h4M7 2.5v4L4.5 9h7L9 6.5v-4M8 9v4.5')], defaultSize: 14);
  static const bullet = VeIconData._('bullet', [_Circle(8, 8, 2.2, fill: true)]);
  // Window controls: 1-unit strokes at 12 px.
  static const minimize = VeIconData._('minimize', [_PathShape('M3 8h10')], stroke: 1, defaultSize: 12);
  static const maximize = VeIconData._('maximize', [_Rect(3.5, 3.5, 9, 9, 1)], stroke: 1, defaultSize: 12);
  static const restore = VeIconData._(
    'restore',
    [_Rect(3.5, 5.5, 7, 7, 1), _PathShape('M5.5 5.5V4.5a1 1 0 0 1 1-1h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1h-1')],
    stroke: 1,
    defaultSize: 12,
  );
  static const close = VeIconData._('close', [_PathShape('m3.5 3.5 9 9M12.5 3.5l-9 9')], stroke: 1, defaultSize: 12);

  static const List<VeIconData> all = [
    lock,
    chevronDown,
    chevronRight,
    search,
    star,
    starFilled,
    error,
    warning,
    info,
    hint,
    check,
    dash,
    copy,
    plus,
    refresh,
    flask,
    folder,
    layers,
    save,
    pin,
    bullet,
    minimize,
    maximize,
    restore,
    close,
  ];
}

/// Draws a [VeIconData]. The colour defaults to the ambient text colour, like
/// SVG `currentColor`.
class VeIcon extends StatelessWidget {
  const VeIcon(this.icon, {super.key, this.size, this.color});

  final VeIconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = size ?? icon.defaultSize;
    final c = color ?? DefaultTextStyle.of(context).style.color ?? VeTokens.of(context).colors.ink;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: s,
        child: CustomPaint(painter: _IconPainter(icon, c)),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color);
  final VeIconData icon;
  final Color color;

  static final Map<String, Path> _cache = {};

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 16, size.height / 16);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = icon.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..isAntiAlias = true;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;
    for (final shape in icon._shapes) {
      final Path path = switch (shape) {
        _PathShape(:final d) => _cache.putIfAbsent(d, () => parseSvgPath(d)),
        _Circle(:final cx, :final cy, :final r) => Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
        _Rect(:final x, :final y, :final w, :final h, :final rx) =>
          Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rx))),
      };
      if (shape.fill) canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.icon != icon || old.color != color;
}

/// Parses the subset of SVG path data the icons use: M L H V C A Z, absolute
/// and relative, with implicit repeats.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MmLlHhVvCcAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  var i = 0;
  var cmd = 'M';
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'M':
        x = (rel ? x : 0) + next();
        y = (rel ? y : 0) + next();
        path.moveTo(x, y);
        startX = x;
        startY = y;
        cmd = rel ? 'l' : 'L'; // further pairs are line-tos
      case 'L':
        x = (rel ? x : 0) + next();
        y = (rel ? y : 0) + next();
        path.lineTo(x, y);
      case 'H':
        x = (rel ? x : 0) + next();
        path.lineTo(x, y);
      case 'V':
        y = (rel ? y : 0) + next();
        path.lineTo(x, y);
      case 'C':
        final x1 = (rel ? x : 0) + next(), y1 = (rel ? y : 0) + next();
        final x2 = (rel ? x : 0) + next(), y2 = (rel ? y : 0) + next();
        x = (rel ? x : 0) + next();
        y = (rel ? y : 0) + next();
        path.cubicTo(x1, y1, x2, y2, x, y);
      case 'A':
        final rx = next(), ry = next(), rotation = next();
        final largeArc = next() != 0, sweep = next() != 0;
        x = (rel ? x : 0) + next();
        y = (rel ? y : 0) + next();
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation * math.pi / 180,
          largeArc: largeArc,
          clockwise: sweep,
        );
      case 'Z':
        path.close();
        x = startX;
        y = startY;
        cmd = '?'; // a number straight after Z is malformed
      default:
        throw FormatException('Unsupported SVG path command $cmd in "$d"');
    }
  }
  return path;
}

/// The app mark: a thick-to-thin video wire with a conversion pip
/// (`I.logo`, 18-unit box).
class VeLogo extends StatelessWidget {
  const VeLogo({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _LogoPainter(VeTokens.of(context).colors)),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.c);
  final VePalette c;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 18);
    final box = RRect.fromRectAndRadius(const Rect.fromLTWH(1, 1, 16, 16), const Radius.circular(4));
    canvas.drawRRect(box, Paint()..color = c.surface);
    canvas.drawRRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = c.line2,
    );
    canvas.drawLine(
      const Offset(3.5, 9),
      const Offset(9, 9),
      Paint()
        ..color = c.videoWire
        ..strokeWidth = 3.2,
    );
    canvas.drawLine(
      const Offset(9, 9),
      const Offset(14.5, 9),
      Paint()
        ..color = c.videoWire
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(const Offset(9, 9), 2.4, Paint()..color = c.pip);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.c != c;
}

/// The library and progress-window glyph: a 10-bit wire in, thick or thin
/// out, with a pip where 10-bit becomes 8-bit (`wireGlyph` in the mockup).
class WireGlyph extends StatelessWidget {
  const WireGlyph({super.key, required this.outputDepth, this.inputDepth = 10});
  final int inputDepth;
  final int outputDepth;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 28,
        height: 12,
        child: CustomPaint(painter: _WireGlyphPainter(VeTokens.of(context).colors, inputDepth, outputDepth)),
      ),
    );
  }
}

class _WireGlyphPainter extends CustomPainter {
  _WireGlyphPainter(this.c, this.inputDepth, this.outputDepth);
  final VePalette c;
  final int inputDepth, outputDepth;

  @override
  void paint(Canvas canvas, Size size) {
    final wire = Paint()..color = c.videoWire;
    canvas.drawLine(const Offset(0, 6), const Offset(13, 6), wire..strokeWidth = inputDepth >= 10 ? 5 : 2);
    canvas.drawLine(const Offset(13, 6), const Offset(28, 6), wire..strokeWidth = outputDepth >= 10 ? 5 : 2);
    if (outputDepth < inputDepth) canvas.drawCircle(const Offset(13, 6), 3.2, Paint()..color = c.pip);
  }

  @override
  bool shouldRepaint(_WireGlyphPainter old) =>
      old.c != c || old.inputDepth != inputDepth || old.outputDepth != outputDepth;
}
