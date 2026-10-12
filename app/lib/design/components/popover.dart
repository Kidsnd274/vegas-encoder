import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// Opens [contentBuilder] in a popover under (or, without room, over) the
/// anchor (`.pop`). A click outside or Esc closes it; focus returns to the
/// anchor.
class VePopover extends StatefulWidget {
  const VePopover({
    super.key,
    required this.anchorBuilder,
    required this.contentBuilder,
    this.width,
    this.maxHeight = 470,
    this.onOpenChanged,
  });

  /// Builds the anchor; call `toggle` to open or close.
  final Widget Function(BuildContext context, bool open, VoidCallback toggle) anchorBuilder;

  /// Builds the popover content; call `close` when a choice is made.
  final Widget Function(BuildContext context, VoidCallback close) contentBuilder;

  /// Popover width; defaults to the anchor's width (at least 300).
  final double? width;
  final double maxHeight;
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<VePopover> createState() => _VePopoverState();
}

class _VePopoverState extends State<VePopover> {
  final OverlayPortalController _portal = OverlayPortalController();
  final GlobalKey _anchorKey = GlobalKey();
  final FocusScopeNode _anchorScope = FocusScopeNode(debugLabel: 'popover anchor');
  FocusNode? _returnFocus;

  @override
  void dispose() {
    _anchorScope.dispose();
    super.dispose();
  }

  void _open() {
    _returnFocus = FocusManager.instance.primaryFocus;
    _portal.show();
    setState(() {});
    widget.onOpenChanged?.call(true);
  }

  void _close() {
    if (!_portal.isShowing) return;
    _portal.hide();
    if (mounted) setState(() {});
    widget.onOpenChanged?.call(false);
    final back = _returnFocus;
    if (back != null && back.context != null && back.context!.mounted) back.requestFocus();
  }

  void _toggle() => _portal.isShowing ? _close() : _open();

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: this,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (overlayContext) {
          final anchor = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
          final overlay = Overlay.of(overlayContext).context.findRenderObject() as RenderBox?;
          if (anchor == null || overlay == null || !anchor.attached) return const SizedBox.shrink();
          final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
          final anchorRect = topLeft & anchor.size;
          final width = widget.width ?? math.max(300.0, anchor.size.width);
          return CustomSingleChildLayout(
            delegate: _PopoverLayout(anchorRect, width),
            child: TapRegion(
              groupId: this,
              onTapOutside: (_) => _close(),
              child: Shortcuts(
                shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
                child: Actions(
                  actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => _close())},
                  child: _PopoverBox(maxHeight: widget.maxHeight, child: widget.contentBuilder(overlayContext, _close)),
                ),
              ),
            ),
          );
        },
        child: KeyedSubtree(key: _anchorKey, child: widget.anchorBuilder(context, _portal.isShowing, _toggle)),
      ),
    );
  }
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  _PopoverLayout(this.anchor, this.width);
  final Rect anchor;
  final double width;

  static const double _gap = 6;
  static const double _margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final below = constraints.maxHeight - anchor.bottom - _gap - _margin;
    final above = anchor.top - _gap - _margin;
    return BoxConstraints(minWidth: width, maxWidth: width, maxHeight: math.max(120, math.max(below, above)));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = anchor.left;
    if (x + childSize.width > size.width - _margin) x = size.width - _margin - childSize.width;
    x = math.max(_margin, x);
    var y = anchor.bottom + _gap;
    if (y + childSize.height > size.height - _margin) {
      final aboveY = anchor.top - _gap - childSize.height;
      y = aboveY >= _margin ? aboveY : math.max(_margin, size.height - _margin - childSize.height);
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PopoverLayout old) => old.anchor != anchor || old.width != width;
}

class _PopoverBox extends StatelessWidget {
  const _PopoverBox({required this.child, required this.maxHeight});
  final Widget child;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          color: t.colors.surface,
          border: Border.all(color: t.colors.line2),
          borderRadius: BorderRadius.circular(9),
          boxShadow: t.popoverShadow,
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
      ),
    );
  }
}

/// One choice in a [VeListbox].
@immutable
class VeOption<T> {
  const VeOption(this.value, this.label, {this.detail, this.trailing, this.enabled = true});
  final T value;
  final String label;

