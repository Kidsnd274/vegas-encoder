import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'field.dart';
import 'text_field.dart';

/// A closed range on a slider's scale.
typedef VeRange = ({double start, double end});

/// `.rng`: a slider on a 4 px track with a ringed thumb.
///
/// Right always means "more" of what the ends say. For lower-is-better scales
/// (CRF, CQ, QP) pass [reversed]: the largest value sits at the left, so right
/// is still higher quality (UI_SPEC §2). Keys: arrows step by [step], Page Up
/// and Page Down by [pageSteps] steps, Home and End go to the left and right
/// ends.
class VeSlider extends StatefulWidget {
  const VeSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.semanticLabel,
    this.semanticValue,
    this.step = 1,
    this.pageSteps = 5,
    this.reversed = false,
    this.band,
    this.onChangeEnd,
    this.focusNode,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final int pageSteps;
  final bool reversed;

  /// A recommended range, drawn as a wider band on the track.
  final VeRange? band;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String semanticLabel;

  /// Spoken value with its meaning, such as "CRF 18, visually lossless".
  final String Function(double value)? semanticValue;
  final FocusNode? focusNode;

  @override
  State<VeSlider> createState() => _VeSliderState();
}

class _VeSliderState extends State<VeSlider> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'slider'));
  bool _showFocus = false;
  bool _hover = false;

  static const double _thumb = 16;
  static const double _height = 24;

  @override
  void dispose() {
    _ownFocus?.dispose();
    super.dispose();
  }

  double _snap(double v) {
    final stepped = widget.min + ((v - widget.min) / widget.step).round() * widget.step;
    return stepped.clamp(widget.min, widget.max).toDouble();
  }

  /// Fraction of the travel from the left end.
  double _fraction(double v) {
    final span = widget.max - widget.min;
    final t = span == 0 ? 0.0 : (v - widget.min) / span;
    return widget.reversed ? 1 - t : t;
  }

  double _valueAt(double dx, double width) {
    final travel = math.max(1.0, width - _thumb);
    var f = ((dx - _thumb / 2) / travel).clamp(0.0, 1.0);
    if (widget.reversed) f = 1 - f;
    return _snap(widget.min + f * (widget.max - widget.min));
  }

  void _set(double v, {bool end = false}) {
    final s = _snap(v);
    if (s != widget.value) widget.onChanged?.call(s);
    if (end) widget.onChangeEnd?.call(s);
  }

  /// Moves right (toward "higher quality" / "faster") by [steps].
  void _moveRight(double steps) => _set(widget.value + (widget.reversed ? -1 : 1) * steps * widget.step, end: true);

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (widget.onChanged == null) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.arrowUp) {
      _moveRight(1);
    } else if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowDown) {
      _moveRight(-1);
    } else if (k == LogicalKeyboardKey.pageUp) {
      _moveRight(widget.pageSteps.toDouble());
    } else if (k == LogicalKeyboardKey.pageDown) {
      _moveRight(-widget.pageSteps.toDouble());
    } else if (k == LogicalKeyboardKey.home) {
      _set(widget.reversed ? widget.max : widget.min, end: true);
    } else if (k == LogicalKeyboardKey.end) {
      _set(widget.reversed ? widget.min : widget.max, end: true);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final enabled = widget.onChanged != null;
    final spoken = widget.semanticValue?.call(widget.value) ?? _plain(widget.value);
    double towardRight(int dir) => _snap(widget.value + (widget.reversed ? -dir : dir) * widget.step);

    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: spoken,
      increasedValue: widget.semanticValue?.call(towardRight(1)) ?? _plain(towardRight(1)),
      decreasedValue: widget.semanticValue?.call(towardRight(-1)) ?? _plain(towardRight(-1)),
      onIncrease: enabled ? () => _moveRight(1) : null,
      onDecrease: enabled ? () => _moveRight(-1) : null,
      // Keys bubble up from the detector's focus node to this handler.
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: FocusableActionDetector(
          focusNode: _focus,
          enabled: enabled,
          mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onShowFocusHighlight: (v) => setState(() => _showFocus = v),
          onShowHoverHighlight: (v) => setState(() => _hover = v),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTapDown: enabled
                    ? (d) {
                        _focus.requestFocus();
                        _set(_valueAt(d.localPosition.dx, width));
                      }
                    : null,
                onTapUp: enabled ? (d) => widget.onChangeEnd?.call(widget.value) : null,
                onHorizontalDragUpdate: enabled ? (d) => _set(_valueAt(d.localPosition.dx, width)) : null,
                onHorizontalDragEnd: enabled ? (_) => widget.onChangeEnd?.call(widget.value) : null,
                child: SizedBox(
                  height: _height,
                  width: width,
                  child: CustomPaint(
                    painter: _SliderPainter(
                      colors: t.colors,
                      fraction: _fraction(widget.value),
                      band: widget.band == null ? null : (_fraction(widget.band!.start), _fraction(widget.band!.end)),
                      focused: _showFocus,
                      hovered: _hover,
                      shadow: t.shadow(0.25),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _plain(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.colors,
    required this.fraction,
    required this.band,
    required this.focused,
    required this.hovered,
    required this.shadow,
  });

  final VePalette colors;
  final double fraction;
  final (double, double)? band;
  final bool focused;
  final bool hovered;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 8.0;
    final cy = size.height / 2;
    final travel = size.width - 2 * r;
    double x(double f) => r + f * travel;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, cy - 2, size.width, 4), const Radius.circular(2)),
      Paint()..color = colors.track,
    );
    if (band != null) {
      final a = x(math.min(band!.$1, band!.$2)), b = x(math.max(band!.$1, band!.$2));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(a, cy - 4, b, cy + 4), const Radius.circular(4)),
        Paint()..color = colors.videoWire.withValues(alpha: 0.28),
      );
    }
    final c = Offset(x(fraction), cy);
    if (focused) canvas.drawCircle(c, r + 3, Paint()..color = shadow);
    canvas.drawCircle(c, r, Paint()..color = colors.surface);
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = hovered ? colors.inkHover : colors.ink,
    );
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.colors != colors ||
      old.fraction != fraction ||
      old.band != band ||
      old.focused != focused ||
      old.hovered != hovered;
}

