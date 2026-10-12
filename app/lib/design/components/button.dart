import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../tokens.dart';
import 'interactive.dart';

enum VeButtonVariant {
  /// `.btn`: surface with a border.
  secondary,

  /// `.btn.primary`: ink fill, one per view.
  primary,

  /// `.btn.ghost`: no border until hovered.
  ghost,
}

enum VeButtonSize {
  /// 32 px tall.
  regular,

  /// `.btn.sm`, 28 px tall.
  small,
}

/// A text button with an optional leading icon. Labels say what happens
/// ("Save preset", "Apply to template").
class VeButton extends StatelessWidget {
  const VeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = VeButtonVariant.secondary,
    this.size = VeButtonSize.regular,
    this.icon,
    this.trailingIcon,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final VeButtonVariant variant;
  final VeButtonSize size;
  final VeIconData? icon;
  final VeIconData? trailingIcon;

  /// Shown on hover; used for the reason a button is disabled.
  final String? tooltip;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final enabled = onPressed != null;
    final small = size == VeButtonSize.small;

    Widget button = VeInteractive(
      enabled: enabled,
      onTap: onPressed,
      focusNode: focusNode,
      autofocus: autofocus,
      builder: (context, s) {
        Color background;
        Color border;
        Color foreground;
        switch (variant) {
          case VeButtonVariant.primary:
            background = s.hovered ? c.inkHover : c.ink;
            border = background;
            foreground = c.onInk;
          case VeButtonVariant.secondary:
            background = s.hovered ? c.fill : c.surface;
            border = c.line2;
            foreground = c.ink;
          case VeButtonVariant.ghost:
            background = s.hovered ? c.fill : const Color(0x00000000);
            border = const Color(0x00000000);
            foreground = s.hovered ? c.ink : c.muted;
        }
        final style = (small ? t.text.buttonSmall : t.text.button).copyWith(color: foreground);
        return VeFocusRing(
          visible: s.focused,
          child: VeDisabled(
            disabled: !enabled,
            child: AnimatedContainer(
              duration: VeTokens.motion(context, const Duration(milliseconds: 100)),
              height: small ? 28 : 32,
              padding: EdgeInsets.symmetric(horizontal: small ? 9 : 12),
              decoration: BoxDecoration(
                color: background,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(VeRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[VeIcon(icon!, color: foreground), const SizedBox(width: 7)],
                  Text(label, style: style, maxLines: 1, softWrap: false),
                  if (trailingIcon != null) ...[const SizedBox(width: 5), VeIcon(trailingIcon!, color: foreground)],
                ],
              ),
            ),
          ),
        );
      },
    );

    button = Semantics(button: true, enabled: enabled, label: semanticLabel ?? label, child: button);
    if (tooltip != null) button = VeTooltip(message: tooltip!, child: button);
    return button;
  }
}

/// A square icon-only button: favorites star, Favorites-only filter, the
/// progress window's pin. [selected] uses [selectedColor].
class VeIconButton extends StatelessWidget {
  const VeIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.selectedIcon,
    this.selectedColor,
    this.selectedBackground,
    this.bordered = false,
    this.dimension = 32,
    this.iconSize,
  });

  final VeIconData icon;
  final VeIconData? selectedIcon;

  /// Accessible name; also the tooltip.
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final Color? selectedColor;
  final Color? selectedBackground;
  final bool bordered;
  final double dimension;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final c = VeTokens.of(context).colors;
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      child: VeTooltip(
        message: label,
        child: VeInteractive(
          enabled: onPressed != null,
          onTap: onPressed,
          builder: (context, s) {
            final fg = selected ? (selectedColor ?? c.ink) : (s.hovered ? c.ink : c.muted);
            final bg = selected && selectedBackground != null
                ? selectedBackground!
                : bordered
                ? c.surface
                : (s.hovered ? c.fill : const Color(0x00000000));
            return VeFocusRing(
              visible: s.focused,
              child: Container(
                width: dimension,
                height: dimension,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(bordered ? 7 : 5),
                  border: bordered ? Border.all(color: c.line2) : null,
                ),
                child: VeIcon(selected && selectedIcon != null ? selectedIcon! : icon, color: fg, size: iconSize),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// `.lnk`: an underlined text action such as "Show setting".
class VeLinkButton extends StatelessWidget {
  const VeLinkButton({super.key, required this.label, required this.onPressed, this.style});

  final String label;
  final VoidCallback? onPressed;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Semantics(
      button: true,
      label: label,
      child: VeInteractive(
        onTap: onPressed,
        enabled: onPressed != null,
        builder: (context, s) => VeFocusRing(
          visible: s.focused,
          radius: 2,
          child: Text(
            label,
            style: (style ?? t.text.small).copyWith(
              color: t.colors.ink,
              decoration: TextDecoration.underline,
              decorationColor: s.hovered ? t.colors.ink : t.colors.faint,
            ),
          ),
        ),
      ),
    );
  }
}

/// `kbd`: a key cap in hints such as "Ctrl Space suggestions".
class VeKbd extends StatelessWidget {
  const VeKbd(this.keyName, {super.key});
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: t.colors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          top: BorderSide(color: t.colors.line2),
          left: BorderSide(color: t.colors.line2),
          right: BorderSide(color: t.colors.line2),
          bottom: BorderSide(color: t.colors.line2, width: 2),
        ),
      ),
      child: Text(
        keyName,
        style: t.text.micro.copyWith(color: t.colors.muted, fontWeight: const FontWeight(400), height: 17 / 11.5),
      ),
    );
  }
}

/// A tooltip in the app's style (ink box, on-ink text; see `buildVeTheme`),
/// shown on hover after a short wait.
class VeTooltip extends StatelessWidget {
  const VeTooltip({super.key, required this.message, required this.child});
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(message: message, excludeFromSemantics: true, child: child);
  }
}
