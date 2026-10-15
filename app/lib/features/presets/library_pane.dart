import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/button.dart';
import '../../design/components/interactive.dart';
import '../../design/components/popover.dart';
import '../../design/components/segmented.dart';
import '../../design/components/text_field.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/presets.dart';
import '../../state/services.dart';
import 'library_model.dart';

/// What the library's context menu can do with a preset (UI_SPEC §2).
enum LibraryAction { duplicate, rename, export, copyShareString, showInFolder, delete }

/// The library's add menu (+): a new preset, or one someone shared.
enum LibraryAdd { newPreset, importShareString, importFile }

/// The preset library (UI_SPEC §2, Library): search, Built-in/Mine filter,
/// favorites, and the grouped list.
class LibraryPane extends ConsumerWidget {
  const LibraryPane({
    super.key,
    required this.searchFocus,
    required this.onAction,
    required this.onFavorite,
    required this.onNewPreset,
    required this.onImportShareString,
    this.onPicked,
  });

  final FocusNode searchFocus;
  final void Function(LibraryAction action, LibraryEntry entry) onAction;

  /// The row's star.
  final ValueChanged<LibraryEntry> onFavorite;

  /// "New preset" from an empty search or the add menu.
  final VoidCallback onNewPreset;

  /// "Import share string…" from the add menu.
  final VoidCallback onImportShareString;

  /// After a preset is chosen, for the narrow layout's library overlay.
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final state = ref.watch(presetsControllerProvider);
    final controller = ref.read(presetsControllerProvider.notifier);
    final groups = groupLibrary(
      ref.watch(libraryEntriesProvider),
      query: state.query,
      filter: state.filter,
      favoritesOnly: state.favoritesOnly,
    );

