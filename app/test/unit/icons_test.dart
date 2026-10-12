import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/design/icons.dart';

void main() {
  test('every icon path parses and stays inside its 16-unit box', () {
    const paths = [
      'M5.5 7V5a2.5 2.5 0 0 1 5 0v2',
      'M4.5 6.5 8 10l3.5-3.5',
      'm8 2 1.8 3.8 4.2.5-3.1 2.9.8 4.1L8 11.3l-3.7 2 .8-4.1L2 6.3l4.2-.5z',
      'M8 2.2 14.3 13.3H1.7z',
      'M6 13.5h4M6.5 11.5h3M8 2a4 4 0 0 0-2.4 7.2c.5.4.9 1 .9 1.6v.2h3v-.2c0-.6.4-1.2.9-1.6A4 4 0 0 0 8 2z',
      'M13.2 8a5.2 5.2 0 1 1-1.6-3.8M13.2 2.5v3h-3',
      'M6 2h4M6.5 2v4.2L3.2 12.6A1.2 1.2 0 0 0 4.3 14.4h7.4a1.2 1.2 0 0 0 1.1-1.8L9.5 6.2V2M4.6 10h6.8',
      'M2 4.5a1 1 0 0 1 1-1h3l1.5 1.5H13a1 1 0 0 1 1 1V12a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1z',
    ];
    for (final d in paths) {
      // getBounds includes curve control points; measure the outline itself.
      Rect? bounds;
      for (final m in parseSvgPath(d).computeMetrics()) {
        for (var at = 0.0; at <= m.length; at += 0.05) {
          final p = m.getTangentForOffset(at)!.position;
          final r = Rect.fromCenter(center: p, width: 0, height: 0);
          bounds = bounds == null ? r : bounds.expandToInclude(r);
        }
      }
      bounds = bounds!;
      expect(const Rect.fromLTWH(0, 0, 16, 16).inflate(0.01).contains(bounds.topLeft), isTrue, reason: d);
      expect(const Rect.fromLTWH(0, 0, 16, 16).inflate(0.01).contains(bounds.bottomRight), isTrue, reason: d);
      expect(bounds.width + bounds.height, greaterThan(0), reason: d);
    }
  });

  test('implicit line-tos after a move are handled', () {
    final b = parseSvgPath('M4.5 6.5 8 10l3.5-3.5').getBounds();
    expect(b.left, 4.5);
    expect(b.right, 11.5);
    expect(b.bottom, 10);
  });

  test('a number straight after Z is rejected instead of looping', () {
    expect(() => parseSvgPath('M1 1L2 2Z 3 3'), throwsFormatException);
  });

  test('the catalogue has distinct names', () {
    final names = VeIcons.all.map((i) => i.name).toSet();
    expect(names.length, VeIcons.all.length);
  });
}
