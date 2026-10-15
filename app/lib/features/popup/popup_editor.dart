import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/button.dart';
import '../../design/components/interactive.dart';
import '../../design/components/field.dart' show VeBlurbs;
import '../../design/components/popover.dart';
import '../../design/components/segmented.dart';
import '../../design/components/signal_path/signal_path.dart';
import '../../design/format.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/editor.dart';
import '../../state/popup.dart';
import '../../state/presets.dart' show presetId, presetRecipe;
import '../../state/services.dart';
import '../advanced/advanced_workspace.dart';
import '../advanced/display.dart' show advancedChecks, templateEditorModel;
import '../presets/command_column.dart';
import '../presets/display.dart';
import '../presets/library_model.dart' show libraryEntry;
import '../presets/panels/audio_panel.dart';
import '../presets/panels/field_anchor.dart';
import '../presets/panels/other_panels.dart';
import '../presets/panels/panel_kit.dart';
import '../presets/panels/video_panel.dart';
import '../presets/preset_header.dart' show EditorMode;
import 'display.dart';

/// The side column's width (S3 `.pp-body`).
const double popupSideWidth = 352;

/// What the popup's header and side column ask the window to do.
class PopupActions {
  const PopupActions({
    required this.onMode,
    required this.onLoad,
    required this.onSaveAsNew,
    required this.onUpdateOrigin,
    required this.onShowChanges,
    required this.onUpdateFromLibrary,
    required this.onOpenInDesktop,
    required this.onShowField,
    required this.onCopy,
    required this.onReplaceWithBasic,
  });

  final ValueChanged<EditorMode> onMode;
  final ValueChanged<Preset> onLoad;
  final VoidCallback onSaveAsNew;
  final VoidCallback onUpdateOrigin;
  final VoidCallback onShowChanges;
  final VoidCallback onUpdateFromLibrary;

  /// Null when nothing can start the desktop app (no service yet).
  final VoidCallback? onOpenInDesktop;
  final ValueChanged<String> onShowField;
  final VoidCallback onCopy;
  final VoidCallback onReplaceWithBasic;
}

/// The template (S3): header, one-row strip, the selected node's settings or
/// the command, and the side column with the library and the command. Below
/// [dockBreakpoint] the side column docks at the bottom, collapsed, so the
/// strip keeps its width (UI_SPEC §1).
class PopupEditor extends ConsumerStatefulWidget {
  const PopupEditor({
    super.key,
    required this.state,
    required this.data,
    required this.actions,
    required this.commandEditor,
    required this.editorPane,
    required this.sidePane,
  });

  final PopupState state;
  final EditorData data;
  final PopupActions actions;

  /// The Advanced command editor's focus.
  final FocusNode commandEditor;
  final FocusNode editorPane;
  final FocusNode sidePane;

  static const double dockBreakpoint = 1040;

  @override
  ConsumerState<PopupEditor> createState() => _PopupEditorState();
}

