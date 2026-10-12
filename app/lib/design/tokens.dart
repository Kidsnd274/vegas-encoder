import 'package:flutter/material.dart';

import 'palette.dart';

export 'palette.dart';

/// Font families bundled in `assets/fonts` (OFL).
abstract final class VeFonts {
  static const String ui = 'Instrument Sans';
  static const String mono = 'JetBrains Mono';

  /// Used when a glyph is missing from the bundled fonts, such as CJK names.
  static const List<String> fallback = ['Segoe UI Variable Text', 'Segoe UI'];
  static const List<String> monoFallback = ['Cascadia Mono', 'Consolas'];
}

/// The type scale from `signal-flow.html`. Sizes are CSS pixels, which map 1:1
/// to Flutter logical pixels. Every style carries `ink`; components change the
/// colour where the mockup does.
@immutable
class VeTextStyles {
  const VeTextStyles({
    required this.body,
    required this.bodyStrong,
    required this.small,
    required this.smallStrong,
    required this.caption,
    required this.captionStrong,
    required this.micro,
    required this.label,
    required this.button,
    required this.buttonSmall,
    required this.panelTitle,
    required this.popupTitle,
    required this.pageTitle,
    required this.headline,
    required this.nodeTitle,
    required this.figure,
    required this.display,
    required this.mono,
    required this.monoSmall,
    required this.monoEditor,
  });

  factory VeTextStyles.of(VePalette c) {
    const features = [FontFeature.tabularFigures()];
    TextStyle ui(double size, int weight, {double height = 1.45, double tracking = 0}) => TextStyle(
      inherit: false,
      fontFamily: VeFonts.ui,
      fontFamilyFallback: VeFonts.fallback,
      fontSize: size,
      fontWeight: FontWeight(weight),
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: tracking * size,
      color: c.ink,
      fontFeatures: features,
      textBaseline: TextBaseline.alphabetic,
      decoration: TextDecoration.none,
    );
    TextStyle mono(double size, {double height = 1.7}) => TextStyle(
      inherit: false,
      fontFamily: VeFonts.mono,
      fontFamilyFallback: VeFonts.monoFallback,
      fontSize: size,
      fontWeight: const FontWeight(400),
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
      color: c.ink,
      textBaseline: TextBaseline.alphabetic,
      decoration: TextDecoration.none,
    );
    return VeTextStyles(
      body: ui(13, 400),
      bodyStrong: ui(13, 600),
      small: ui(12.5, 400, height: 1.4),
      smallStrong: ui(12.5, 600, height: 1.4),
      caption: ui(12, 400, height: 1.35),
      captionStrong: ui(12, 600, height: 1.35),
      micro: ui(11.5, 500, height: 1.3),
      label: ui(13, 600),
      button: ui(13, 550, height: 1.2),
      buttonSmall: ui(12.5, 550, height: 1.2),
      panelTitle: ui(15, 650, height: 1.3),
      popupTitle: ui(18, 650, height: 1.25),
      pageTitle: ui(19, 650, height: 1.2),
      headline: ui(22, 650, height: 1.2, tracking: -0.01),
      nodeTitle: ui(17, 650, height: 1.25, tracking: -0.005),
      figure: ui(26, 650, height: 1.15, tracking: -0.01),
      display: ui(34, 650, height: 1.15, tracking: -0.015),
      mono: mono(12.5),
      monoSmall: mono(12, height: 1.55),
      monoEditor: mono(14, height: 23 / 14),
    );
  }

  /// 13 px, the base inside app windows (`.frame`).
  final TextStyle body;
  final TextStyle bodyStrong;

  /// 12.5 px: read-outs, blurbs, messages.
  final TextStyle small;
  final TextStyle smallStrong;

  /// 12 px: node labels, legends, group headers.
  final TextStyle caption;
  final TextStyle captionStrong;

  /// 11.5 px: tags, keycaps, marks.
  final TextStyle micro;

  /// Field label (`.fh .l`).
  final TextStyle label;
  final TextStyle button;
  final TextStyle buttonSmall;

  /// Inspector heading (`.ip-h h2`).
  final TextStyle panelTitle;

  /// Popup template name (`.pp-head h1`).
  final TextStyle popupTitle;

  /// Editor preset name (`.head h1`).
  final TextStyle pageTitle;

  /// Page heading and the estimate (`.ffh h1`, `.est b`).
  final TextStyle headline;

  /// Node name (`.node .nt`).
  final TextStyle nodeTitle;

  /// Progress percentage (`.pct b`).
  final TextStyle figure;

  /// Size estimate (`.szc .big`).
  final TextStyle display;

  /// Command text (`.cmd`).
  final TextStyle mono;
  final TextStyle monoSmall;

  /// Advanced-mode editor, 14/23 px.
  final TextStyle monoEditor;

