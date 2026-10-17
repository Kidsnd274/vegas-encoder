import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:ve_services/ve_services.dart';

import '../../design/components/button.dart';
import '../../design/components/command_view.dart' show copyCommand;
import '../../design/components/dialog.dart';
import '../../design/components/title_bar.dart';
import '../../design/components/toast.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/app_state.dart';
import '../../state/popup.dart';
import '../../state/popup_placement.dart';
import '../../state/popup_version.dart';
import '../../state/services.dart';
import '../../state/ui_state.dart';
import '../advanced/mode_switch.dart';
import '../presets/display.dart' show nodeForField;
import '../presets/panels/field_anchor.dart';
import '../presets/preset_header.dart' show EditorMode;
import '../presets/save_check.dart';
import 'popup_dialogs.dart';
import 'popup_editor.dart';
import 'popup_version.dart';

/// The VEGAS popup (`--edit-session`, S3, UI_SPEC §4): one render template,
/// owned by VEGAS's dialog. Apply writes the template's settings as the
/// session's result; Cancel, Esc and the title bar's close write a cancel.
/// Either way the window then closes.
class PopupWindow extends ConsumerStatefulWidget {
  const PopupWindow({super.key, this.launchError});

  /// `--edit-session` without its directory.
  final String? launchError;

  @override
  ConsumerState<PopupWindow> createState() => _PopupWindowState();
}

class _PopupWindowState extends ConsumerState<PopupWindow> {
  late final AppLifecycleListener _lifecycle;
  final FocusNode _commandEditor = FocusNode(debugLabel: 'popup command editor');
  final FocusNode _editorPane = FocusNode(debugLabel: 'popup editor', skipTraversal: true);
  final FocusNode _sidePane = FocusNode(debugLabel: 'popup side', skipTraversal: true);
  final FieldAnchors _anchors = FieldAnchors();
  Timer? _toastTimer;
  Timer? _undoTimer;
  String? _toast;
  PopupSnapshot? _undoShown;
  bool _asking = false;