class _PopupEditorState extends ConsumerState<PopupEditor> {
  bool _dockOpen = false;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final state = widget.state;
    final data = widget.data;
    final actions = widget.actions;
    final controller = ref.read(popupProvider.notifier);
    final changes = ref.watch(popupChangesProvider);
    final local = changes.local?.value;
    final line = originLine(state, local: local?.length);
    final length = VeFormat.parseLength(state.lengthText);
    final model = signalPathModel(
      recipe: data.recipe,
      catalog: data.catalog,
      media: data.media,
      compiled: data.compiled.value,
      installation: data.installation,
      lengthSec: length,
      preview: data.preview,
    ).withMarks(originMarks(local: local, since: changes.since?.value, revision: line.libraryRevision));
    final scope = PanelScope(data, controller);
    final node = state.node;

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: FocusTraversalGroup(
            child: data.advanced
                ? SignalPath(
                    model: model,
                    layout: SignalPathLayout.strip,
                    onSelect: (_) => widget.commandEditor.requestFocus(),
                  )
                : SignalPath(
                    model: model,
                    layout: SignalPathLayout.strip,
                    selected: node,
                    onSelect: controller.selectNode,
                  ),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: c.surface,
            child: data.advanced
                ? AdvancedWorkspace(
                    key: const ValueKey('popup-advanced'),
                    data: data,
                    editorFocus: widget.commandEditor,
                    editorPane: widget.editorPane,
                    sidePane: widget.sidePane,
                    onSwitchToBasic: () => actions.onMode(EditorMode.basic),
                    onReplaceWithBasic: actions.onReplaceWithBasic,
                    onCopy: actions.onCopy,
                    onTemplateChanged: controller.setTemplate,
                    compact: true,
                  )
                : Focus(
                    focusNode: widget.editorPane,
                    child: FocusTraversalGroup(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            NodePanelHeader(node: node),
                            const SizedBox(height: 12),
                            KeyedSubtree(
                              key: ValueKey('popup/${node.name}'),
                              // S3 hides the fields' explanations.
                              child: VeBlurbs(
                                show: false,
                                child: switch (node) {
                                  SignalNode.source => SourcePanel(scope: scope),
                                  SignalNode.video => VideoPanel(scope: scope),
                                  SignalNode.audio => AudioPanel(scope: scope),
                                  SignalNode.container => ContainerPanel(scope: scope),
                                  SignalNode.file => FilePanel(
                                    scope: scope,
                                    lengthSec: length,
                                    lengthText: state.lengthText,
                                    onLengthTextChanged: controller.setLengthText,
                                  ),
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );

    Widget side(double width) => Focus(
      focusNode: widget.sidePane,
      child: FocusTraversalGroup(
        child: data.advanced
            ? _AdvancedSide(state: state, data: data, line: line, actions: actions, width: width)
            : CommandColumn(
                data: data,
                node: node,
                width: width,
                onShowField: actions.onShowField,
                multiline: state.commandMultiline,
                onToggleLayout: controller.toggleCommandLayout,
                litFields: FieldAnchorScope.maybeOf(context)?.active,
                leading: [
                  LibrarySection(state: state, line: line, actions: actions),
                  const SizedBox(height: 16),
                ],
              ),
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        final docked = box.maxWidth < PopupEditor.dockBreakpoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PopupHeader(state: state, data: data, line: line, actions: actions),
            Expanded(
              child: docked
                  ? main
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: main),
                        side(popupSideWidth),
                      ],
                    ),
            ),
            if (docked)
              _Dock(
                open: _dockOpen,
                summary: dockSummary(line, data),
                onToggle: () => setState(() => _dockOpen = !_dockOpen),
                child: SizedBox(height: 230, child: side(double.infinity)),
              ),
          ],
        );
      },
    );
  }
}

/// The docked side column's one line: the library, then the errors.
String dockSummary(OriginLine line, EditorData data) {
  final library = switch (line.state) {
    OriginState.libraryNewer => 'Library has revision ${line.libraryRevision}',
    OriginState.deleted => 'Not in the library',
    OriginState.noOrigin => 'Made in VEGAS',
    OriginState.unreadable => 'The library couldn’t be read',
    OriginState.unchanged || OriginState.localChanges => 'Up to date with the library',
  };
  final errors =
      data.issues.where((i) => i.level == IssueLevel.error).length +
      (data.lint?.value?.where((d) => d.level == IssueLevel.error).length ?? 0);
  return '$library. ${errors == 0
      ? 'No errors'
      : errors == 1
      ? '1 error'
      : '$errors errors'}.';
}

/// The side column docked under a narrow popup (UI_SPEC §1: a collapsible
/// strip): a summary line that opens it.
class _Dock extends StatelessWidget {
  const _Dock({required this.open, required this.summary, required this.onToggle, required this.child});
  final bool open;
  final String summary;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.panel,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: 'Library and command. $summary',
            excludeSemantics: true,
            child: VeInteractive(
              onTap: onToggle,
              cursor: SystemMouseCursors.click,
              builder: (context, s) => VeFocusRing(
                visible: s.focused,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 9, 16, 9),
                  child: Row(
                    children: [
                      VeIcon(open ? VeIcons.chevronDown : VeIcons.chevronRight, color: c.ink),
                      const SizedBox(width: 6),
                      Text('Library and command', style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(650))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.text.small.copyWith(color: c.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (open)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: child,
            ),
        ],
      ),
    );
  }
}
// ------------------------------------------------------------ header

