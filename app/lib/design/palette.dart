import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// Signal Flow's colour tokens, light and dark.
///
/// Every value is the `:root` token of the same name in
/// `docs/product/design/signal-flow.html` (CSS name in each comment). The
/// presentation-only tokens (`--canvas`, `--pres-muted`) are left out.
@immutable
class VePalette {
  const VePalette({
    required this.paper,
    required this.dots,
    required this.surface,
    required this.surface2,
    required this.panel,
    required this.ink,
    required this.ink2,
    required this.inkHover,
    required this.onInk,
    required this.text2,
    required this.muted,
    required this.subText,
    required this.nodeText,
    required this.faint,
    required this.faintText,
    required this.line,
    required this.line2,
    required this.lineHover,
    required this.lineSoft,
    required this.fill,
    required this.fillHover,
    required this.fillSelected,
    required this.fillSelected2,
    required this.lit,
    required this.track,
    required this.knob,
    required this.videoWire,
    required this.videoText,
    required this.audioWire,
    required this.audioText,
    required this.pip,
    required this.onPip,
    required this.containerWire,
    required this.error,
    required this.errorBackground,
    required this.errorText,
    required this.errorLine,
    required this.warning,
    required this.warningBackground,
    required this.warningText,
    required this.warningWave,
    required this.success,
    required this.macro,
    required this.highlight,
    required this.amberLine,
    required this.bannerBackground,
    required this.pipLabelBackground,
    required this.pipLabelText,
    required this.favorite,
    required this.favoriteBackground,
    required this.videoTint,
    required this.audioTint,
    required this.containerTint,
    required this.selection,
    required this.legendBackground,
    required this.shadow,
    required this.lockBackground,
  });

  /// `--paper`: window background, diagram canvas.
  final Color paper;

  /// `--dots`: the diagram's grid dots.
  final Color dots;

  /// `--surface`: controls, nodes, panels.
  final Color surface;

  /// `--surface-2`: From VEGAS node, size card.
  final Color surface2;

  /// `--panel`: command column, popup side panel, footers.
  final Color panel;

  /// `--ink`: text, primary buttons, focus ring, selection outline.
  final Color ink;

  /// `--ink2`: secondary strong text (wire labels, locked chips).
  final Color ink2;

  /// `--ink-hover`: primary button hover.
  final Color inkHover;

  /// `--on-ink`: text on ink.
  final Color onInk;

  /// `--text2`: segment labels, legend, ranges.
  final Color text2;

  /// `--muted`: secondary text and icons.
  final Color muted;

  /// `--sub-text`: wire sub-labels.
  final Color subText;

  /// `--nd-text`: node detail lines.
  final Color nodeText;

  /// `--faint`: tick marks, chip borders.
  final Color faint;

  /// `--faint-text`: placeholders, tick labels, line numbers.
  final Color faintText;

  /// `--line`: dividers and quiet borders.
  final Color line;

  /// `--line2`: control borders.
  final Color line2;

  /// `--line-hover`: control border on hover.
  final Color lineHover;

  /// `--line-soft`: table row rules.
  final Color lineSoft;

  /// `--fill`: segmented track, hover fill, chips.
  final Color fill;

  /// `--fill-hover`: list row hover.
  final Color fillHover;

  /// `--fill-sel`: active option in a list.
  final Color fillSelected;

  /// `--fill-sel2`: selected library row, expanded chip, locked token.
  final Color fillSelected2;

  /// `--lit`: a field lit from the command.
  final Color lit;

  /// `--track`: slider and switch track.
  final Color track;

  /// `--knob`: switch knob.
  final Color knob;

  /// `--vw`: video wire, video role.
  final Color videoWire;

  /// `--vw-text`: video wire labels.
  final Color videoText;

  /// `--aw`: audio wire, audio role.
  final Color audioWire;

  /// `--aw-text`: audio wire labels.
  final Color audioText;

  /// `--pip`: pixel-format conversion pip, revision badge.
  final Color pip;

  /// `--on-pip`: text on the pip colour.
  final Color onPip;

  /// `--cont`: container wire, container and output roles.
  final Color containerWire;

  /// `--err`
  final Color error;

  /// `--errbg`
  final Color errorBackground;

  /// `--err-text`
  final Color errorText;

  /// `--err-line`
  final Color errorLine;

  /// `--warnt`: warning icon and text.
  final Color warning;

  /// `--warnbg`
  final Color warningBackground;

  /// `--warn-text`
  final Color warningText;

  /// `--warn-wave`: warning lint underline.
  final Color warningWave;

  /// `--ok`
  final Color success;

  /// `--macro`: Advanced-mode macros.
  final Color macro;

  /// `--hl`: tokens lit from a hovered control.
  final Color highlight;

  /// `--amber-line`: banner and pip label border.
  final Color amberLine;

  /// `--banner-bg`
  final Color bannerBackground;

