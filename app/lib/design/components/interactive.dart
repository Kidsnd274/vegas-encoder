import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// What a control looks like right now.
@immutable
class VeControlState {
  const VeControlState({required this.hovered, required this.focused, required this.pressed, required this.enabled});

  final bool hovered;

  /// Keyboard focus that should show a ring (`:focus-visible`), not any focus.
  final bool focused;
  final bool pressed;
  final bool enabled;
}

/// Hover, keyboard focus, press and Enter/Space activation for a custom
/// control. The builder draws the control for each state.
class VeInteractive extends StatefulWidget {
  const VeInteractive({
    super.key,
    required this.builder,
    this.onTap,
    this.onDoubleTap,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.cursor,
    this.onKeyEvent,
    this.onFocusChange,
    this.onHoverChange,
    this.excludeChildSemantics = true,
  });

  final Widget Function(BuildContext context, VeControlState state) builder;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool canRequestFocus;
  final MouseCursor? cursor;
  final FocusOnKeyEventCallback? onKeyEvent;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<bool>? onHoverChange;

  /// Hide the drawn content from screen readers; wrap the control in
  /// [Semantics] with its role and label instead.
  final bool excludeChildSemantics;

  @override
  State<VeInteractive> createState() => _VeInteractiveState();
}

class _VeInteractiveState extends State<VeInteractive> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _active => widget.enabled && widget.onTap != null;

  void _activate() {
    if (_active) widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    // The control's own semantics (button, label) come from the caller; the
    // drawn content is excluded so labels are not read twice, while tap and
    // focus actions from the detectors below stay available.
    final visual = ExcludeSemantics(
      excluding: widget.excludeChildSemantics,
      child: widget.builder(
        context,
        VeControlState(hovered: _hovered && _active, focused: _focused, pressed: _pressed, enabled: widget.enabled),
      ),
    );
    Widget detector = FocusableActionDetector(
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      descendantsAreFocusable: true,
      mouseCursor: widget.cursor ?? (_active ? SystemMouseCursors.click : SystemMouseCursors.basic),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) {
        setState(() => _hovered = v);
        widget.onHoverChange?.call(v);
      },
      onFocusChange: widget.onFocusChange,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _active ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _active ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _active ? () => setState(() => _pressed = false) : null,
        onTap: _active
            ? () {
                if (widget.canRequestFocus && widget.focusNode != null) widget.focusNode!.requestFocus();
                _activate();
              }
            : null,
        onDoubleTap: widget.enabled ? widget.onDoubleTap : null,
        child: visual,
      ),
    );
    // Key events bubble from the focused node to its ancestors, so the
    // handler must sit above the detector's focus node.
    if (widget.onKeyEvent != null) {
      detector = Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: widget.onKeyEvent, child: detector);
    }
    return ExcludeFocus(excluding: !widget.canRequestFocus, child: detector);
  }
}

/// `:focus-visible{outline:2px solid var(--ink);outline-offset:2px}`, drawn
/// outside the child's bounds.
class VeFocusRing extends StatelessWidget {
  const VeFocusRing({
    super.key,
    required this.visible,
    required this.child,
    this.radius = VeRadius.md,
    this.offset = 2,
    this.shape = BoxShape.rectangle,
  });

  final bool visible;
  final Widget child;
  final double radius;
  final double offset;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    // Same tree with or without the ring: a changing parent would remount the
    // child (and drop a text field's input connection) when focus arrives.
    return CustomPaint(
      foregroundPainter: visible ? _RingPainter(VeTokens.of(context).colors.focus, radius, offset, shape) : null,
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.color, this.radius, this.offset, this.shape);
  final Color color;
  final double radius;
  final double offset;
  final BoxShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    final grow = offset + 1;
    final rect = (Offset.zero & size).inflate(grow);
    if (shape == BoxShape.circle) {
      canvas.drawOval(rect, paint);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius + grow)), paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color || old.radius != radius || old.offset != offset || old.shape != shape;
}

/// A rounded border drawn with dashes (`border-style:dashed`).
class DashedRRectPainter extends CustomPainter {
  DashedRRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1,
    this.dash = 4,
    this.gap = 3,
    this.fill,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius((Offset.zero & size).deflate(strokeWidth / 2), Radius.circular(radius));
    if (fill != null) canvas.drawRRect(rrect, Paint()..color = fill!);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter old) =>
      old.color != color || old.radius != radius || old.strokeWidth != strokeWidth || old.fill != fill;
}

/// Applies `opacity:.45` to disabled controls, like the mockup's `:disabled`.
class VeDisabled extends StatelessWidget {
  const VeDisabled({super.key, required this.disabled, required this.child, this.opacity = 0.45});
  final bool disabled;
  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) => Opacity(opacity: disabled ? opacity : 1, child: child);
}
