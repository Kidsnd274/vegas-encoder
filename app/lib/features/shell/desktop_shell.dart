import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart' show DesktopWindowBounds;

import '../../design/components/button.dart';
import '../../design/components/dialog.dart';
import '../../design/components/title_bar.dart';
import '../../design/tokens.dart';
import '../../state/app_state.dart';
import '../../state/presets.dart';
import '../../state/services.dart';
import '../../state/ui_state.dart';
import '../ffmpeg/ffmpeg_page.dart';
import '../gallery/gallery_page.dart';
import '../history/history_page.dart';
import '../presets/presets_page.dart';
import '../settings/settings_page.dart';
import 'core_unavailable.dart';

/// The desktop window: title bar with Presets, FFmpeg, History and Settings.
/// In debug builds Ctrl+Shift+D shows the design system gallery (F1).
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  bool _gallery = false;

  static const _nav = [
    VeNavItem('Presets', shortcut: 'Ctrl+1'),
    VeNavItem('FFmpeg', shortcut: 'Ctrl+2'),
    VeNavItem('History', shortcut: 'Ctrl+3'),
    VeNavItem('Settings', shortcut: 'Ctrl+4'),
  ];

  void _go(int i) {
    ref.read(desktopSectionProvider.notifier).go(DesktopSection.values[i]);
    setState(() => _gallery = false);
  }

  /// Every way of closing the window (the title bar's Close, Alt+F4, the
  /// taskbar) reaches this: Flutter's Windows engine asks before it closes the
  /// last window. Unsaved presets ask first (UI_SPEC §2).
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Remembers where the window is (C7 `uiState`) for the next start. A
  /// failed write never keeps the window open.
  Future<AppExitResponse> _exit() async {
    try {
      final placed = await ref.read(windowControllerProvider).restoredBounds();
      if (placed != null) {
        final b = placed.bounds;
        await ref
            .read(uiStateWriterProvider)
            .update(
              (ui) => ui.copyWith(
                desktopWindowBounds: DesktopWindowBounds(x: b.x, y: b.y, width: b.width, height: b.height),
                desktopMaximized: placed.maximized,
              ),
            );
      }
    } on Object {
      // Keep closing.
    }
    return AppExitResponse.exit;
  }

  Future<AppExitResponse> _onExitRequested() async {
    final drafts = ref.read(presetsControllerProvider).drafts;
    if (drafts.isEmpty) return _exit();
    if (_asking || !mounted) return AppExitResponse.cancel;
    final presets = ref.read(presetsProvider).value ?? const [];
    final names = [
      for (final id in drafts.keys) presets.where((p) => p.recipe.id == id).firstOrNull?.recipe.name ?? id,
    ];
    final one = names.length == 1;
    _asking = true;
    final _CloseChoice? choice;
    try {
      choice = await showVeDialog<_CloseChoice>(
        context,
        title: one ? 'Save changes to “${names.first}”?' : 'Save changes to ${names.length} presets?',
        message: one
            ? 'Your changes are lost if you don’t save them.'
            : 'These presets have unsaved changes: ${names.join(', ')}.',
        actions: [
          const VeDialogAction('Cancel', _CloseChoice.cancel),
          const VeDialogAction('Don’t save', _CloseChoice.discard),
          VeDialogAction(one ? 'Save' : 'Save all', _CloseChoice.save, variant: VeButtonVariant.primary),
        ],
      );
    } finally {
      _asking = false;
    }
    if (choice == _CloseChoice.discard) return _exit();
    if (choice != _CloseChoice.save) return AppExitResponse.cancel;
    final controller = ref.read(presetsControllerProvider.notifier);
    for (final id in drafts.keys.toList()) {
      if (await controller.save(id: id) == SaveOutcome.conflict) {
        // Changed in another window: stay open on that preset so the user decides.
        controller.select(id);
        return AppExitResponse.cancel;
      }
    }
    return _exit();
  }

  @override
  Widget build(BuildContext context) {
    final window = ref.watch(windowControllerProvider);
    final maximized = ref.watch(windowStateProvider.select((s) => s.maximized));
    final c = VeTokens.of(context).colors;
    final section = ref.watch(desktopSectionProvider);
    final coreError = ref.watch(coreLoadErrorProvider);

    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i < _nav.length; i++)
          SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), control: true): () => _go(i),
        if (kDebugMode)
          const SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true): () =>
              setState(() => _gallery = !_gallery),
      },
      child: FocusScope(
        autofocus: true,
        child: ColoredBox(
          color: c.paper,
          child: Column(
            children: [
              VeTitleBar(
                appName: 'Vegas Encoder',
                nav: _nav,
                currentNav: section.index,
                onNav: _go,
                maximized: maximized,
                onDragStart: window.startDrag,
                onMinimize: window.minimize,
                onToggleMaximize: window.toggleMaximize,
                onClose: window.close,
              ),
              Expanded(
                child: _gallery
                    ? const GalleryPage()
                    : coreError != null
                    ? CoreUnavailable(error: coreError)
                    : switch (section) {
                        DesktopSection.presets => const PresetsPage(),
                        DesktopSection.ffmpeg => const FFmpegPage(),
                        DesktopSection.history => const HistoryPage(),
                        DesktopSection.settings => const SettingsPage(),
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CloseChoice { cancel, discard, save }