  static VeTextStyles lerp(VeTextStyles a, VeTextStyles b, double t) {
    TextStyle mix(TextStyle Function(VeTextStyles s) pick) => TextStyle.lerp(pick(a), pick(b), t)!;
    return VeTextStyles(
      body: mix((s) => s.body),
      bodyStrong: mix((s) => s.bodyStrong),
      small: mix((s) => s.small),
      smallStrong: mix((s) => s.smallStrong),
      caption: mix((s) => s.caption),
      captionStrong: mix((s) => s.captionStrong),
      micro: mix((s) => s.micro),
      label: mix((s) => s.label),
      button: mix((s) => s.button),
      buttonSmall: mix((s) => s.buttonSmall),
      panelTitle: mix((s) => s.panelTitle),
      popupTitle: mix((s) => s.popupTitle),
      pageTitle: mix((s) => s.pageTitle),
      headline: mix((s) => s.headline),
      nodeTitle: mix((s) => s.nodeTitle),
      figure: mix((s) => s.figure),
      display: mix((s) => s.display),
      mono: mix((s) => s.mono),
      monoSmall: mix((s) => s.monoSmall),
      monoEditor: mix((s) => s.monoEditor),
    );
  }
}

/// Spacing scale (UI_SPEC §10): 4, 8, 12, 16, 24, 32.
abstract final class VeSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
}

/// Corner radii used by the mockup.
abstract final class VeRadius {
  /// Command tokens, small chips.
  static const double xs = 3;

  /// Segment buttons, chips, message rows (5–6 px in the mockup).
  static const double sm = 5;

  /// Buttons, inputs, selects.
  static const double md = 6;

  /// Command box, cards inside panels, popovers.
  static const double lg = 8;

  /// Nodes, cards, the size card.
  static const double xl = 10;
}

/// Durations. Components ask [VeTokens.motion] so reduced motion zeroes them.
abstract final class VeDurations {
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);

  /// Wire thickness changes (`.wire` transition).
  static const Duration wire = Duration(milliseconds: 400);

  /// cubic-bezier(.2,.7,.2,1)
  static const Curve wireCurve = Cubic(0.2, 0.7, 0.2, 1);
}

/// Vegas Encoder's design tokens, registered on [ThemeData.extensions].
@immutable
class VeTokens extends ThemeExtension<VeTokens> {
  const VeTokens({required this.brightness, required this.colors, required this.text});

  factory VeTokens.forBrightness(Brightness brightness) {
    final colors = brightness == Brightness.dark ? VePalette.dark : VePalette.light;
    return VeTokens(brightness: brightness, colors: colors, text: VeTextStyles.of(colors));
  }

  static final VeTokens light = VeTokens.forBrightness(Brightness.light);
  static final VeTokens dark = VeTokens.forBrightness(Brightness.dark);

  final Brightness brightness;
  final VePalette colors;
  final VeTextStyles text;

  static VeTokens of(BuildContext context) => Theme.of(context).extension<VeTokens>() ?? VeTokens.light;

  /// [d], or zero when Windows "Animation effects" is off (UI_SPEC §9).
  static Duration motion(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;

  /// `rgba(var(--shadow-rgb), a)`.
  Color shadow(double alpha) => colors.shadow.withValues(alpha: alpha);

  /// Raised node and selected card: `0 6px 16px -6px rgba(shadow,.35)`.
  List<BoxShadow> get raisedShadow => [
    BoxShadow(color: shadow(0.35), offset: const Offset(0, 6), blurRadius: 16, spreadRadius: -6),
  ];

  /// Resting node: `0 1px 2px rgba(shadow,.06)`.
  List<BoxShadow> get restingShadow => [BoxShadow(color: shadow(0.06), offset: const Offset(0, 1), blurRadius: 2)];

  /// Pressed segment: `0 1px 2px rgba(.18), 0 0 0 1px rgba(.06)`.
  List<BoxShadow> get segmentShadow => [
    BoxShadow(color: shadow(0.18), offset: const Offset(0, 1), blurRadius: 2),
    BoxShadow(color: shadow(0.06), spreadRadius: 1),
  ];

  /// Popovers and menus: `0 16px 34px -8px rgba(shadow,.35)`.
  List<BoxShadow> get popoverShadow => [
    BoxShadow(color: shadow(0.35), offset: const Offset(0, 16), blurRadius: 34, spreadRadius: -8),
  ];

  /// Toasts: `0 10px 24px rgba(shadow,.35)`.
  List<BoxShadow> get toastShadow => [BoxShadow(color: shadow(0.35), offset: const Offset(0, 10), blurRadius: 24)];

  @override
  VeTokens copyWith({VePalette? colors, VeTextStyles? text}) =>
      VeTokens(brightness: brightness, colors: colors ?? this.colors, text: text ?? this.text);

  @override
  VeTokens lerp(covariant VeTokens? other, double t) {
    if (other == null) return this;
    return VeTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      colors: VePalette.lerp(colors, other.colors, t),
      text: VeTextStyles.lerp(text, other.text, t),
    );
  }
}

/// Shorthands for widgets.
extension VeTokensContext on BuildContext {
  VeTokens get ve => VeTokens.of(this);
  VePalette get veColors => VeTokens.of(this).colors;
  VeTextStyles get veText => VeTokens.of(this).text;
}
