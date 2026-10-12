import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/button.dart';
import '../../design/components/dialog.dart';
import '../../design/components/title_bar.dart';
import '../../design/tokens.dart';
import '../../state/app_state.dart';
import '../../state/presets.dart';
import '../../state/services.dart';
import '../gallery/gallery_page.dart';
import '../presets/presets_page.dart';

/// The desktop window: title bar with Presets, FFmpeg, History and Settings.
/// FFmpeg, History and Settings say which milestone builds them. In debug
/// builds Ctrl+Shift+D shows the design system gallery (F1).
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  int _section = 0;
  bool _gallery = false;

  static const _nav = [
    VeNavItem('Presets', shortcut: 'Ctrl+1'),
    VeNavItem('FFmpeg', shortcut: 'Ctrl+2'),
    VeNavItem('History', shortcut: 'Ctrl+3'),
    VeNavItem('Settings', shortcut: 'Ctrl+4'),
  ];

  void _go(int i) => setState(() {
    _section = i;
    _gallery = false;
  });

  /// Close asks first when presets have unsaved changes (UI_SPEC §2).
  Future<void> _close() async {
    final window = ref.read(windowControllerProvider);
    final drafts = ref.read(presetsControllerProvider).drafts;
    if (drafts.isEmpty) return window.close();
    final presets = ref.read(presetsProvider).value ?? const [];
    final names = [
      for (final id in drafts.keys) presets.where((p) => p.recipe.id == id).firstOrNull?.recipe.name ?? id,
    ];
    final one = names.length == 1;
    final choice = await showVeDialog<_CloseChoice>(
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
    if (choice == _CloseChoice.discard) return window.close();
    if (choice != _CloseChoice.save) return;
    final controller = ref.read(presetsControllerProvider.notifier);
    for (final id in drafts.keys.toList()) {
      if (await controller.save(id: id) == SaveOutcome.conflict) {
        // Changed in another window: stay open on that preset so the user decides.
        controller.select(id);
        return;
      }
    }
    await window.close();
  }

  @override
  Widget build(BuildContext context) {
    final window = ref.watch(windowControllerProvider);
    final maximized = ref.watch(windowStateProvider.select((s) => s.maximized));
    final c = VeTokens.of(context).colors;

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
                currentNav: _section,
                onNav: _go,
                maximized: maximized,
                onDragStart: window.startDrag,
                onMinimize: window.minimize,
                onToggleMaximize: window.toggleMaximize,
                onClose: _close,
              ),
              Expanded(
                child: _gallery
                    ? const GalleryPage()
                    : switch (_section) {
                        0 => const PresetsPage(),
                        1 => const _Pending(title: 'FFmpeg', milestone: 'F3'),
                        2 => const _Pending(title: 'History', milestone: 'F3'),
                        _ => const _Pending(title: 'Settings', milestone: 'F3'),
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

class _Pending extends StatelessWidget {
  const _Pending({required this.title, required this.milestone});
  final String title;
  final String milestone;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: t.text.headline),
          const SizedBox(height: 6),
          Text('This screen is built in milestone $milestone.', style: t.text.small.copyWith(color: t.colors.text2)),
        ],
      ),
    );
  }
}