  /// `--pipl-bg`
  final Color pipLabelBackground;

  /// `--pipl-text`
  final Color pipLabelText;

  /// `--fav`
  final Color favorite;

  /// `--fav-bg`
  final Color favoriteBackground;

  /// `--vwl`: video group tint in the command.
  final Color videoTint;

  /// `--awl`: audio group tint.
  final Color audioTint;

  /// `--contl`: container and output group tint.
  final Color containerTint;

  /// `--sel`: text selection.
  final Color selection;

  /// `--legend-bg`
  final Color legendBackground;

  /// `--shadow-rgb` as an opaque colour; shadows apply their own alpha.
  final Color shadow;

  /// `--lock-bg`: the lock badge on locked chips.
  final Color lockBackground;

  static const VePalette light = VePalette(
    paper: Color(0xFFF4F6F8),
    dots: Color(0xFFD9DEE4),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFBFCFD),
    panel: Color(0xFFFAFBFC),
    ink: Color(0xFF1F2933),
    ink2: Color(0xFF33404E),
    inkHover: Color(0xFF334150),
    onInk: Color(0xFFFFFFFF),
    text2: Color(0xFF4A5767),
    muted: Color(0xFF64748B),
    subText: Color(0xFF566476),
    nodeText: Color(0xFF3E4A59),
    faint: Color(0xFFA9B4C0),
    faintText: Color(0xFF7A8698),
    line: Color(0xFFD6DDE4),
    line2: Color(0xFFBCC6D1),
    lineHover: Color(0xFF8E9BAA),
    lineSoft: Color(0xFFEDF0F3),
    fill: Color(0xFFEEF1F4),
    fillHover: Color(0xFFF0F3F6),
    fillSelected: Color(0xFFEEF2F5),
    fillSelected2: Color(0xFFE6EBF0),
    lit: Color(0xFFF2F6F8),
    track: Color(0xFFC9D2DB),
    knob: Color(0xFFFFFFFF),
    videoWire: Color(0xFF0E7C86),
    videoText: Color(0xFF0B5F67),
    audioWire: Color(0xFFB5446E),
    audioText: Color(0xFF8E3456),
    pip: Color(0xFFE8A33D),
    onPip: Color(0xFF2B1D04),
    containerWire: Color(0xFF3E4C59),
    error: Color(0xFFB42318),
    errorBackground: Color(0xFFFDF0EE),
    errorText: Color(0xFF7A1A12),
    errorLine: Color(0xFFF1C6C0),
    warning: Color(0xFF8A5300),
    warningBackground: Color(0xFFFDF5E6),
    warningText: Color(0xFF5C3A00),
    warningWave: Color(0xFFC98A1B),
    success: Color(0xFF2E6B4F),
    macro: Color(0xFF5B4A8A),
    highlight: Color(0xFFFFE7B8),
    amberLine: Color(0xFFEDC17A),
    bannerBackground: Color(0xFFFFF8EA),
    pipLabelBackground: Color(0xFFFFF3DD),
    pipLabelText: Color(0xFF6B4100),
    favorite: Color(0xFFB7791F),
    favoriteBackground: Color(0xFFFFF7E6),
    videoTint: Color(0x1A0E7C86), // rgba(14,124,134,.1)
    audioTint: Color(0x17B5446E), // rgba(181,68,110,.09)
    containerTint: Color(0x173E4C59), // rgba(62,76,89,.09)
    selection: Color(0x380E7C86), // rgba(14,124,134,.22)
    legendBackground: Color(0xEBF4F6F8), // rgba(244,246,248,.92)
    shadow: Color(0xFF1F2933), // 31,41,51
    lockBackground: Color(0xFF33404E),
  );

  static const VePalette dark = VePalette(
    paper: Color(0xFF15191E),
    dots: Color(0xFF272D35),
    surface: Color(0xFF1D2228),
    surface2: Color(0xFF1A1F25),
    panel: Color(0xFF1A1F24),
    ink: Color(0xFFE6EAF0),
    ink2: Color(0xFFC9D1DB),
    inkHover: Color(0xFFFFFFFF),
    onInk: Color(0xFF11151A),
    text2: Color(0xFFAEB8C4),
    muted: Color(0xFF95A0AE),
    subText: Color(0xFF9AA5B2),
    nodeText: Color(0xFFB7C0CB),
    faint: Color(0xFF4B5562),
    faintText: Color(0xFF7F8A98),
    line: Color(0xFF2C333B),
    line2: Color(0xFF3A434E),
    lineHover: Color(0xFF5B6675),
    lineSoft: Color(0xFF252B32),
    fill: Color(0xFF262C34),
    fillHover: Color(0xFF242A31),
    fillSelected: Color(0xFF2A3139),
    fillSelected2: Color(0xFF2E363F),
    lit: Color(0xFF222930),
    track: Color(0xFF3C4550),
    knob: Color(0xFFC9D1DB),
    videoWire: Color(0xFF3DB6C1),
    videoText: Color(0xFF63CAD3),
    audioWire: Color(0xFFE0779D),
    audioText: Color(0xFFEC98B7),
    pip: Color(0xFFF0B04F),
    onPip: Color(0xFF2B1D04),
    containerWire: Color(0xFF8E9CAD),
    error: Color(0xFFFF7B70),
    errorBackground: Color(0xFF3A201E),
    errorText: Color(0xFFFFB3AA),
    errorLine: Color(0xFF5C2E29),
    warning: Color(0xFFF2B85A),
    warningBackground: Color(0xFF33290F),
    warningText: Color(0xFFF4D293),
    warningWave: Color(0xFFE0A43A),
    success: Color(0xFF5DC495),
    macro: Color(0xFFB9A7F2),
    highlight: Color(0xFF4D3B12),
    amberLine: Color(0xFF6E5420),
    bannerBackground: Color(0xFF2B2312),
    pipLabelBackground: Color(0xFF3B2C10),
    pipLabelText: Color(0xFFF6CF88),
    favorite: Color(0xFFE9B44C),
    favoriteBackground: Color(0xFF3A2E14),
    videoTint: Color(0x293DB6C1), // rgba(61,182,193,.16)
    audioTint: Color(0x26E0779D), // rgba(224,119,157,.15)
    containerTint: Color(0x248E9CAD), // rgba(142,156,173,.14)
    selection: Color(0x523DB6C1), // rgba(61,182,193,.32)
    legendBackground: Color(0xE615191E), // rgba(21,25,30,.9)
    shadow: Color(0xFF000000),
    lockBackground: Color(0xFF56606D),
  );

  static VePalette lerp(VePalette a, VePalette b, double t) {
    Color mix(Color Function(VePalette p) pick) => Color.lerp(pick(a), pick(b), t)!;
    return VePalette(
      paper: mix((p) => p.paper),
      dots: mix((p) => p.dots),
      surface: mix((p) => p.surface),
      surface2: mix((p) => p.surface2),
      panel: mix((p) => p.panel),
      ink: mix((p) => p.ink),
      ink2: mix((p) => p.ink2),
      inkHover: mix((p) => p.inkHover),
      onInk: mix((p) => p.onInk),
      text2: mix((p) => p.text2),
      muted: mix((p) => p.muted),
      subText: mix((p) => p.subText),
      nodeText: mix((p) => p.nodeText),
      faint: mix((p) => p.faint),
      faintText: mix((p) => p.faintText),
      line: mix((p) => p.line),
      line2: mix((p) => p.line2),
      lineHover: mix((p) => p.lineHover),
      lineSoft: mix((p) => p.lineSoft),
      fill: mix((p) => p.fill),
      fillHover: mix((p) => p.fillHover),
      fillSelected: mix((p) => p.fillSelected),
      fillSelected2: mix((p) => p.fillSelected2),
      lit: mix((p) => p.lit),
      track: mix((p) => p.track),
      knob: mix((p) => p.knob),
      videoWire: mix((p) => p.videoWire),
      videoText: mix((p) => p.videoText),
      audioWire: mix((p) => p.audioWire),
      audioText: mix((p) => p.audioText),
      pip: mix((p) => p.pip),
      onPip: mix((p) => p.onPip),
      containerWire: mix((p) => p.containerWire),
      error: mix((p) => p.error),
      errorBackground: mix((p) => p.errorBackground),
      errorText: mix((p) => p.errorText),
      errorLine: mix((p) => p.errorLine),
      warning: mix((p) => p.warning),
      warningBackground: mix((p) => p.warningBackground),
      warningText: mix((p) => p.warningText),
      warningWave: mix((p) => p.warningWave),
      success: mix((p) => p.success),
      macro: mix((p) => p.macro),
      highlight: mix((p) => p.highlight),
      amberLine: mix((p) => p.amberLine),
      bannerBackground: mix((p) => p.bannerBackground),
      pipLabelBackground: mix((p) => p.pipLabelBackground),
      pipLabelText: mix((p) => p.pipLabelText),
      favorite: mix((p) => p.favorite),
      favoriteBackground: mix((p) => p.favoriteBackground),
      videoTint: mix((p) => p.videoTint),
      audioTint: mix((p) => p.audioTint),
      containerTint: mix((p) => p.containerTint),
      selection: mix((p) => p.selection),
      legendBackground: mix((p) => p.legendBackground),
      shadow: mix((p) => p.shadow),
      lockBackground: mix((p) => p.lockBackground),
    );
  }

  // UI_SPEC §10 role names: what part of the command a thing belongs to.
  Color get roleInput => muted;
  Color get roleVideo => videoWire;
  Color get roleAudio => audioWire;
  Color get roleContainer => containerWire;
  Color get roleOutput => containerWire;
  Color get roleExtra => warning;
  Color get focus => ink;
}
