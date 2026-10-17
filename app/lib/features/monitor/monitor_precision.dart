import 'package:flutter/widgets.dart';

import '../../design/components/button.dart';
import '../../design/tokens.dart';

/// C5's compiled encoder-input precision, before codec compression. The
/// monitor has no source depth: a uniform wire avoids inventing one. Only
/// the engine's explicit reduction fact adds a pip; null stays unknown.
class MonitorPrecision extends StatelessWidget {
  const MonitorPrecision({super.key, required this.outputBitDepth, required this.conversionReducesPrecision});

  final int outputBitDepth;
  final bool? conversionReducesPrecision;

  @override
  Widget build(BuildContext context) {
    final label =
        '$outputBitDepth-bit at encoder input. ${switch (conversionReducesPrecision) {
          true => 'Pixel-format conversion reduces precision.',
          false => 'Pixel-format conversion does not reduce precision.',
          null => 'Pixel-format precision change is unknown.',
        }}';
    return Semantics(
      label: label,
      child: VeTooltip(
        message: '$label Before codec compression; not measured file precision.',
        child: ExcludeSemantics(
          child: SizedBox(
            width: 28,
            height: 12,
            child: CustomPaint(
              painter: _PrecisionPainter(VeTokens.of(context).colors, outputBitDepth, conversionReducesPrecision),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrecisionPainter extends CustomPainter {
  _PrecisionPainter(this.colors, this.depth, this.reducesPrecision);

  final VePalette colors;
  final int depth;
  final bool? reducesPrecision;

  @override
  void paint(Canvas canvas, Size size) {
    final wire = Paint()
      ..color = colors.videoWire
      ..strokeWidth = depth >= 10 ? 5 : 2;
    if (reducesPrecision == null) {
      // The central gap leaves the conversion unknown, while both line
      // segments describe the known encoder-input depth only.
      canvas.drawLine(const Offset(0, 6), const Offset(10, 6), wire);
      canvas.drawLine(const Offset(18, 6), const Offset(28, 6), wire);
    } else {
      canvas.drawLine(const Offset(0, 6), const Offset(28, 6), wire);
    }
    if (reducesPrecision == true) canvas.drawCircle(const Offset(14, 6), 3.2, Paint()..color = colors.pip);
  }

  @override
  bool shouldRepaint(_PrecisionPainter old) =>
      old.colors != colors || old.depth != depth || old.reducesPrecision != reducesPrecision;
}
