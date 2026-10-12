import 'package:flutter/material.dart';

import 'tokens.dart';

/// ThemeData that carries [VeTokens]. The app draws its own components; the
/// Material parts kept here (text selection, scrollbars, tooltips) are tuned so
/// nothing of the Material look shows through.
ThemeData buildVeTheme(VeTokens tokens) {
  final c = tokens.colors;
  final dark = tokens.brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: tokens.brightness,
    primary: c.ink,
    onPrimary: c.onInk,
    secondary: c.videoWire,
    onSecondary: c.onInk,
    error: c.error,
    onError: c.onInk,
    surface: c.surface,
    onSurface: c.ink,
    outline: c.line2,
    outlineVariant: c.line,
  );
  return ThemeData(
    // Windows x64 only; also makes widget tests behave as the product does.
    platform: TargetPlatform.windows,
    brightness: tokens.brightness,
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: VeFonts.ui,
    fontFamilyFallback: VeFonts.fallback,
    scaffoldBackgroundColor: c.paper,
    canvasColor: c.paper,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.ink,
      selectionColor: c.selection,
      selectionHandleColor: c.ink,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStatePropertyAll(c.line2.withValues(alpha: dark ? 0.9 : 0.8)),
      crossAxisMargin: 2,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(VeRadius.md)),
      textStyle: tokens.text.small.copyWith(color: c.onInk),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      waitDuration: const Duration(milliseconds: 500),
    ),
    extensions: [tokens],
  );
}