    // Built lazily (ListView.builder), for libraries of hundreds of presets
    // (TECH_ARCHITECTURE §9.3).
    final rows = <Widget Function()>[];
    for (var gi = 0; gi < groups.length; gi++) {
      final g = groups[gi];
      final first = gi == 0;
      rows.add(() => _GroupHeader(title: g.title, count: g.count, first: first));
      for (final sub in g.subgroups) {
        rows.add(() => _SubHeader(sub.title));
        for (final e in sub.entries) {
          rows.add(
            () => _LibraryRow(
              key: ValueKey('preset-${e.id}'),
              entry: e,
              selected: e.id == state.selectedId,
              onSelect: () {
                controller.select(e.id);
                onPicked?.call();
              },
              onFavorite: () => onFavorite(e),
              onAction: (a) => onAction(a, e),
            ),
          );
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SearchField(focusNode: searchFocus, query: state.query, onChanged: controller.setQuery),
                    ),
                    const SizedBox(width: 6),
                    _AddMenu(
                      onPick: (a) => switch (a) {
                        LibraryAdd.newPreset => onNewPreset(),
                        LibraryAdd.importShareString => onImportShareString(),
                        LibraryAdd.importFile => null,
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: VeSegmented<LibraryFilter>(
                        semanticLabel: 'Show',
                        expand: true,
                        segments: const [
                          VeSegment(LibraryFilter.all, 'All'),
                          VeSegment(LibraryFilter.builtin, 'Built-in'),
                          VeSegment(LibraryFilter.mine, 'Mine'),
                        ],
                        selected: state.filter,
                        onChanged: controller.setFilter,
                      ),
                    ),
                    const SizedBox(width: 6),
                    VeIconButton(
                      icon: VeIcons.star,
                      selectedIcon: VeIcons.starFilled,
                      label: 'Favorites only',
                      selected: state.favoritesOnly,
                      selectedColor: c.favorite,
                      selectedBackground: c.favoriteBackground,
                      bordered: true,
                      onPressed: controller.toggleFavoritesOnly,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: !ref.watch(presetsProvider).hasValue
                ? const SizedBox.shrink()
                : rows.isEmpty
                ? _NoMatch(query: state.query, onClear: controller.showAll, onNewPreset: onNewPreset)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => rows[i](),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.focusNode, required this.query, required this.onChanged});
  final FocusNode focusNode;
  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _text = TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(_SearchField old) {
    super.didUpdateWidget(old);
    if (widget.query != _text.text) _text.text = widget.query;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VeTextField(
      controller: _text,
      focusNode: widget.focusNode,
      search: true,
      placeholder: 'Search name, encoder or tag',
      semanticLabel: 'Search presets',
      onChanged: widget.onChanged,
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.count, required this.first});
  final String title;
  final int count;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final style = t.text.bodyStrong.copyWith(fontWeight: const FontWeight(600));
    return Container(
      margin: EdgeInsets.only(top: first ? 0 : 6),
      padding: EdgeInsets.fromLTRB(8, first ? 6 : 14, 8, 4),
      decoration: first
          ? null
          : BoxDecoration(
              border: Border(top: BorderSide(color: t.colors.line)),
            ),
      child: Semantics(
        header: true,
        label: '$title, $count presets',
        excludeSemantics: true,
        child: Row(
          children: [
            Expanded(child: Text(title, style: style)),
            Text('$count', style: style),
          ],
        ),
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Semantics(
        header: true,
        child: Text(title, style: t.text.captionStrong.copyWith(color: t.colors.muted)),
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.onSelect,
    required this.onFavorite,
    required this.onAction,
  });

  final LibraryEntry entry;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onFavorite;
  final ValueChanged<LibraryAction> onAction;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final e = entry;
    return VePopover(
      width: 240,
      anchorBuilder: (context, open, toggle) {
        final row = Semantics(
          button: true,
          selected: selected,
          label: [
            e.name,
            if (e.advanced) 'Advanced',
            if (e.dirty) 'unsaved changes',
            if (e.errors.isNotEmpty) e.errors.length == 1 ? 'an error' : '${e.errors.length} errors',
            e.line,
            if (e.favorite) 'favorite',
          ].join(', '),
          child: VeInteractive(
            onTap: onSelect,
            onKeyEvent: (node, event) {
              final menuKey =
                  event.logicalKey == LogicalKeyboardKey.contextMenu ||
                  (event.logicalKey == LogicalKeyboardKey.f10 && HardwareKeyboard.instance.isShiftPressed);
              if (event is KeyDownEvent && menuKey) {
                toggle();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            builder: (context, s) => VeFocusRing(
              visible: s.focused,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 32, 6),
                decoration: BoxDecoration(
                  color: selected ? c.fillSelected2 : (s.hovered || open ? c.fillHover : null),
                  borderRadius: BorderRadius.circular(VeRadius.md),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 30, child: e.depth == null ? null : WireGlyph(outputDepth: e.depth!)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  e.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(600), height: 18 / 13),
                                ),
                              ),
                              if (e.errors.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                VeTooltip(
                                  message: e.errors.join('\n'),
                                  child: VeIcon(VeIcons.error, color: c.error, size: 14),
                                ),
                              ],
                              if (e.dirty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
                                ),
                              ],
                            ],
                          ),
                          _Line(entry: e),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        return GestureDetector(
          onSecondaryTap: () {
            onSelect();
            toggle();
          },
          child: Stack(
            children: [
              row,
              if (selected)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: c.ink,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(VeRadius.md)),
                    ),
                  ),
                ),
              Positioned(
                right: 6,
                top: 7,
                child: VeIconButton(
                  icon: VeIcons.star,
                  selectedIcon: VeIcons.starFilled,
                  label: 'Favorite ${e.name}',
                  selected: e.favorite,
                  selectedColor: c.favorite,
                  dimension: 24,
                  onPressed: onFavorite,
                ),
              ),
            ],
          ),
        );
      },
      contentBuilder: (context, close) => VeListbox<LibraryAction>(
        semanticLabel: '${e.name} actions',
        selected: null,
        onClose: close,
        onPick: onAction,
        groups: [
          VeOptionGroup([
            const VeOption(LibraryAction.duplicate, 'Duplicate', detail: 'Copy it into Mine.'),
            VeOption(
              LibraryAction.rename,
              'Rename…',
              enabled: !e.builtin,
              detail: e.builtin ? 'Built-in presets can’t be changed.' : null,
            ),
          ]),
          VeOptionGroup([
            VeOption(
              LibraryAction.export,
              'Export…',
              detail: e.dirty ? 'The saved version, without unsaved changes.' : 'Save it as a .vepreset file.',
            ),
            VeOption(
              LibraryAction.copyShareString,
              'Copy share string',
              detail: e.dirty ? 'The saved version, without unsaved changes.' : 'Text to paste anywhere to share it.',
            ),
            VeOption(
              LibraryAction.showInFolder,
              'Show in folder',
              enabled: !e.builtin,
              detail: e.builtin ? 'Built-in presets are part of the app.' : null,
            ),
          ]),
          VeOptionGroup([
            VeOption(
              LibraryAction.delete,
              'Delete…',
              enabled: !e.builtin,
              detail: e.builtin ? 'Built-in presets can’t be deleted.' : null,
            ),
          ]),
        ],
      ),
    );
  }
}

