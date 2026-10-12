import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/title_bar.dart';
import '../../design/tokens.dart';
import '../../state/app_state.dart';
import '../gallery/gallery_page.dart';

/// The desktop window: title bar with Presets, FFmpeg, History and Settings.
/// Until F2/F3 the Presets section shows the design system gallery and the
/// others say which milestone builds them.
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  int _section = 0;

  static const _nav = [
    VeNavItem('Presets', shortcut: 'Ctrl+1'),
    VeNavItem('FFmpeg', shortcut: 'Ctrl+2'),
    VeNavItem('History', shortcut: 'Ctrl+3'),
    VeNavItem('Settings', shortcut: 'Ctrl+4'),
  ];

  void _go(int i) => setState(() => _section = i);

  @override
  Widget build(BuildContext context) {
    final window = ref.watch(windowControllerProvider);
    final maximized = ref.watch(windowStateProvider.select((s) => s.maximized));
    final c = VeTokens.of(context).colors;

    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i < _nav.length; i++)
          SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), control: true): () => _go(i),
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
                onClose: window.close,
              ),
              Expanded(
                child: switch (_section) {
                  0 => const GalleryPage(),
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
