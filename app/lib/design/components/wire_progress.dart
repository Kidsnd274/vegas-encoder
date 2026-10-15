import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// The bar's colour: the video wire while rendering, then the outcome.
enum VeWireTone {
  /// `.prog`: the video wire.
  video,

  /// `.prog.done`.
  success,

  /// `.prog.bad`: a dashed red wire.
  error,

  /// Stopped without a failure (cancelled): a quiet grey wire.
  stopped,
}

/// The progress window's bar (`.prog`, S6): a video wire with a round head on
/// dotted paper. [fraction] null draws the paper alone (the total is
/// unknown). It moves without animation: the window redraws only when the
/// render's status changes.
class VeWireProgress extends StatelessWidget {
  const VeWireProgress({super.key, required this.fraction, this.tone = VeWireTone.video, this.semanticLabel});

  final double? fraction;
  final VeWireTone tone;

  /// What a screen reader hears, such as "Render progress".
  final String? semanticLabel;

  static const double height = 20;

  @override
  Widget build(BuildContext context) {
    final c = VeTokens.of(context).colors;
    final f = fraction;
    return Semantics(
      label: semanticLabel,
      value: f == null ? null : '${(f * 100).floor()}%',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _WirePainter(c, f, tone)),
      ),
    );
  }
}

class _WirePainter extends CustomPainter {
  _WirePainter(this.c, this.fraction, this.tone);
  final VePalette c;
  final double? fraction;
  final VeWireTone tone;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5));
    canvas.drawRRect(track, Paint()..color = c.paper);
    canvas.save();
    canvas.clipRRect(track);
    final dot = Paint()..color = c.dots;
    for (var y = 4.0; y < size.height; y += 8) {
      for (var x = 4.0; x < size.width; x += 8) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
    canvas.restore();

    final f = fraction;
    if (f == null) return;
    final color = switch (tone) {
      VeWireTone.video => c.videoWire,
      VeWireTone.success => c.success,
      VeWireTone.error => c.error,
      VeWireTone.stopped => c.faint,
    };
    final end = size.width * f.clamp(0.0, 1.0);
    final wire = Paint()..color = color;
    if (tone == VeWireTone.error) {
      // `repeating-linear-gradient(90deg, err 0 6px, transparent 6px 11px)`
      for (var x = 0.0; x < end; x += 11) {
        canvas.drawRect(Rect.fromLTRB(x, 6, (x + 6).clamp(0, end), 14), wire);
      }
    } else if (end > 0) {
      canvas.drawRRect(RRect.fromLTRBR(0, 6, end, 14, const Radius.circular(4)), wire);
    }
    // The head stays whole inside the bar at either end.
    final x = end.clamp(8.0, size.width - 8.0);
    final head = Offset(x, size.height / 2);
    canvas.drawCircle(head, 6.5, Paint()..color = c.surface);
    canvas.drawCircle(
      head,
      6.5,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_WirePainter old) => old.c != c || old.fraction != fraction || old.tone != tone;
}
