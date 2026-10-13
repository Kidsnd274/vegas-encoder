import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart' show Preset;

import '../../design/components/button.dart';
import '../../design/components/command_view.dart';
import '../../design/components/dialog.dart';
import '../../design/components/signal_path/signal_path.dart';
import '../../design/components/toast.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/editor.dart';
import '../../state/presets.dart';
import '../../state/services.dart';
import '../../state/ui_state.dart';
import 'command_column.dart';
import 'display.dart';
import 'library_model.dart';
import 'library_pane.dart';
import 'palette.dart';
import 'panels/audio_panel.dart';
import 'panels/field_anchor.dart';
import 'panels/other_panels.dart';
import 'panels/panel_kit.dart';
import 'panels/video_panel.dart';
import 'preset_header.dart';

/// Below this window width the library collapses to a rail (UI_SPEC §1).
const double libraryRailBreakpoint = 1280;

/// The Presets screen (S1): the library, then the selected preset's signal
/// path, the selected node's settings, and the command with its checks.
class PresetsPage extends ConsumerStatefulWidget {
  const PresetsPage({super.key});

  @override
  ConsumerState<PresetsPage> createState() => _PresetsPageState();
}

class _PresetsPageState extends ConsumerState<PresetsPage> {
  final FocusNode _search = FocusNode(debugLabel: 'library search');
  final FieldAnchors _anchors = FieldAnchors();

  /// The panes F6 and Shift+F6 move between: library, diagram, settings,
  /// command (UI_SPEC §7).
  final List<FocusNode> _panes = [
    for (final name in ['library', 'diagram', 'settings', 'command'])
      FocusNode(debugLabel: '$name pane', skipTraversal: true, canRequestFocus: false),
  ];

  ({String message, String? action, VoidCallback? onAction})? _toast;
  Timer? _toastTimer;

