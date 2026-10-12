import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../tokens.dart';
import 'interactive.dart';

/// One section in the desktop title bar (`.nav`).
@immutable
class VeNavItem {
  const VeNavItem(this.label, {this.shortcut});
  final String label;

  /// Shown in the tooltip, such as "Ctrl+1".
  final String? shortcut;
}

/// The app-drawn title bar (`.tb`). The window has no system caption; this bar
/// moves it (drag), maximizes it (double-click) and carries the window buttons.
class VeTitleBar extends StatelessWidget {
  const VeTitleBar({
    super.key,
    this.height = 40,
    this.appName,
    this.title,
    this.nav = const [],
    this.currentNav = 0,
    this.onNav,
    this.trailing = const [],
    this.maximized = false,
    this.onDragStart,
    this.onMinimize,
    this.onToggleMaximize,
    required this.onClose,
    this.closeLabel = 'Close',
  });

  /// 40 px on the desktop, 34 px in the popup and the progress window.
  final double height;

  /// "Vegas Encoder" beside the logo (desktop only).
  final String? appName;

  /// Window title text (popup and progress window).
  final Widget? title;
  final List<VeNavItem> nav;
  final int currentNav;
  final ValueChanged<int>? onNav;

  /// Extra buttons before the window controls, such as the progress window's pin.
  final List<Widget> trailing;
  final bool maximized;
  final VoidCallback? onDragStart;
  final VoidCallback? onMinimize;
  final VoidCallback? onToggleMaximize;
  final VoidCallback onClose;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: onDragStart == null ? null : (_) => onDragStart!(),
              onDoubleTap: onToggleMaximize,
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 14),
              const VeLogo(),
              if (appName != null) ...[
                const SizedBox(width: 9),
                Text(appName!, style: t.text.caption.copyWith(color: c.muted)),
                const SizedBox(width: 20),
              ] else
                const SizedBox(width: 9),
              if (title != null)
                Flexible(
                  child: DefaultTextStyle(
                    style: t.text.caption.copyWith(color: c.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: title!,
                  ),
                ),
              if (nav.isNotEmpty)
                Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: 'Sections',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < nav.length; i++)
                        _NavButton(
                          item: nav[i],
                          current: i == currentNav,
                          onTap: onNav == null ? null : () => onNav!(i),
                        ),
                    ],
                  ),
                ),
              const Spacer(),
              ...trailing,
              if (onMinimize != null) _WindowButton(icon: VeIcons.minimize, label: 'Minimize', onTap: onMinimize!),
              if (onToggleMaximize != null)
                _WindowButton(
                  icon: maximized ? VeIcons.restore : VeIcons.maximize,
                  label: maximized ? 'Restore' : 'Maximize',
                  onTap: onToggleMaximize!,
                ),
              _WindowButton(icon: VeIcons.close, label: closeLabel, onTap: onClose, isClose: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.current, required this.onTap});
  final VeNavItem item;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Semantics(
      button: true,
      selected: current,
      label: item.label,
      hint: item.shortcut,
      child: VeInteractive(
        onTap: onTap,
        builder: (context, s) => VeFocusRing(
          visible: s.focused,
          radius: 4,
          offset: -3,
          child: SizedBox(
            height: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: Center(
                    child: Text(
                      item.label,
                      style: t.text.body.copyWith(
                        color: current || s.hovered ? c.ink : c.muted,
                        fontWeight: FontWeight(current ? 600 : 400),
                      ),
                    ),
                  ),
                ),
                if (current)
                  // `::after{left:13px;right:13px;bottom:-1px;height:2px}`, over the border.
                  Positioned(
                    left: 13,
                    right: 13,
                    bottom: -1,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({required this.icon, required this.label, required this.onTap, this.isClose = false});
  final VeIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isClose;

  // Windows caption-button close colours.
  static const Color _closeHover = Color(0xFFC42B1C);
  static const Color _closePressed = Color(0xFFC83C31);

  @override
  Widget build(BuildContext context) {
    final c = VeTokens.of(context).colors;
    return Semantics(
      button: true,
      label: label,
      child: VeInteractive(
        onTap: onTap,
        canRequestFocus: false,
        builder: (context, s) {
          Color bg = const Color(0x00000000);
          Color fg = c.ink;
          if (isClose && (s.hovered || s.pressed)) {
            bg = s.pressed ? _closePressed : _closeHover;
            fg = const Color(0xFFFFFFFF);
          } else if (s.pressed) {
            bg = c.fillSelected2;
          } else if (s.hovered) {
            bg = c.fill;
          }
          return Container(
            width: 46,
            color: bg,
            alignment: Alignment.center,
            child: VeIcon(icon, color: fg),
          );
        },
      ),
    );
  }
}