  /// Second line ("H.264, NVIDIA GPU, 10-bit").
  final String? detail;

  /// Right side, such as an availability tag.
  final Widget? trailing;

  /// Disabled choices stay visible (`aria-disabled`), at reduced opacity.
  final bool enabled;
}

@immutable
class VeOptionGroup<T> {
  const VeOptionGroup(this.options, {this.header});
  final String? header;
  final List<VeOption<T>> options;
}

/// The listbox inside a popover: grouped options, keyboard and pointer
/// selection, an optional footnote (`.pnote`).
class VeListbox<T> extends StatefulWidget {
  const VeListbox({
    super.key,
    required this.groups,
    required this.selected,
    required this.onPick,
    required this.onClose,
    required this.semanticLabel,
    this.footnote,
  });

  final List<VeOptionGroup<T>> groups;
  final T? selected;
  final ValueChanged<T> onPick;
  final VoidCallback onClose;
  final String semanticLabel;
  final String? footnote;

  @override
  State<VeListbox<T>> createState() => _VeListboxState<T>();
}

class _VeListboxState<T> extends State<VeListbox<T>> {
  final FocusNode _focus = FocusNode(debugLabel: 'listbox');
  late final List<VeOption<T>> _flat = [for (final g in widget.groups) ...g.options];
  late final List<GlobalKey> _keys = List.generate(_flat.length, (_) => GlobalKey());
  late int _active;

  @override
  void initState() {
    super.initState();
    final sel = _flat.indexWhere((o) => o.value == widget.selected && o.enabled);
    _active = sel >= 0 ? sel : _flat.indexWhere((o) => o.enabled);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _reveal();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _reveal() {
    if (_active < 0) return;
    final ctx = _keys[_active].currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
    if (ctx != null) Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
  }

  void _move(int dir) {
    var i = _active;
    for (var n = 0; n < _flat.length; n++) {
      i = (i + dir).clamp(0, _flat.length - 1);
      if (_flat[i].enabled) break;
    }
    if (_flat[i].enabled) {
      setState(() => _active = i);
      _reveal();
    }
  }

  void _pick(int i) {
    if (i < 0 || !_flat[i].enabled) return;
    widget.onClose();
    widget.onPick(_flat[i].value);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _move(-1);
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space) {
      _pick(_active);
    } else if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.tab) {
      widget.onClose();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final children = <Widget>[];
    var index = 0;
    for (final g in widget.groups) {
      if (g.header != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 3),
            child: Semantics(
              header: true,
              child: Text(g.header!, style: t.text.captionStrong.copyWith(color: c.muted)),
            ),
          ),
        );
      }
      for (final o in g.options) {
        final i = index++;
        children.add(
          _OptionRow<T>(
            key: _keys[i],
            option: o,
            active: i == _active,
            selected: o.value == widget.selected,
            onHover: () {
              if (o.enabled && _active != i) setState(() => _active = i);
            },
            onTap: () => _pick(i),
          ),
        );
      }
    }
    if (widget.footnote != null) {
      children.add(
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: Text(widget.footnote!, style: t.text.caption.copyWith(color: c.muted)),
        ),
      );
    }
    return Semantics(
      label: widget.semanticLabel,
      container: true,
      explicitChildNodes: true,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.option,
    required this.active,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });

  final VeOption<T> option;
  final bool active;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final row = Container(
      color: active ? c.fillSelected : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: t.text.bodyStrong.copyWith(height: 1.35),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (option.detail != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        option.detail!,
                        style: t.text.caption.copyWith(color: c.muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (option.trailing != null) ...[const SizedBox(width: 14), option.trailing!],
        ],
      ),
    );
    // One node per option: its label, the trailing tag's words, and the tap.
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        enabled: option.enabled,
        button: true,
        label: option.detail == null ? option.label : '${option.label}, ${option.detail}',
        child: MouseRegion(
          cursor: option.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => onHover(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: option.enabled ? onTap : null,
            child: Opacity(
              opacity: option.enabled ? 1 : 0.55,
              child: Stack(
                children: [
                  row,
                  if (selected)
                    Positioned(
                      left: 0,
                      top: 6,
                      bottom: 6,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: c.ink,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
