import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart' show DesktopRoute, DesktopWindowBounds, ServiceException;

import '../../app/launch.dart';
import '../../design/components/button.dart';
import '../../design/components/dialog.dart';
import '../../design/components/title_bar.dart';
import '../../design/tokens.dart';
import '../../state/app_state.dart';
import '../../state/desktop_interaction.dart';
import '../../state/desktop_routes.dart';
import '../../state/presets.dart';
import '../../state/services.dart';
import '../../state/ui_state.dart';
import '../ffmpeg/ffmpeg_page.dart';
import '../gallery/gallery_page.dart';
import '../history/history_page.dart';
import '../presets/presets_page.dart';
import '../presets/save_check.dart';
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
  StreamSubscription<DesktopRoute>? _routes;
  Future<void> _routeWork = Future.value();
  final Completer<void> _routeStop = Completer<void>();

  @override
  void initState() {
    super.initState();
    _lifecycle;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_startRoutes()));
  }

  @override
  void dispose() {
    _routeStop.complete();
    unawaited(_routes?.cancel());
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _startRoutes() async {
    if (!mounted) return;
    final source = ref.read(desktopRouteSourceProvider);
    _routes = source.changes.listen(_queueRoute);
    final mode = ref.read(launchModeProvider);
    if (mode is DesktopLaunch) {
      if (mode.route case final route?) _queueRoute(route);
      if (mode.error case final error?) unawaited(_routeError(error));
    }
    for (final route in await source.start()) {
      if (!mounted) return;
      _queueRoute(route);
    }
  }

  void _queueRoute(DesktopRoute route) {
    _routeWork = _routeWork.then((_) async {
      if (!mounted) return;
      final gate = ref.read(desktopInteractionProvider);
      Future<bool> idle() => gate.waitUntilIdle(cancelled: _routeStop.future);
      if (!await idle() || !mounted) return;
      final container = ProviderScope.containerOf(context, listen: false);
      String? error;
      try {
        error = await openDesktopRoute(container, route, isMounted: () => mounted, beforeApply: idle);
      } on Object {
        error = 'Vegas Encoder couldn’t read the requested item. Try opening it from the library or History.';
      }
      if (!mounted) return;
      if (error != null) {
        await _routeError(error);
      } else {
        setState(() => _gallery = false);
        unawaited(ref.read(windowControllerProvider).trace('desktop_route_applied ${route.kind} ${route.id}'));
      }
    });
  }

  Future<void> _routeError(String message) async {
    if (!mounted) return;
    if (!await ref.read(desktopInteractionProvider).waitUntilIdle(cancelled: _routeStop.future) || !mounted) return;
    await showVeDialog<void>(
      context,
      title: 'Couldn’t open the requested item',
      message: message,
      actions: const [VeDialogAction('OK', null, variant: VeButtonVariant.primary)],
    );
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

  Future<AppExitResponse> _onExitRequested() => ref.read(desktopInteractionProvider).run(_onExitGuarded);

  Future<AppExitResponse> _onExitGuarded() async {
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
      // A draft whose settings have errors isn't saved (owner decision,
      // 2026-10-15): say why and stay open on it.
      final recipe = controller.working(id);
      final errors = recipe == null ? null : saveErrors(ref.read(veCoreProvider), recipe, const []);
      if (recipe != null && errors!.settings.isNotEmpty) {
        controller.select(id);
        if (mounted) {
          await checkSave(context, name: recipe.name, settings: errors.settings, ffmpeg: const [], installation: '');
        }
        return AppExitResponse.cancel;
      }
      final SaveOutcome outcome;
      try {
        outcome = await controller.save(id: id);
      } on ServiceException catch (e) {
        // The library refused it: stay open on that preset and say why.
        controller.select(id);
        if (mounted) {
          final name = presets.where((p) => p.recipe.id == id).firstOrNull?.recipe.name ?? id;
          await showVeDialog<void>(
            context,
            title: 'Couldn’t save “$name”',
            message: '${e.message} Vegas Encoder stays open so you can fix it or close without saving.',
            actions: const [VeDialogAction('OK', null, variant: VeButtonVariant.primary)],
          );
        }
        return AppExitResponse.cancel;
      }
      if (outcome == SaveOutcome.conflict) {
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