  /// Set once the popup chose to close (a result written, or a cancel that
  /// couldn't be): the exit request that follows must not ask again.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _toastTimer?.cancel();
    _undoTimer?.cancel();
    _commandEditor.dispose();
    _editorPane.dispose();
    _sidePane.dispose();
    _anchors.dispose();
    super.dispose();
  }

  PopupController get _controller => ref.read(popupProvider.notifier);
  PopupState? get _state => ref.read(popupProvider).value;

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// The Undo bar lasts 8 seconds (S3); a new one replaces it.
  void _watchUndo(PopupSnapshot? undo) {
    if (identical(undo, _undoShown)) return;
    _undoShown = undo;
    _undoTimer?.cancel();
    if (undo != null) {
      _undoTimer = Timer(const Duration(seconds: 8), () {
        if (mounted && identical(_state?.undo, undo)) _controller.dismissUndo();
      });
    }
  }

  void _afterFrame(VoidCallback action) => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) action();
  });

  // ------------------------------------------------------------ closing

  /// Cancel: asks first only when the template changed (UI_SPEC §4).
  /// Returns whether the popup is closing.
  Future<bool> _cancel() async {
    final s = _state;
    if (s == null) {
      // No session to answer: closing is a Cancel (C4: no result means cancel).
      await _close();
      return true;
    }
    if (s.finished != null) return true;
    if (_asking) return false;
    if (s.changed) {
      _asking = true;
      final bool? discard;
      try {
        discard = await showVeDialog<bool>(
          context,
          title: 'Discard changes to this template?',
          message: 'The template keeps the settings it had when you opened it.',
          actions: const [
            VeDialogAction('Keep editing', false),
            VeDialogAction('Discard changes', true, variant: VeButtonVariant.primary),
          ],
        );
      } finally {
        _asking = false;
      }
      if (discard != true || !mounted) return false;
    }
    try {
      await _controller.cancel();
    } on ServiceException {
      // A cancel that can't be written is still a cancel (C4).
    }
    await _close();
    return true;
  }

  /// The title bar's close, Alt+F4 and the taskbar: the same as Cancel.
  Future<AppExitResponse> _onExitRequested() async {
    final s = _state;
    if (_closing) return AppExitResponse.exit;
    if (s == null || s.finished != null) {
      await _rememberSize();
      return AppExitResponse.exit;
    }
    if (!mounted) return AppExitResponse.exit;
    // _cancel closes the window itself once the result is written.
    await _cancel();
    return AppExitResponse.cancel;
  }

  /// Apply to template (Ctrl+Enter): the settings as the session's result.
  Future<void> _apply() async {
    final data = ref.read(popupEditorProvider);
    final s = _state;
    if (data == null || s == null || s.finished != null) return;
    if (applyBlocked(data) case final why?) {
      _showToast(why);
      return;
    }
    try {
      await _controller.apply();
    } on ServiceException catch (e) {
      if (mounted) _showToast('Couldn’t apply to the template: ${e.message}');
      return;
    }
    await _close();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    final window = ref.read(windowControllerProvider);
    await _rememberSize();
    if (mounted) await window.close();
  }

  Future<void> _rememberSize() async {
    try {
      await rememberPopupSize(ref.read(windowControllerProvider), ref.read(uiStateWriterProvider));
    } on Object {
      // Unavailable settings/services must not keep the editor open.
    }
  }

  // ------------------------------------------------------------ actions

  Future<void> _setMode(EditorMode mode) async {
    final data = ref.read(popupEditorProvider);
    final advanced = mode == EditorMode.advanced;
    if (data == null || advanced == data.advanced) return;
    if (!advanced) {
      _controller.setMode(advanced: false);
      return;
    }
    final start = await askAdvancedStart(context, data);
    if (!mounted || start == AdvancedStart.cancel) return;
    if (start == AdvancedStart.keepSaved) {
      _controller.setMode(advanced: true);
      _afterFrame(_commandEditor.requestFocus);
      return;
    }
    final template = data.compiled.value?.advancedTemplate;
    if (template == null) {
      _showToast(
        'Advanced mode starts from the command, which the core couldn’t build: '
        '${data.compiled.error?.message ?? 'unknown error'}',
      );
      return;
    }
    _controller.setMode(advanced: true, template: template);
    _afterFrame(_commandEditor.requestFocus);
  }

  void _toggleMode() {
    final data = ref.read(popupEditorProvider);
    if (data != null) unawaited(_setMode(data.advanced ? EditorMode.basic : EditorMode.advanced));
  }

  void _replaceWithBasic() {
    final seed = ref.read(popupEditorProvider)?.basic?.value?.advancedTemplate;
    if (seed != null) _controller.setTemplate(seed);
  }

  void _copy() {
    final compiled = ref.read(popupEditorProvider)?.compiled.value;
    if (compiled == null) return;
    unawaited(copyCommand(compiled.commandLine));
    _showToast('Command copied');
  }

  void _showField(String field) {
    final node = nodeForField(field);
    if (node == null) return;
    _controller.selectNode(node);
    _afterFrame(() => _anchors.reveal(field));
  }

  /// Warns before a library save of settings with errors (owner decision,
  /// 2026-10-15), checked as the popup checks them: against the default FFmpeg.
  Future<bool> _checkSave() async {
    final s = _state;
    final data = ref.read(popupEditorProvider);
    if (s == null || data == null) return false;
    final errors = saveErrors(ref.read(veCoreProvider), s.recipe, data.issues);
    final check = await checkSave(
      context,
      name: s.templateName,
      settings: errors.settings,
      ffmpeg: errors.ffmpeg,
      installation: data.installation?.label ?? 'this FFmpeg',
    );
    if (!mounted) return false;
    if (check == SaveCheck.showSetting) _showField(errors.settings.first.field);
    return check == SaveCheck.save;
  }

  Future<void> _saveAsNew() async {
    final s = _state;
    if (s == null || !await _checkSave() || !mounted) return;
    final name = await showVeTextDialog(
      context,
      title: 'Save as new preset',
      label: 'Name',
      initial: s.templateName,
      confirmLabel: 'Save',
    );
    if (name == null || !mounted) return;
    try {
      final created = await _controller.saveAsNew(name);
      if (mounted) _showToast('Saved “${created.recipe.name}” to the library.');
    } on ServiceException catch (e) {
      if (mounted) _showToast('Couldn’t save to the library: ${e.message}');
    }
  }

  Future<void> _updateOrigin() async {
    final name = _state?.origin?.name ?? 'the preset';
    if (!await _checkSave()) return;
    try {
      final saved = await _controller.updateOrigin();
      if (mounted) _showToast('Updated “$name” to revision ${saved.revision}.');
    } on ServiceException catch (e) {
      if (mounted) _showToast('Couldn’t update “$name”: ${e.message}');
    }
  }

  Future<void> _showChanges() async {
    final s = _state;
    final data = ref.read(popupEditorProvider);
    final local = ref.read(popupChangesProvider).local?.value;
    if (s == null || data == null || local == null || s.origin == null) return;
    await showTemplateChanges(
      context,
      originName: s.origin!.name,
      revision: s.origin!.revision,
      changes: local,
      catalog: data.catalog,
      recipe: s.recipe,
    );
  }

  Future<void> _updateFromLibrary() async {
    final s = _state;
    final data = ref.read(popupEditorProvider);
    final latest = s?.libraryPreset;
    if (s == null || data == null || latest == null || s.origin == null) return;
    final changes = ref.read(popupChangesProvider);
    final since = changes.since?.value;
    final choice = await showUpdateFromLibrary(
      context,
      revision: s.origin!.revision,
      libraryRevision: latest.revision,
      catalog: data.catalog,
      recipe: s.recipe,
      since: since,
      mine: changes.local?.value,
      fromLibrary: changes.fromLibrary?.value,
      canMerge: changes.canMerge,
    );
    if (!mounted) return;
    switch (choice) {
      case LibraryUpdate.replace:
        _controller.replaceWithLibrary();
      case LibraryUpdate.merge when since != null:
        _controller.takeLibraryChanges(since);
      case LibraryUpdate.merge || null:
        break;
    }
  }

  Future<void> _openInDesktop(DesktopAppLauncher launcher) async {
    final id = _state?.origin?.presetId;
    if (id == null) return;
    try {
      await launcher.openPreset(id);
    } on ServiceException catch (e) {
      if (mounted) _showToast('Couldn’t open Vegas Encoder: ${e.message}');
    }
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final window = ref.watch(windowControllerProvider);
    final popup = ref.watch(popupProvider);
    final data = ref.watch(popupEditorProvider);
    final s = popup.value;
    _watchUndo(s?.undo);
    final launcher = ref.watch(desktopAppLauncherProvider);
    final blocked = data == null ? null : applyBlocked(data);
    final versions = ref.watch(popupVersionsProvider).asData?.value;

    final Widget body;
    if (widget.launchError case final error?) {
      body = _Problem(text: error, detail: 'Closing this window leaves the template as it was.');
    } else if (s != null && data != null) {
      body = FieldAnchorScope(
        anchors: _anchors,
        child: PopupEditor(
          state: s,
          data: data,
          commandEditor: _commandEditor,
          editorPane: _editorPane,
          sidePane: _sidePane,
          actions: PopupActions(
            onMode: (m) => unawaited(_setMode(m)),
            onLoad: _controller.loadPreset,
            onSaveAsNew: () => unawaited(_saveAsNew()),
            onUpdateOrigin: () => unawaited(_updateOrigin()),
            onShowChanges: () => unawaited(_showChanges()),
            onUpdateFromLibrary: () => unawaited(_updateFromLibrary()),
            onOpenInDesktop: launcher == null ? null : () => unawaited(_openInDesktop(launcher)),
            onShowField: _showField,
            onCopy: _copy,
            onReplaceWithBasic: _replaceWithBasic,
          ),
        ),
      );
    } else if (popup.hasError) {
      // Riverpod keeps retrying a failed provider; the error stays on it.
      body = _Problem(
        text: 'Vegas Encoder couldn’t open this template: ${_message(popup.error)}',
        detail: 'Closing this window leaves the template as it was.',
      );
    } else {
      body = const SizedBox.shrink();
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => unawaited(_cancel()),
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () => unawaited(_apply()),
        const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true): () => unawaited(_apply()),
        const SingleActivator(LogicalKeyboardKey.keyM, control: true): _toggleMode,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true): _copy,
      },
      child: Focus(
        autofocus: true,
        child: ColoredBox(
          color: c.paper,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VeTitleBar(
                height: 34,
                title: const Text('Vegas Encoder, editing a VEGAS render template'),
                onDragStart: window.startDrag,
                onClose: () => unawaited(_cancel()),
                closeLabel: 'Cancel',
              ),
              if (s != null && versions != null) PopupVersionWarning(status: versions),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: body),
                    if (s?.undo case final undo?)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 18,
                        child: Center(
                          child: VeToast(message: undo.message, actionLabel: 'Undo', onAction: _controller.undo),
                        ),
                      )
                    else if (_toast case final toast?)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 18,
                        child: Center(child: VeToast(message: toast)),
                      ),
                  ],
                ),
              ),
              _Footer(
                blocked: s == null ? null : blocked,
                outputExtension: s?.request.context.target == null ? null : data?.compiled.value?.outputExtension,
                canApply: s != null && data != null && blocked == null && s.finished == null,
                onCancel: () => unawaited(_cancel()),
                onApply: () => unawaited(_apply()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _message(Object? error) => switch (error) {
  // Riverpod wraps a failure that reached it through another provider.
  ProviderException(:final exception) => _message(exception),
  ServiceException(:final message) => message,
  CoreException(:final message) => message,
  _ => '$error',
};

/// `.pp-foot`: what Apply does, Cancel and Apply to template.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.blocked,
    required this.canApply,
    required this.onCancel,
    required this.onApply,
    this.outputExtension,
  });

  /// Why Apply is off, said beside it.
  final String? blocked;
  final String? outputExtension;
  final bool canApply;
  final VoidCallback onCancel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final why = blocked;
    final extension = outputExtension;
    final guidance = extension == null
        ? 'Apply updates this render template. Save it in VEGAS to keep it for next time.'
        : 'Use $extension for the Render As filename. Apply updates this template; save it in VEGAS to keep it.';
    return Container(
      height: 58,
      padding: const EdgeInsets.only(left: 20, right: 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          if (why == null) VeIcon(VeIcons.info, color: c.muted) else VeIcon(VeIcons.error, color: c.error),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                why ?? guidance,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.text.small.copyWith(color: why == null ? c.muted : c.errorText),
              ),
            ),
          ),
          const SizedBox(width: 10),
          VeButton(label: 'Cancel', tooltip: 'Esc', onPressed: onCancel),
          const SizedBox(width: 10),
          VeButton(
            label: 'Apply to template',
            variant: VeButtonVariant.primary,
            tooltip: why ?? 'Ctrl+Enter',
            onPressed: canApply ? onApply : null,
          ),
        ],
      ),
    );
  }
}

/// A session that can't be edited: why, and that closing changes nothing.
class _Problem extends StatelessWidget {
  const _Problem({required this.text, required this.detail});
  final String text;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(VeSpace.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VeIcon(VeIcons.warning, color: t.colors.warning),
              const SizedBox(height: 10),
              Text(text, textAlign: TextAlign.center, style: t.text.panelTitle),
              const SizedBox(height: 6),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: t.text.small.copyWith(color: t.colors.text2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