/// A labelled mark on a quality scale, from the encoder profile.
@immutable
class VeQualityMark {
  const VeQualityMark(this.value, this.name);
  final int value;

  /// "Visually lossless", "FFmpeg default".
  final String name;
}

/// The quality scale of one encoder's rate-control mode (from encoder profiles,
/// through the core).
@immutable
class VeQualityScale {
  const VeQualityScale({
    required this.unit,
    required this.min,
    required this.max,
    required this.lowerIsBetter,
    required this.marks,
    this.recommended,
  });

  /// "CRF", "CQ", "QP".
  final String unit;
  final int min;
  final int max;
  final bool lowerIsBetter;
  final List<VeQualityMark> marks;

  /// Recommended band for the delivered resolution, when the profile has one.
  final VeRange? recommended;

  /// "CRF 18, visually lossless" or "CRF 17, near visually lossless".
  ({String value, String meaning}) describe(int v) {
    if (marks.isEmpty) return (value: '$unit $v', meaning: '');
    var best = marks.first;
    for (final m in marks) {
      if ((m.value - v).abs() < (best.value - v).abs()) best = m;
    }
    final near = best.value == v ? '' : 'near ';
    return (value: '$unit $v', meaning: ', $near${best.name.toLowerCase()}');
  }
}

/// `QualityControl` (UI_SPEC §11): slider, numeric field and labelled marks.
/// Right is higher quality whatever the scale's direction.
class VeQualityControl extends StatelessWidget {
  const VeQualityControl({
    super.key,
    required this.scale,
    required this.value,
    required this.onChanged,
    this.label = 'Quality',
    this.smallerLabel = 'Smaller file',
    this.higherLabel = 'Higher quality',
  });

  final VeQualityScale scale;
  final int value;
  final ValueChanged<int>? onChanged;
  final String label;
  final String smallerLabel;
  final String higherLabel;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final d = scale.describe(value);
    return VeField(
      label: label,
      readout: VeReadout(value: d.value, meaning: d.meaning),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VeSlider(
                  value: value.toDouble(),
                  min: scale.min.toDouble(),
                  max: scale.max.toDouble(),
                  reversed: scale.lowerIsBetter,
                  band: scale.recommended,
                  onChanged: onChanged == null ? null : (v) => onChanged!(v.round()),
                  semanticLabel: '$label, ${scale.unit}. Right is higher quality',
                  semanticValue: (v) {
                    final s = scale.describe(v.round());
                    return '${s.value}${s.meaning}';
                  },
                ),
                SizedBox(
                  height: 18,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final travel = box.maxWidth - 16;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final m in scale.marks)
                            Positioned(
                              left: 8 + travel * _fraction(m.value) - 20,
                              width: 40,
                              top: 0,
                              child: ExcludeSemantics(
                                child: Column(
                                  children: [
                                    Container(width: 1, height: 4, color: c.faint),
                                    Text(
                                      '${m.value}',
                                      textAlign: TextAlign.center,
                                      style: t.text.caption.copyWith(
                                        height: 14 / 12,
                                        color: m.value == value ? c.ink : c.faintText,
                                        fontWeight: FontWeight(m.value == value ? 600 : 400),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 2),
                VeSliderEnds(left: smallerLabel, right: higherLabel),
              ],
            ),
          ),
          const SizedBox(width: 12),
          VeNumberField(
            value: value,
            width: 68,
            semanticLabel: '${scale.unit} value',
            onChanged: onChanged == null
                ? null
                : (v) {
                    if (v != null && v >= scale.min && v <= scale.max) onChanged!(v.round());
                  },
          ),
        ],
      ),
    );
  }

  double _fraction(int v) {
    final t = (v - scale.min) / (scale.max - scale.min);
    return scale.lowerIsBetter ? 1 - t : t;
  }
}

/// `.ends`: what the two ends of a slider mean.
class VeSliderEnds extends StatelessWidget {
  const VeSliderEnds({super.key, required this.left, required this.right});
  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final style = t.text.caption.copyWith(color: t.colors.muted);
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: style),
          Text(right, style: style),
        ],
      ),
    );
  }
}
