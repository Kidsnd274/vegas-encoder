import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/button.dart';
import '../../design/components/interactive.dart';
import '../../design/components/segmented.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/history.dart';
import 'display.dart';

/// Status as an icon and a word, coloured; never colour alone.
class JobStatus extends StatelessWidget {
  const JobStatus(this.outcome, {super.key});
  final JobOutcome outcome;

  static VeIconData iconOf(JobOutcome o) => switch (o) {
    JobOutcome.succeeded => VeIcons.check,
    JobOutcome.failed => VeIcons.error,
    JobOutcome.cancelled => VeIcons.dash,
    JobOutcome.other => VeIcons.info,
  };

  static Color colorOf(VePalette c, JobOutcome o) => switch (o) {
    JobOutcome.succeeded => c.success,
    JobOutcome.failed => c.error,
    JobOutcome.cancelled || JobOutcome.other => c.muted,
  };

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final color = colorOf(t.colors, outcome);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VeIcon(iconOf(outcome), color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            outcome.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.small.copyWith(color: color, fontWeight: const FontWeight(550)),
          ),
        ),
      ],
    );
  }
}

/// The list's columns, all from the index (C6 `jobs.jsonl`). Below
/// [compactWidth] the length and time-taken columns give way; the detail
/// still has both. Speed (× realtime) shows in the detail only: the index
/// has no realtime figure (workstreams/app.md, Needs).
enum JobColumn {
  status('Status', 104),
  started('Started', 104),
  template('Template and project', null, flex: 5),
  encoder('Encoder', null, flex: 4),
  length('Length', 60, end: true),
  took('Took', 60, end: true),
  size('Size', 76, end: true);

  const JobColumn(this.label, this.width, {this.end = false, this.flex = 1});
  final String label;

  /// Null shares the remaining width, by [flex].
  final double? width;
  final int flex;

  /// Figures align at the end.
  final bool end;
}

const double compactWidth = 860;
const double _cellPad = 8;

List<JobColumn> _columns(bool compact) =>
    JobColumn.values.where((c) => !compact || (c != JobColumn.length && c != JobColumn.took)).toList();

Widget _cells(List<JobColumn> cols, Widget Function(JobColumn c) cell) => Row(
  children: [
    const SizedBox(width: 16 - _cellPad),
    for (final c in cols)
      if (c.width == null)
        Expanded(
          flex: c.flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _cellPad),
            child: cell(c),
          ),
        )
      else
        SizedBox(
          width: c.width! + 2 * _cellPad,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _cellPad),
            child: Align(alignment: c.end ? Alignment.centerRight : Alignment.centerLeft, child: cell(c)),
          ),
        ),
    const SizedBox(width: 16 - _cellPad),
  ],
);

/// History's list (`.capl` on surface): the status filter, column headings and
/// one row per render.
class JobList extends StatelessWidget {
  const JobList({
    super.key,
    required this.all,
    required this.shown,
    required this.selectedId,
    required this.filter,
    required this.onFilter,
    required this.onSelect,
    required this.onMove,
    required this.focusFor,
  });

  final List<JobIndexEntry> all;
  final List<JobIndexEntry> shown;
  final String? selectedId;
  final HistoryFilter filter;
  final ValueChanged<HistoryFilter> onFilter;
  final ValueChanged<String> onSelect;

  /// Up (-1) or Down (+1) from the selected row.
  final ValueChanged<int> onMove;
  final FocusNode Function(String id) focusFor;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final count = filter == HistoryFilter.all
        ? '${all.length} ${all.length == 1 ? 'render' : 'renders'}'
        : '${shown.length} of ${all.length} renders';
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.line)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final cols = _columns(box.maxWidth < compactWidth);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.line)),
                ),
                child: Row(
                  children: [
                    VeSegmented<HistoryFilter>(
                      semanticLabel: 'Show renders',
                      segments: [for (final f in HistoryFilter.values) VeSegment(f, f.label)],
                      selected: filter,
                      onChanged: onFilter,
                    ),
                    const Spacer(),
                    Text(count, style: t.text.small.copyWith(color: c.muted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.line)),
                ),
                child: ExcludeSemantics(
                  child: _cells(
                    cols,
                    (col) => Text(
                      col.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: t.text.caption.copyWith(color: c.muted, fontWeight: const FontWeight(500)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? _NoMatch(filter: filter, onShowAll: () => onFilter(HistoryFilter.all))
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final e = shown[i];
                          return JobRow(
                            key: ValueKey('job-${e.id}'),
                            entry: e,
                            columns: cols,
                            selected: e.id == selectedId,
                            focusNode: focusFor(e.id),
                            onSelect: () => onSelect(e.id),
                            onMove: onMove,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One render (`.ctab tr.r`): its line in the index. The row reads no record;
/// only the selected render's detail does.
class JobRow extends StatelessWidget {
  const JobRow({
    super.key,
    required this.entry,
    required this.columns,
    required this.selected,
    required this.focusNode,
    required this.onSelect,
    required this.onMove,
  });

  final JobIndexEntry entry;
  final List<JobColumn> columns;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onSelect;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final e = entry;
    final outcome = JobOutcome.of(e.status);
    final figure = t.text.small.copyWith(color: c.ink);
    final quiet = t.text.small.copyWith(color: c.muted);

    Widget text(String? value, {TextStyle? style, String? tooltip}) {
      final label = Text(
        value ?? '–',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: value == null ? quiet : (style ?? figure),
      );
      return tooltip == null ? label : VeTooltip(message: tooltip, child: label);
    }

    final project = indexProject(e);
    final encoder = indexEncoder(e);
    final size = indexSize(e);

    Widget cell(JobColumn col) => switch (col) {
      JobColumn.status => JobStatus(outcome),
      JobColumn.started => text(jobTime(entry.startedAt)),
      JobColumn.template => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.templateName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.bodyStrong.copyWith(height: 18 / 13),
          ),
          Text(
            project ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.caption.copyWith(color: c.muted),
          ),
        ],
      ),
      JobColumn.encoder => text(encoder, tooltip: encoder),
      JobColumn.length => text(indexDuration(e.durationSec)),
      JobColumn.took => text(indexDuration(e.elapsedSec)),
      JobColumn.size => text(size, style: e.sizeBytes == 0 ? quiet : null),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: [outcome.label, e.templateName, ?project, ?encoder, jobTime(e.startedAt, year: true)].join(', '),
      child: VeInteractive(
        focusNode: focusNode,
        onTap: onSelect,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            onMove(1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            onMove(-1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        builder: (context, s) => Container(
          height: 48,
          decoration: BoxDecoration(
            color: selected ? c.fillSelected : (s.hovered ? c.fillHover : null),
            border: Border(
              bottom: BorderSide(color: c.lineSoft),
              left: BorderSide(color: selected ? c.ink : const Color(0x00000000), width: 3),
            ),
          ),
          foregroundDecoration: s.focused ? BoxDecoration(border: Border.all(color: c.ink, width: 2)) : null,
          child: Transform.translate(offset: const Offset(-3, 0), child: _cells(columns, cell)),
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.filter, required this.onShowAll});
  final HistoryFilter filter;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text('No ${filter.label.toLowerCase()} renders. ', style: t.text.body.copyWith(color: t.colors.muted)),
          VeLinkButton(label: 'Show all renders', onPressed: onShowAll, style: t.text.body),
        ],
      ),
    );
  }
}
