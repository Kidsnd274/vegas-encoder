import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Where each recipe field's control is, so "Show setting" can scroll to it
/// and focus it (UI_SPEC §2: "Clicking a summary item focuses its field").
class FieldAnchors {
  final Map<String, FocusNode> _nodes = {};

  /// The fields of the control under the pointer or holding focus; the
  /// command lights their tokens (UI_SPEC §2, Command preview).
  final ValueNotifier<List<String>?> active = ValueNotifier(null);

  void _register(Iterable<String> fields, FocusNode node) {
    for (final f in fields) {
      _nodes[f] = node;
    }
  }

  void _unregister(FocusNode node) => _nodes.removeWhere((_, n) => identical(n, node));

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    active.dispose();
  }

  /// Clears the lit fields if they are still [fields].
  void _release(List<String> fields) {
    if (!_disposed && listEquals(active.value, fields)) active.value = null;
  }

  /// Scrolls the control for [field] into view and focuses its first
  /// focusable part. False when no shown control has that field.
  bool reveal(String field) {
    final node = _nodes[field] ?? _nodes[field.split('.').first];
    final context = node?.context;
    if (node == null || context == null || !context.mounted) return false;
    Scrollable.ensureVisible(context, alignment: 0.2);
    final target = node.descendants.where((n) => n.canRequestFocus && !n.skipTraversal).firstOrNull;
    (target ?? node).requestFocus();
    return true;
  }
}

/// Makes [FieldAnchors] available to the panels below it.
class FieldAnchorScope extends InheritedWidget {
  const FieldAnchorScope({super.key, required this.anchors, required super.child});
  final FieldAnchors anchors;

  static FieldAnchors? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FieldAnchorScope>()?.anchors;

  @override
  bool updateShouldNotify(FieldAnchorScope old) => !identical(old.anchors, anchors);
}

/// Marks [child] as the control for [fields] (the core's field paths).
class FieldAnchor extends StatefulWidget {
  const FieldAnchor({super.key, required this.fields, required this.child});
  final List<String> fields;
  final Widget child;

  @override
  State<FieldAnchor> createState() => _FieldAnchorState();
}

class _FieldAnchorState extends State<FieldAnchor> {
  final FocusNode _node = FocusNode(debugLabel: 'field anchor', skipTraversal: true, canRequestFocus: false);
  FieldAnchors? _anchors;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final anchors = FieldAnchorScope.maybeOf(context);
    if (!identical(anchors, _anchors)) {
      _anchors?._unregister(_node);
      _anchors = anchors;
      anchors?._register(widget.fields, _node);
    }
  }

  @override
  void didUpdateWidget(FieldAnchor old) {
    super.didUpdateWidget(old);
    _anchors?._unregister(_node);
    _anchors?._register(widget.fields, _node);
  }

  @override
  void dispose() {
    // After the frame: the tree is locked while widgets are disposed.
    final anchors = _anchors, fields = widget.fields;
    if (anchors != null) WidgetsBinding.instance.addPostFrameCallback((_) => anchors._release(fields));
    _anchors?._unregister(_node);
    _node.dispose();
    super.dispose();
  }

  void _activate(bool on) {
    final anchors = _anchors;
    if (anchors == null) return;
    if (on) {
      anchors.active.value = widget.fields;
    } else {
      anchors._release(widget.fields);
    }
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _activate(true),
    onExit: (_) => _activate(_node.hasFocus),
    child: Focus(focusNode: _node, onFocusChange: _activate, child: widget.child),
  );
}
