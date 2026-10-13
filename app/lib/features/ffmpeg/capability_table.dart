import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../design/components/interactive.dart';
import '../../design/components/status.dart';
import '../../design/tokens.dart';
import 'display.dart';

/// `.ctab`: what an installation can encode, grouped by codec. Rows are
/// focusable; focusing one selects it, and Up and Down move between rows.
class CapabilityTable extends StatelessWidget {
  const CapabilityTable({
    super.key,
    required this.groups,
    required this.selectedId,
    required this.onSelect,
    required this.video,
    required this.emptyText,
  });

  final List<CapabilityGroup> groups;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final bool video;
  final String emptyText;

  /// Narrower than this, the FFmpeg name and reason columns give way; the
  /// detail panel still shows both.
  static const double compactBelow = 760;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => _build(context, _Layout(compact: box.maxWidth < compactBelow, video: video)),
  );

  Widget _build(BuildContext context, _Layout layout) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final rows = [for (final g in groups) ...g.rows];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 33,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: DefaultTextStyle(
            style: t.text.caption.copyWith(color: c.muted, fontWeight: const FontWeight(500)),
            child: _Columns(
              layout: layout,
              group: const Text('Codec'),
              encoder: const Text('Encoder'),
              name: const Text('FFmpeg name'),
              depth: const Text('Bit depth'),
              runsOn: const Text('Runs on'),
              state: const Text('State'),
              why: const Text('Reason'),
            ),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(emptyText, style: t.text.body.copyWith(color: c.muted)),
                )
              : FocusTraversalGroup(
                  child: ListView(
                    children: [
                      for (final g in groups)
                        Container(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: c.lineSoft)),
                          ),
                          child: Stack(
                            children: [
                              Column(
                                children: [
                                  for (final r in g.rows)
                                    _Row(
                                      row: r,
                                      layout: layout,
                                      selected: r.id == selectedId,
                                      first: identical(r, rows.first),
                                      last: identical(r, rows.last),
                                      onSelect: () => onSelect(r.id),
                                    ),
                                ],
                              ),
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: layout.groupWidth,
                                child: IgnorePointer(
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(10, 11, 10, 0),
                                    decoration: BoxDecoration(
                                      color: c.surface,
                                      border: Border(right: BorderSide(color: c.lineSoft)),
                                    ),
                                    child: Text(g.name, style: t.text.bodyStrong),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Which columns show, and the codec column's width.
@immutable
class _Layout {
  const _Layout({required this.compact, required this.video});
  final bool compact;
  final bool video;
  double get groupWidth => compact ? 96 : 120;
}

/// The table's column widths, shared by the header and the rows.
class _Columns extends StatelessWidget {
  const _Columns({
    required this.layout,
    required this.group,
    required this.encoder,
    required this.name,
    required this.depth,
    required this.runsOn,
    required this.state,
    required this.why,
  });

  final _Layout layout;
  final Widget group, encoder, name, depth, runsOn, state, why;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: layout.groupWidth - 10, child: group),
      const SizedBox(width: 10),
      Expanded(flex: 5, child: encoder),
      if (!layout.compact) Expanded(flex: 4, child: name),
      if (layout.video) SizedBox(width: 88, child: depth),
      Expanded(flex: 6, child: runsOn),
      SizedBox(width: 156, child: state),
      if (!layout.compact) Expanded(flex: 6, child: why),
    ],
  );
}

class _Row extends StatefulWidget {
  const _Row({
    required this.row,
    required this.layout,
    required this.selected,
    required this.first,
    required this.last,
    required this.onSelect,
  });

  final CapabilityRow row;
  final _Layout layout;
  final bool selected;
  final bool first;
  final bool last;
  final VoidCallback onSelect;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  // A click focuses the row too, so arrow keys carry on from it.
  final FocusNode _focus = FocusNode(debugLabel: 'capability row');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final r = widget.row;
    final selected = widget.selected;
    final layout = widget.layout;
    final muted = t.text.small.copyWith(color: c.muted);
    Widget cell(String text, TextStyle style) =>
        Text(text, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis);

    return Semantics(
      button: true,
      selected: selected,
      label: '${r.label}, ${r.id}, ${r.status.state.label}${r.why.isEmpty ? '' : ', ${r.why}'}',
      child: VeInteractive(
        focusNode: _focus,
        onTap: () {
          _focus.requestFocus();
          widget.onSelect();
        },
        onFocusChange: (focused) {
          if (focused && !widget.selected) widget.onSelect();
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowDown && !widget.last) {
            node.nextFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp && !widget.first) {
            node.previousFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        builder: (context, s) {
          final fill = selected ? c.fillSelected : (s.hovered ? c.fillHover : null);
          return Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: fill,
            foregroundDecoration: s.focused ? BoxDecoration(border: Border.all(color: c.focus, width: 2)) : null,
            child: _Columns(
              layout: layout,
              group: const SizedBox.shrink(),
              encoder: Container(
                height: 38,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 10, right: 8),
                decoration: selected
                    ? BoxDecoration(
                        border: Border(left: BorderSide(color: c.ink, width: 3)),
                      )
                    : null,
                child: cell(r.label, t.text.bodyStrong),
              ),
              name: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: cell(r.id, t.text.monoSmall.copyWith(color: c.muted)),
              ),
              depth: cell(r.depth, t.text.body),
              runsOn: Padding(padding: const EdgeInsets.only(right: 8), child: cell(r.runsOn, t.text.body)),
              state: Align(alignment: Alignment.centerLeft, child: VeStatusTag(r.status.state)),
              why: Text(r.why, style: muted, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          );
        },
      ),
    );
  }
}
