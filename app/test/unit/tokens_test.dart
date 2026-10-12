import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/design/theme.dart';
import 'package:vegas_encoder/design/tokens.dart';

double _luminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('tokens are the mockup :root values', () {
    expect(VePalette.light.paper, const Color(0xFFF4F6F8));
    expect(VePalette.dark.paper, const Color(0xFF15191E));
    expect(VePalette.light.videoWire, const Color(0xFF0E7C86));
    expect(VePalette.dark.videoWire, const Color(0xFF3DB6C1));
    expect(VePalette.light.pip, const Color(0xFFE8A33D));
    expect(VePalette.dark.audioWire, const Color(0xFFE0779D));
    // rgba(14,124,134,.1)
    expect(VePalette.light.videoTint.a, closeTo(0.1, 0.005));
  });

  test('both token sets register on ThemeData and lerp', () {
    final light = buildVeTheme(VeTokens.light);
    final dark = buildVeTheme(VeTokens.dark);
    expect(light.extension<VeTokens>()!.colors.ink, VePalette.light.ink);
    expect(dark.extension<VeTokens>()!.colors.ink, VePalette.dark.ink);
    expect(dark.brightness, Brightness.dark);
    final mid = VeTokens.light.lerp(VeTokens.dark, 0.5);
    expect(mid.colors.paper, Color.lerp(VePalette.light.paper, VePalette.dark.paper, 0.5));
    expect(VeTokens.light.lerp(null, 0.5), same(VeTokens.light));
  });

  // UI_SPEC §9: text ≥ 4.5:1, UI glyphs ≥ 3:1, checked in both themes. These are
  // the pairs the components draw. Known shortfalls of the mockup tokens are
  // listed separately and reported in docs/product/workstreams/app.md.
  final textPairs = <String, (Color Function(VePalette), Color Function(VePalette))>{
    'ink on paper': ((p) => p.ink, (p) => p.paper),
    'ink on surface': ((p) => p.ink, (p) => p.surface),
    'ink on fill (segments)': ((p) => p.ink, (p) => p.fill),
    'text2 on fill (segments)': ((p) => p.text2, (p) => p.fill),
    'text2 on paper': ((p) => p.text2, (p) => p.paper),
    'muted on surface': ((p) => p.muted, (p) => p.surface),
    'muted on panel': ((p) => p.muted, (p) => p.panel),
    'muted on surface-2': ((p) => p.muted, (p) => p.surface2),
    'node text on surface': ((p) => p.nodeText, (p) => p.surface),
    'sub-text on paper (wire notes)': ((p) => p.subText, (p) => p.paper),
    'video label on paper': ((p) => p.videoText, (p) => p.paper),
    'audio label on paper': ((p) => p.audioText, (p) => p.paper),
    'container label on paper': ((p) => p.containerWire, (p) => p.paper),
    'error text on error row': ((p) => p.errorText, (p) => p.errorBackground),
    'warning text on warning row': ((p) => p.warningText, (p) => p.warningBackground),
    'pip label': ((p) => p.pipLabelText, (p) => p.pipLabelBackground),
    'revision badge': ((p) => p.onPip, (p) => p.pip),
    'primary button': ((p) => p.onInk, (p) => p.ink),
    'status error': ((p) => p.error, (p) => p.surface),
    'status warning': ((p) => p.warning, (p) => p.surface),
    'status ready': ((p) => p.success, (p) => p.surface),
  };

  final glyphPairs = <String, (Color Function(VePalette), Color Function(VePalette))>{
    'focus ring on surface': ((p) => p.focus, (p) => p.surface),
    'focus ring on paper': ((p) => p.focus, (p) => p.paper),
    'video wire on paper': ((p) => p.videoWire, (p) => p.paper),
    'audio wire on paper': ((p) => p.audioWire, (p) => p.paper),
    'container wire on paper': ((p) => p.containerWire, (p) => p.paper),
    'error icon on error row': ((p) => p.error, (p) => p.errorBackground),
    'warning icon on warning row': ((p) => p.warning, (p) => p.warningBackground),
    'muted icon on surface': ((p) => p.muted, (p) => p.surface),
  };

  for (final (name, palette) in [('light', VePalette.light), ('dark', VePalette.dark)]) {
    group('$name contrast', () {
      textPairs.forEach((label, pair) {
        test('text: $label ≥ 4.5', () {
          expect(contrast(pair.$1(palette), pair.$2(palette)), greaterThanOrEqualTo(4.5));
        });
      });
      glyphPairs.forEach((label, pair) {
        test('glyph: $label ≥ 3', () {
          expect(contrast(pair.$1(palette), pair.$2(palette)), greaterThanOrEqualTo(3));
        });
      });
    });
  }

  test('known shortfalls of the light tokens, kept as measured (owner decision)', () {
    final p = VePalette.light;
    expect(contrast(p.muted, p.paper), closeTo(4.39, 0.01)); // app avoids muted text on paper
    expect(contrast(p.faintText, p.surface), closeTo(3.69, 0.01)); // placeholders, slider tick numbers
    expect(contrast(p.pip, p.paper), closeTo(1.99, 0.01)); // always paired with a pip label
    expect(contrast(p.line2, p.surface), closeTo(1.73, 0.01)); // control borders
  });
}
