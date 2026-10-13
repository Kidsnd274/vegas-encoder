import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/button.dart';
import '../../design/components/interactive.dart';
import '../../design/components/segmented.dart';
import '../../design/format.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/history.dart';
import '../../state/services.dart';
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

/// The list's columns. Below [compactWidth] the length and time-taken columns
/// give way to the template; the detail still has both.
enum JobColumn {
  status('Status', 104),
  started('Started', 104),
  template('Template and project', null),
  encoder('Encoder', 104),
  length('Length', 60, end: true),
  took('Took', 60, end: true),
  speed('Speed', 60, end: true),
  size('Size', 76, end: true);

  const JobColumn(this.label, this.width, {this.end = false});
  final String label;

  /// Null shares the remaining width.
  final double? width;

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

/// One render (`.ctab tr.r`): the index line, filled in from its record as
/// that loads.
class JobRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final record = ref.watch(jobRecordProvider(entry.id));
    final r = record.value;
    final outcome = JobOutcome.of(entry.status);
    final figure = t.text.small.copyWith(color: c.ink);
    final quiet = t.text.small.copyWith(color: c.muted);

    Widget text(String? value, {TextStyle? style}) => Text(
      value ?? '–',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: value == null ? quiet : (style ?? figure),
    );

    final ratio = r == null ? null : realtimeRatio(r);
    final length = r?.media.durationSec;
    // A failed read stays an error while Riverpod retries it (a loading value
    // that still carries the error), so ask hasError rather than the type.
    final second = r != null
        ? r.project
        : record.hasError
        ? 'The record couldn’t be read'
        : record.hasValue
        ? 'The record is missing'
        : '';
    final recordProblem = r == null && (record.hasError || record.hasValue);

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
            second,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.caption.copyWith(color: recordProblem ? c.error : c.muted),
          ),
        ],
      ),
      JobColumn.encoder => text(r == null ? null : encoderLabel(r, ref.watch(profilesProvider))),
      JobColumn.length => text(length == null ? null : VeFormat.duration(length)),
      JobColumn.took => text(r == null ? null : VeFormat.duration(r.elapsedSec)),
      JobColumn.speed => text(ratio == null ? null : ratioLabel(ratio)),
      JobColumn.size => text(r == null ? null : sizeLabel(r), style: r != null && !r.published ? quiet : null),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: [
        outcome.label,
        entry.templateName,
        if (second.isNotEmpty) second,
        jobTime(entry.startedAt, year: true),
      ].join(', '),
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