/// `.pp-head`: the template's name, its origin line and the actions.
class _PopupHeader extends ConsumerWidget {
  const _PopupHeader({required this.state, required this.data, required this.line, required this.actions});
  final PopupState state;
  final EditorData data;
  final OriginLine line;
  final PopupActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final sub = t.text.small.copyWith(color: c.muted, height: 1.4);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    state.templateName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.popupTitle,
                  ),
                ),
                const SizedBox(height: 1),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: line.lead),
                      if (line.name != null)
                        TextSpan(
                          text: line.name,
                          style: TextStyle(color: c.ink, fontWeight: const FontWeight(600)),
                        ),
                      TextSpan(text: line.trail),
                      if (line.changesSentence case final changes?) ...[
                        TextSpan(text: ' $changes '),
                        // "(Show changes)." wraps as one piece.
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('(', style: sub),
                              VeLinkButton(
                                label: 'Show changes',
                                onPressed: actions.onShowChanges,
                                style: sub.copyWith(color: c.ink2),
                              ),
                              Text(').', style: sub),
                            ],
                          ),
                        ),
                      ],
                      const TextSpan(text: ' Rename in VEGAS to change the saved template name.'),
                    ],
                  ),
                  style: sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _LoadPreset(state: state, data: data, onLoad: actions.onLoad),
          const SizedBox(width: 10),
          _SaveToLibrary(state: state, onSaveAsNew: actions.onSaveAsNew, onUpdate: actions.onUpdateOrigin),
          Container(width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 12), color: c.line),
          VeSegmented<EditorMode>(
            semanticLabel: 'Editing mode',
            segments: const [VeSegment(EditorMode.basic, 'Basic'), VeSegment(EditorMode.advanced, 'Advanced')],
            selected: data.advanced ? EditorMode.advanced : EditorMode.basic,
            onChanged: actions.onMode,
          ),
        ],
      ),
    );
  }
}

/// Every preset in the library, read once when Load preset opens (the popup
/// doesn't watch the library).
final popupLibraryListProvider = FutureProvider.autoDispose<List<Preset>>(
  (ref) => ref.watch(presetLibraryProvider).list(),
);

/// Load preset (UI_SPEC §4): a list of the library's presets; choosing one
/// replaces the template's settings at once.
class _LoadPreset extends ConsumerWidget {
  const _LoadPreset({required this.state, required this.data, required this.onLoad});
  final PopupState state;
  final EditorData data;
  final ValueChanged<Preset> onLoad;

  @override
  Widget build(BuildContext context, WidgetRef ref) => VePopover(
    width: 380,
    anchorBuilder: (context, open, toggle) =>
        VeButton(label: 'Load preset', icon: VeIcons.folder, onPressed: toggle, semanticLabel: 'Load preset'),
    contentBuilder: (context, close) => Consumer(
      builder: (context, ref, _) {
        final t = VeTokens.of(context);
        final presets = ref.watch(popupLibraryListProvider);
        return switch (presets) {
          AsyncValue(:final value?) => VeListbox<String>(
            semanticLabel: 'Load a preset into this template',
            groups: [
              for (final builtin in [true, false])
                if (value.any((p) => p.builtin == builtin))
                  VeOptionGroup(header: builtin ? 'Built-in' : 'Mine', [
                    for (final p in value.where((p) => p.builtin == builtin))
                      VeOption(
                        presetId(p),
                        presetRecipe(p).name,
                        detail: libraryEntry(
                          p,
                          recipe: presetRecipe(p),
                          favorite: p.favorite,
                          dirty: false,
                          compiled: null,
                          catalog: data.catalog,
                          installation: data.installation,
                        ).line,
                      ),
                  ]),
            ],
            selected: state.origin?.presetId,
            footnote: 'Loading replaces the template’s settings right away. You can undo it.',
            onClose: close,
            onPick: (id) {
              close();
              onLoad(value.firstWhere((p) => presetId(p) == id));
            },
          ),
          AsyncValue(:final error?) => Padding(
            padding: const EdgeInsets.all(12),
            child: Text('The library couldn’t be read: $error', style: t.text.small),
          ),
          _ => Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Reading the library…', style: t.text.small.copyWith(color: t.colors.muted)),
          ),
        };
      },
    ),
  );
}

/// Save to library (UI_SPEC §4): "Save as new preset…" or "Update the origin
/// (revision 5 → 7)", which built-in origins can't offer.
class _SaveToLibrary extends StatelessWidget {
  const _SaveToLibrary({required this.state, required this.onSaveAsNew, required this.onUpdate});
  final PopupState state;
  final VoidCallback onSaveAsNew;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final latest = state.libraryPreset;
    final origin = state.origin;
    final canUpdate = latest != null && !latest.builtin && origin != null;
    final String why;
    if (origin == null || latest == null) {
      why = 'This template has no preset in the library to update.';
    } else if (latest.builtin) {
      why = 'Built-in presets can’t be changed.';
    } else {
      why = 'The preset takes this template’s settings.';
    }
    return VePopover(
      width: 330,
      anchorBuilder: (context, open, toggle) => VeButton(
        label: 'Save to library',
        icon: VeIcons.save,
        trailingIcon: VeIcons.chevronDown,
        onPressed: toggle,
        semanticLabel: 'Save to library',
      ),
      contentBuilder: (context, close) => VeListbox<String>(
        semanticLabel: 'Save to library',
        groups: [
          VeOptionGroup([
            const VeOption('new', 'Save as new preset…', detail: 'Adds it to Mine.'),
            VeOption(
              'update',
              origin == null ? 'Update the preset' : 'Update “${origin.name}” (${updateRevisions(state)})',
              detail: why,
              enabled: canUpdate,
            ),
          ]),
        ],
        selected: 'new',
        onClose: close,
        onPick: (v) {
          close();
          v == 'new' ? onSaveAsNew() : onUpdate();
        },
      ),
    );
  }
}