  /// The library overlay in the narrow layout.
  bool _libraryOpen = false;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _search.dispose();
    _anchors.dispose();
    for (final p in _panes) {
      p.dispose();
    }
    super.dispose();
  }

  PresetsController get _controller => ref.read(presetsControllerProvider.notifier);

  void _showToast(String message, {String? action, VoidCallback? onAction}) {
    _toastTimer?.cancel();
    setState(() => _toast = (message: message, action: action, onAction: onAction));
    _toastTimer = Timer(Duration(seconds: action == null ? 3 : 8), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ------------------------------------------------------------ actions

  Future<void> _save() async {
    final data = ref.read(editorProvider);
    if (data == null || !data.dirty) return;
    var overwrite = false;
    if (data.behindLibrary && !data.preset.builtin) {
      final choice = await _askConflict(data.recipe.name);
      if (choice == null) return;
      if (choice == _Conflict.saveAsNew) return _saveAsNew();
      overwrite = true;
    }
    final outcome = await _controller.save(overwrite: overwrite);
    if (!mounted) return;
    switch (outcome) {
      case SaveOutcome.saved:
        _showToast('Preset saved');
      case SaveOutcome.savedAsNew:
        _showToast('Saved as a new preset in Mine');
      case SaveOutcome.conflict:
        final choice = await _askConflict(data.recipe.name);
        if (choice == _Conflict.saveAsNew) return _saveAsNew();
        if (choice == _Conflict.overwrite) {
          await _controller.save(overwrite: true);
          if (mounted) _showToast('Preset saved');
        }
      case SaveOutcome.nothingToSave:
        break;
    }
  }

  Future<void> _saveAsNew() async {
    await _controller.saveAsNew();
    if (mounted) _showToast('Saved as a new preset in Mine');
  }

  Future<_Conflict?> _askConflict(String name) => showVeDialog<_Conflict>(
    context,
    title: '“$name” changed in another window',
    message: 'Replace that version with yours, or keep both by saving yours as a new preset.',
    actions: const [
      VeDialogAction('Cancel', _Conflict.cancel),
      VeDialogAction('Save as new preset', _Conflict.saveAsNew),
      VeDialogAction('Replace it', _Conflict.overwrite, variant: VeButtonVariant.primary),
    ],
  ).then((c) => c == _Conflict.cancel ? null : c);

  void _revert() {
    final data = ref.read(editorProvider);
    final draft = data?.draft;
    if (data == null || draft == null) return;
    final id = data.preset.recipe.id;
    _controller.revert(id);
    _showToast(
      'Reverted “${data.preset.recipe.name}”',
      action: 'Undo',
      onAction: () {
        _controller.restoreDraft(id, draft);
        setState(() => _toast = null);
      },
    );
  }

  Future<void> _duplicate(String id) async {
    await _controller.duplicate(id);
    if (mounted) _showToast('Duplicated into Mine');
  }

  /// "New preset": a preset in Mine started from the first built-in.
  Future<void> _newPreset() async {
    final first = groupLibrary(ref.read(libraryEntriesProvider))
        .where((g) => g.title == 'Built-in')
        .firstOrNull
        ?.subgroups
        .first
        .entries
        .first;
    if (first == null) return;
    await _controller.createNew(first.id);
    if (mounted) {
      setState(() => _libraryOpen = false);
      _showToast('Started a new preset in Mine from “${first.name}”');
    }
  }

  Future<void> _libraryAction(LibraryAction action, LibraryEntry entry) async {
    switch (action) {
      case LibraryAction.duplicate:
        await _duplicate(entry.id);
      case LibraryAction.rename:
        final name = await showVeTextDialog(
          context,
          title: 'Rename preset',
          label: 'Name',
          initial: entry.name,
          confirmLabel: 'Rename',
        );
        if (name != null && name != entry.name) await _controller.rename(entry.id, name);
      case LibraryAction.delete:
        final ok = await showVeDialog<bool>(
          context,
          title: 'Delete “${entry.name}”?',
          message: 'It is removed from your library. Render templates made from it keep all their settings.',
          actions: const [
            VeDialogAction('Cancel', false),
            VeDialogAction('Delete', true, variant: VeButtonVariant.primary),
          ],
        );
        if (ok == true) {
          await _controller.delete(entry.id);
          if (mounted) _showToast('Deleted “${entry.name}”');
        }
    }
  }

  void _copyCommand() {
    final compiled = ref.read(editorProvider)?.compiled.value;
    if (compiled == null) return;
    unawaited(copyCommand(compiled.commandLine));
    _showToast('Command copied');
  }

  /// "Show setting": opens the node that holds [field], then scrolls to its
  /// control and focuses it.
  void _showField(String field) {
    final node = nodeForField(field);
    if (node == null) return;
    _controller.selectNode(node);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _anchors.reveal(field);
    });
  }

  Future<void> _openPalette() async {
    final id = await showPresetPalette(context, ref.read(libraryEntriesProvider));
    if (id != null && mounted) _controller.select(id);
  }

  void _searchLibrary(bool narrow) {
    if (narrow && !_libraryOpen) setState(() => _libraryOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _search.requestFocus();
    });
  }

  /// F6 / Shift+F6: the next or previous pane's first control.
  void _cyclePane(int step) {
    final current = _panes.indexWhere((p) => p.hasFocus);
    for (var n = 1; n <= _panes.length; n++) {
      final pane = _panes[((current < 0 ? (step > 0 ? -1 : 0) : current) + step * n) % _panes.length];
      final target = pane.descendants.where((d) => d.canRequestFocus && !d.skipTraversal).firstOrNull;
      if (target != null) {
        target.requestFocus();
        return;
      }
    }
  }

  /// Selects the first preset when nothing (or a deleted preset) is selected.
  void _ensureSelection(List<Preset> presets, PresetsState state) {
    if (presets.isEmpty || presets.any((p) => p.recipe.id == state.selectedId)) return;
    final groups = groupLibrary(ref.read(libraryEntriesProvider));
    final first = groups.isEmpty ? presets.first.recipe.id : groups.first.subgroups.first.entries.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(presetsControllerProvider).selectedId == state.selectedId) _controller.select(first);
    });
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final presets = ref.watch(presetsProvider);
    final state = ref.watch(presetsControllerProvider);
    final data = ref.watch(editorProvider);
    if (presets.value case final list?) _ensureSelection(list, state);

    return LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < libraryRailBreakpoint;
        final library = LibraryPane(
          searchFocus: _search,
          onAction: _libraryAction,
          onNewPreset: _newPreset,
          onPicked: narrow ? () => setState(() => _libraryOpen = false) : null,
        );
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => unawaited(_save()),
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => _searchLibrary(narrow),
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => unawaited(_openPalette()),
            const SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true): _copyCommand,
            const SingleActivator(LogicalKeyboardKey.f6): () => _cyclePane(1),
            const SingleActivator(LogicalKeyboardKey.f6, shift: true): () => _cyclePane(-1),
            if (narrow && _libraryOpen)
              const SingleActivator(LogicalKeyboardKey.escape): () => setState(() => _libraryOpen = false),
          },
          child: Focus(
            autofocus: true,
            child: FieldAnchorScope(
              anchors: _anchors,
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (narrow)
                        _LibraryRail(
                          open: _libraryOpen,
                          onToggle: () => setState(() => _libraryOpen = !_libraryOpen),
                          onPalette: () => unawaited(_openPalette()),
                        )
                      else
                        SizedBox(
                          width: 256,
                          child: Focus(
                            focusNode: _panes[0],
                            child: FocusTraversalGroup(child: library),
                          ),
                        ),
                      Expanded(
                        child: switch (presets) {
                          AsyncError(:final error) => _Centered('The library couldn’t be read: $error'),
                          _ when data == null => const SizedBox.shrink(),
                          _ => _Editor(
                            data: data,
                            node: state.node,
                            lengthSec: ref.watch(sizeLengthSecProvider),
                            lengthText: ref.watch(sizeLengthTextProvider),
                            multiline: state.commandMultiline,
                            panes: _panes,
                            onSave: _save,
                            onRevert: _revert,
                            onDuplicate: () => _duplicate(data.preset.recipe.id),
                            onMode: (m) {
                              if (m == EditorMode.advanced) {
                                _showToast('Advanced mode arrives in milestone F4');
                              }
                            },
                            onShowField: _showField,
                          ),
                        },
                      ),
                    ],
                  ),
                  if (narrow && _libraryOpen)
                    Positioned(
                      left: _LibraryRail.width,
                      top: 0,
                      bottom: 0,
                      width: 256,
                      child: TapRegion(
                        onTapOutside: (_) => setState(() => _libraryOpen = false),
                        child: DecoratedBox(
                          decoration: BoxDecoration(boxShadow: VeTokens.of(context).popoverShadow),
                          child: Focus(
                            focusNode: _panes[0],
                            child: FocusTraversalGroup(child: library),
                          ),
                        ),
                      ),
                    ),
                  if (_toast case final toast?)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 22,
                      child: Center(
                        child: VeToast(message: toast.message, actionLabel: toast.action, onAction: toast.onAction),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _Conflict { cancel, saveAsNew, overwrite }

class _Centered extends StatelessWidget {
  const _Centered(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Center(
      child: Text(text, style: t.text.body.copyWith(color: t.colors.muted)),
    );
  }
}

/// The library collapsed to a rail in a narrow window: the library opens over
/// the editor, and Ctrl+K opens a preset by name.
class _LibraryRail extends StatelessWidget {
  const _LibraryRail({required this.open, required this.onToggle, required this.onPalette});
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onPalette;

  static const double width = 52;

  @override
  Widget build(BuildContext context) {
    final c = VeTokens.of(context).colors;
    return Container(
      width: width,
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.line)),
      ),
      child: Column(
        children: [
          VeIconButton(
            icon: VeIcons.layers,
            label: open ? 'Hide the preset library' : 'Show the preset library (Ctrl+F)',
            selected: open,
            bordered: true,
            onPressed: onToggle,
          ),
          const SizedBox(height: 8),
          VeIconButton(icon: VeIcons.search, label: 'Open a preset by name (Ctrl+K)', onPressed: onPalette),
        ],
      ),
    );
  }
}

