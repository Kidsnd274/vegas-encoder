import 'package:flutter/widgets.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/button.dart';
import '../../design/components/dialog.dart';
import '../../design/tokens.dart';
import 'display.dart';

/// "Show changes" (UI_SPEC §4): the template's own changes from its origin
/// revision, from the core's diff.
Future<void> showTemplateChanges(
  BuildContext context, {
  required String originName,
  required int revision,
  required List<FieldDiff> changes,
  required ProfileCatalog catalog,
  required Recipe recipe,
}) => showVeDialog<void>(
  context,
  title: 'Changes in this template',
  message: 'What this template changed from “$originName”, revision $revision.',
  width: 520,
  content: DiffTable(
    changes: changes,
    before: 'Rev. $revision',
    after: 'This template',
    catalog: catalog,
    recipe: recipe,
  ),
  actions: const [VeDialogAction('Close', null, variant: VeButtonVariant.primary)],
);

/// What Update from library does.
enum LibraryUpdate { replace, merge }

/// Update from library (UI_SPEC §4): what the library changed since the
/// template's revision (what you get) and the template's own changes (what
/// Replace loses). "Take library changes, keep mine" only when no setting is
/// in both lists. Without a copy of the template's revision there is no
/// three-way choice: [fromLibrary] lists how the template differs from the
/// library now, and only Replace is offered.
Future<LibraryUpdate?> showUpdateFromLibrary(
  BuildContext context, {
  required int revision,
  required int libraryRevision,
  required ProfileCatalog catalog,
  required Recipe recipe,
  List<FieldDiff>? since,
  List<FieldDiff>? mine,
  List<FieldDiff>? fromLibrary,
  required bool canMerge,
}) {
  final t = VeTokens.of(context);
  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 2),
    child: Text(
      text,
      style: t.text.small.copyWith(color: t.colors.warningText, fontWeight: const FontWeight(600)),
    ),
  );
  final threeWay = since != null;
  return showVeDialog<LibraryUpdate?>(
    context,
    title: 'Update from library',
    message: threeWay
        ? null
        : 'This template doesn’t carry a copy of revision $revision, so its own changes can’t be told apart '
              'from the library’s. Replacing takes all of revision $libraryRevision.',
    width: 520,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: threeWay
          ? [
              heading('Changes in the library since revision $revision'),
              DiffTable(
                changes: since,
                before: 'Rev. $revision',
                after: 'Rev. $libraryRevision',
                catalog: catalog,
                recipe: recipe,
              ),
              heading('Your changes in this template'),
              if (mine == null || mine.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('None.', style: t.text.small.copyWith(color: t.colors.muted)),
                )
              else
                DiffTable(
                  changes: mine,
                  before: 'Rev. $revision',
                  after: 'This template',
                  catalog: catalog,
                  recipe: recipe,
                ),
            ]
          : [
              heading('This template and revision $libraryRevision'),
              DiffTable(
                changes: fromLibrary ?? const [],
                before: 'This template',
                after: 'Rev. $libraryRevision',
                catalog: catalog,
                recipe: recipe,
              ),
            ],
    ),
    actions: [
      const VeDialogAction('Cancel', null),
      if (threeWay)
        VeDialogAction(
          'Take library changes, keep mine',
          LibraryUpdate.merge,
          enabled: canMerge,
          tooltip: canMerge ? null : 'Some settings changed in both places.',
        ),
      VeDialogAction('Replace with revision $libraryRevision', LibraryUpdate.replace, variant: VeButtonVariant.primary),
    ],
  );
}

/// `.dtab`: one row per setting the core's diff names, before and after.
class DiffTable extends StatelessWidget {
  const DiffTable({
    super.key,
    required this.changes,
    required this.before,
    required this.after,
    required this.catalog,
    required this.recipe,
  });

  final List<FieldDiff> changes;
  final String before;
  final String after;
  final ProfileCatalog catalog;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final head = t.text.caption.copyWith(color: c.muted);
    final cell = t.text.small;
    TableRow row(List<Widget> cells, {bool top = true}) => TableRow(
      decoration: top
          ? BoxDecoration(
              border: Border(top: BorderSide(color: c.line)),
            )
          : null,
      children: [for (final w in cells) Padding(padding: const EdgeInsets.fromLTRB(0, 5, 8, 5), child: w)],
    );
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.25), 1: FlexColumnWidth(), 2: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        row([Text('Setting', style: head), Text(before, style: head), Text(after, style: head)], top: false),
        for (final d in changes)
          row([
            Text(fieldLabel(d.path), style: cell.copyWith(color: c.muted)),
            Text(fieldValue(d.path, d.before, catalog, recipe), style: cell),
            Text(fieldValue(d.path, d.after, catalog, recipe), style: cell.copyWith(fontWeight: const FontWeight(650))),
          ]),
      ],
    );
  }
}