// ------------------------------------------------------------ side column

/// `.sd` Library: where the template came from and how it compares with the
/// library now (UI_SPEC §4's origin table).
class LibrarySection extends StatelessWidget {
  const LibrarySection({super.key, required this.state, required this.line, required this.actions});
  final PopupState state;
  final OriginLine line;
  final PopupActions actions;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final p = t.text.small.copyWith(color: c.muted, height: 1.4);
    final latest = state.libraryPreset;
    Widget heading(String text, [String? aside]) => Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Semantics(
          header: true,
          child: Text(text, style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(650))),
        ),
        const Spacer(),
        if (aside != null) Text(aside, style: t.text.caption.copyWith(color: c.muted)),
      ],
    );
    Widget banner(String title, List<Widget> children) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bannerBackground,
        border: Border.all(color: c.amberLine),
        borderRadius: BorderRadius.circular(VeRadius.xl),
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(650))),
            ...children,
          ],
        ),
      ),
    );
    final open = actions.onOpenInDesktop;
    final openButton = state.origin == null || state.library is! OriginFound
        ? null
        : VeButton(
            label: 'Open in Vegas Encoder',
            size: VeButtonSize.small,
            variant: VeButtonVariant.ghost,
            tooltip: open == null
                ? 'Opening Vegas Encoder from here needs a platform service that isn’t there yet.'
                : 'Opens the preset in the desktop app, for library work.',
            onPressed: open,
          );

    final body = <Widget>[];
    switch (line.state) {
      case OriginState.libraryNewer:
        final since = line.libraryRevision!;
        body.add(
          banner('Library has revision $since', [
            const SizedBox(height: 4),
            Text('The library changed “${state.origin!.name}” after revision ${state.origin!.revision}.', style: p),
            const SizedBox(height: 10),
            VeButton(
              label: 'Update from library',
              size: VeButtonSize.small,
              variant: VeButtonVariant.primary,
              onPressed: actions.onUpdateFromLibrary,
            ),
          ]),
        );
      case OriginState.deleted:
        body.add(
          banner('Not in the library', [
            const SizedBox(height: 4),
            Text(line.text, style: p),
            const SizedBox(height: 10),
            VeButton(label: 'Save as new preset…', size: VeButtonSize.small, onPressed: actions.onSaveAsNew),
          ]),
        );
      case OriginState.noOrigin:
        body.add(Text('Made in VEGAS. Save it to the library to use it in other templates.', style: p));
      case OriginState.unreadable:
        body.add(Text(line.text, style: p));
      case OriginState.unchanged || OriginState.localChanges:
        body.add(Text('Up to date with the library preset.', style: p));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('Library', latest == null ? null : 'revision ${latest.revision}'),
        const SizedBox(height: 8),
        ...body,
        if (openButton != null) ...[
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: openButton),
        ],
      ],
    );
  }
}

/// The side column in Advanced mode: the library, and the command's
/// diagnostics count (the command itself is edited below the diagram).
class _AdvancedSide extends StatelessWidget {
  const _AdvancedSide({
    required this.state,
    required this.data,
    required this.line,
    required this.actions,
    required this.width,
  });
  final double width;
  final PopupState state;
  final EditorData data;
  final OriginLine line;
  final PopupActions actions;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    // The same findings the Diagnostics list under the editor shows.
    final template = data.recipe.command.template;
    final model = templateEditorModel(template, compiled: data.compiled.value, lint: data.lint?.value ?? const []);
    final count = advancedChecks(template, model.marks, data.compiled.value).length;
    final diagnostics = count == 1 ? '1 diagnostic' : '$count diagnostics';
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.panel,
        border: Border(left: BorderSide(color: c.line)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 14, 16),
        children: [
          LibrarySection(state: state, line: line, actions: actions),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Semantics(
                header: true,
                child: Text('Command', style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(650))),
              ),
              const Spacer(),
              Text('yours', style: t.text.caption.copyWith(color: c.muted)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.lint?.ok == false
                ? 'The core couldn’t check the command: ${data.lint!.error!.message}'
                : '$diagnostics. Edit it below the diagram.',
            style: t.text.small.copyWith(color: c.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
