import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'interactive.dart';

@immutable
class VeSegment<T> {
  const VeSegment(this.value, this.label);
  final T value;
  final String label;
}

/// `.seg`: one choice from a few (Basic | Advanced, rate control, bit depth).
/// Arrow keys move the choice, like a radio group.
class VeSegmented<T> extends StatefulWidget {
  const VeSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
    this.expand = false,
  });

  final List<VeSegment<T>> segments;
  final T? selected;
  final ValueChanged<T>? onChanged;

  /// Names the group for screen readers ("Editing mode", "Rate control").
  final String semanticLabel;

  /// `.seg.full`: segments share the width equally.
  final bool expand;

  @override
  State<VeSegmented<T>> createState() => _VeSegmentedState<T>();
}

class _VeSegmentedState<T> extends State<VeSegmented<T>> {
  late List<FocusNode> _nodes = _makeNodes();

  List<FocusNode> _makeNodes() => List.generate(widget.segments.length, (i) => FocusNode(debugLabel: 'segment $i'));

  @override
  void didUpdateWidget(VeSegmented<T> old) {
    super.didUpdateWidget(old);
    if (old.segments.length != widget.segments.length) {
      for (final n in _nodes) {
        n.dispose();
      }
      _nodes = _makeNodes();
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowUp => -1,
      _ => 0,
    };
    if (delta == 0 || widget.onChanged == null) return KeyEventResult.ignored;
    final next = (index + delta).clamp(0, widget.segments.length - 1);
    if (next != index) {
      _nodes[next].requestFocus();
      widget.onChanged!(widget.segments[next].value);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final children = <Widget>[];
    for (var i = 0; i < widget.segments.length; i++) {
      final seg = widget.segments[i];
      final on = seg.value == widget.selected;
      Widget button = Semantics(
        inMutuallyExclusiveGroup: true,
        checked: on,
        button: true,
        label: seg.label,
        child: VeInteractive(
          focusNode: _nodes[i],
          enabled: widget.onChanged != null,
          onTap: () => widget.onChanged?.call(seg.value),
          onKeyEvent: (_, e) => _onKey(i, e),
          builder: (context, s) => VeFocusRing(
            visible: s.focused,
            radius: VeRadius.sm,
            child: AnimatedContainer(
              duration: VeTokens.motion(context, const Duration(milliseconds: 120)),
              height: 28,
              padding: EdgeInsets.symmetric(horizontal: widget.expand ? 6 : 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? c.surface : c.surface.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(VeRadius.sm),
                boxShadow: on ? t.segmentShadow : const [],
              ),
              child: Text(
                seg.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: t.text.body.copyWith(
                  height: 1.2,
                  color: on || s.hovered ? c.ink : c.text2,
                  fontWeight: FontWeight(on ? 600 : 400),
                ),
              ),
            ),
          ),
        ),
      );
      if (widget.expand) button = Expanded(child: button);
      if (i > 0) children.add(const SizedBox(width: 2));
      children.add(button);
    }
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(7)),
        child: Row(mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min, children: children),
      ),
    );
  }
}