/// `+` beside the filters: New preset, Import share string…, and Import
/// file… (disabled: the library can't read a `.vepreset` the user picks yet;
/// workstreams/app.md, Needs).
class _AddMenu extends StatelessWidget {
  const _AddMenu({required this.onPick});
  final ValueChanged<LibraryAdd> onPick;

  @override
  Widget build(BuildContext context) {
    return VePopover(
      width: 260,
      anchorBuilder: (context, open, toggle) =>
          VeIconButton(icon: VeIcons.plus, label: 'Add a preset', selected: open, bordered: true, onPressed: toggle),
      contentBuilder: (context, close) => VeListbox<LibraryAdd>(
        semanticLabel: 'Add a preset',
        selected: null,
        onClose: close,
        onPick: onPick,
        groups: const [
          VeOptionGroup([
            VeOption(LibraryAdd.newPreset, 'New preset', detail: 'Start one in Mine from the first built-in.'),
            VeOption(LibraryAdd.importShareString, 'Import share string…', detail: 'Paste a preset someone shared.'),
            VeOption(
              LibraryAdd.importFile,
              'Import file…',
              enabled: false,
              detail: 'Not available yet: the library can’t read a .vepreset file you choose.',
            ),
          ]),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.entry});
  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final text = Text(
      entry.line,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.text.caption.copyWith(height: 17 / 12, color: entry.problem != null ? t.colors.error : t.colors.muted),
    );
    final detail = entry.problemDetail;
    final line = detail == null ? text : VeTooltip(message: detail, child: text);
    if (!entry.advanced) return line;
    // The Advanced tag leads the line, so the name keeps its room.
    return Row(
      children: [
        const _Tag('Advanced'),
        const SizedBox(width: 6),
        Flexible(child: line),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: t.colors.line2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: t.text.micro.copyWith(color: t.colors.muted, fontWeight: const FontWeight(500), height: 15 / 11.5),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query, required this.onClear, required this.onNewPreset});
  final String query;
  final VoidCallback onClear;
  final VoidCallback onNewPreset;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            query.trim().isEmpty ? 'No presets to show.' : 'No presets match “${query.trim()}”.',
            style: t.text.body.copyWith(color: t.colors.muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              VeButton(
                label: 'New preset',
                icon: VeIcons.plus,
                size: VeButtonSize.small,
                tooltip: 'Start a preset in Mine from the first built-in',
                onPressed: onNewPreset,
              ),
              VeLinkButton(label: 'Show all presets', onPressed: onClear),
            ],
          ),
        ],
      ),
    );
  }
}