/// The selected preset: header, notices, diagram, node settings, command.
class _Editor extends ConsumerWidget {
  const _Editor({
    required this.data,
    required this.node,
    required this.lengthSec,
    required this.lengthText,
    required this.multiline,
    required this.panes,
    required this.onSave,
    required this.onRevert,
    required this.onDuplicate,
    required this.onMode,
    required this.onShowField,
  });

  final EditorData data;
  final SignalNode node;
  final int? lengthSec;
  final String lengthText;
  final bool multiline;

  /// Library, diagram, settings and command pane focus nodes, for F6.
  final List<FocusNode> panes;
  final VoidCallback onSave;
  final VoidCallback onRevert;
  final VoidCallback onDuplicate;
  final ValueChanged<EditorMode> onMode;
  final ValueChanged<String> onShowField;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final controller = ref.read(presetsControllerProvider.notifier);
    final scope = PanelScope(data, controller);
    final model = signalPathModel(
      recipe: data.recipe,
      catalog: data.catalog,
      media: data.media,
      compiled: data.compiled.value,
      installation: data.installation,
      lengthSec: lengthSec,
    );
    final id = data.preset.recipe.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PresetHeader(
          data: data,
          onMode: onMode,
          onInstallation: controller.selectInstallation,
          onDuplicate: onDuplicate,
          onRevert: onRevert,
          onSave: onSave,
        ),
        if (data.changedElsewhere)
          _Banner(
            text: 'This preset changed in another window.',
            actions: [
              VeButton(
                label: 'Reload',
                size: VeButtonSize.small,
                variant: VeButtonVariant.primary,
                onPressed: () => controller.revert(id),
              ),
              VeButton(label: 'Keep editing', size: VeButtonSize.small, onPressed: () => controller.keepEditing(id)),
            ],
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Focus(
            focusNode: panes[1],
            child: FocusTraversalGroup(
              child: SignalPath(model: model, selected: node, onSelect: controller.selectNode),
            ),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: c.surface,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Focus(
                    focusNode: panes[2],
                    child: FocusTraversalGroup(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PanelHeader(node: node),
                            const SizedBox(height: 14),
                            KeyedSubtree(
                              key: ValueKey('$id/${node.name}'),
                              child: switch (node) {
                                SignalNode.source => SourcePanel(scope: scope),
                                SignalNode.video => VideoPanel(scope: scope),
                                SignalNode.audio => AudioPanel(scope: scope),
                                SignalNode.container => ContainerPanel(scope: scope),
                                SignalNode.file => FilePanel(
                                  scope: scope,
                                  lengthSec: lengthSec,
                                  lengthText: lengthText,
                                  onLengthTextChanged: controller.setLengthText,
                                ),
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Focus(
                  focusNode: panes[3],
                  child: FocusTraversalGroup(
                    child: CommandColumn(
                      data: data,
                      node: node,
                      onShowField: onShowField,
                      multiline: multiline,
                      onToggleLayout: controller.toggleCommandLayout,
                      litFields: FieldAnchorScope.maybeOf(context)?.active,
                    ),
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

/// `.ip-h`: the node's name and what it does.
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.node});
  final SignalNode node;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final (title, sub, color) = switch (node) {
      SignalNode.source => ('From VEGAS', 'What the project delivers', c.faint),
      SignalNode.video => ('Video encoder', 'Encodes the frames', c.videoWire),
      SignalNode.audio => ('Audio encoder', 'Encodes the samples', c.audioWire),
      SignalNode.container => ('Container', 'Joins the streams into one file', c.containerWire),
      SignalNode.file => ('File', 'Where the render goes, and how big it will be', c.containerWire),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Semantics(header: true, child: Text(title, style: t.text.panelTitle)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(sub, style: t.text.small.copyWith(color: c.muted)),
        ),
      ],
    );
  }
}

/// `.banner`: an amber notice across the editor with its actions.
class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.actions});
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 8, 16, 8),
        decoration: BoxDecoration(
          color: c.bannerBackground,
          border: Border(bottom: BorderSide(color: c.amberLine)),
        ),
        child: Row(
          children: [
            VeIcon(VeIcons.warning, color: c.warning),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: t.text.bodyStrong)),
            for (final a in actions) ...[const SizedBox(width: 8), a],
          ],
        ),
      ),
    );
  }
}
