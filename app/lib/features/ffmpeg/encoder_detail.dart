import 'package:flutter/widgets.dart';

import '../../design/components/button.dart';
import '../../design/components/signal_path/signal_path.dart' show VeDotGridPainter;
import '../../design/components/status.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import 'display.dart';

/// `.capd`: one encoder in the selected installation: its state, what that
/// means, the test encode, what FFmpeg said, and the presets that use it.
class EncoderDetail extends StatelessWidget {
  const EncoderDetail({super.key, required this.model, required this.onTest, required this.onOpenPreset});

  final EncoderDetailModel model;

  /// Test this encoder again; null while a test runs.
  final VoidCallback? onTest;
  final ValueChanged<String> onOpenPreset;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final m = model;
    final para = t.text.small.copyWith(color: c.text2, height: 1.5);
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(650))),
      ),
    );

    final detail = m.status.detail;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      children: [
        Semantics(header: true, child: Text(m.label, style: t.text.popupTitle)),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            style: t.text.small.copyWith(color: c.muted),
            children: [
              TextSpan(
                text: m.id,
                style: t.text.monoSmall.copyWith(color: c.muted),
              ),
              TextSpan(text: ' in ${m.installationLabel}'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: VeStatusTag(m.status.state)),
        heading('What this means'),
        Text(m.meaning, style: para),
        if (m.advice case final a?) ...[const SizedBox(height: 8), Text(a, style: para.copyWith(color: c.ink))],
        if (m.testFacts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(m.testFacts.join('. '), style: para.copyWith(color: c.muted)),
        ],
        if (m.showsTestEncode) ...[
          heading('Test encode'),
          _TestFlow(id: m.id, video: m.video, state: m.status.state),
          if (detail != null) ...[
            heading('FFmpeg said'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: c.errorBackground,
                border: Border.all(color: c.errorLine),
                borderRadius: BorderRadius.circular(VeRadius.lg),
              ),
              child: Text(detail, style: t.text.monoSmall.copyWith(color: c.errorText)),
            ),
          ],
        ],
        heading('Used by ${m.usedBy.length} ${m.usedBy.length == 1 ? 'preset' : 'presets'}'),
        if (m.usedBy.isEmpty)
          Text('No preset in the library uses this encoder.', style: para)
        else
          for (final p in m.usedBy)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: VeLinkButton(
                        label: p.name,
                        style: t.text.body.copyWith(color: c.ink),
                        onPressed: () => onOpenPreset(p.id),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(p.builtin ? 'Built-in' : 'Mine', style: t.text.caption.copyWith(color: c.muted)),
                ],
              ),
            ),
        if (m.hardware) ...[
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: VeButton(label: 'Test ${m.label} again', icon: VeIcons.flask, onPressed: onTest),
          ),
        ],
      ],
    );
  }
}

/// `.testflow`: testsrc2 into the encoder into the null muxer, the wire as
/// thick as the stream, and dashed past an encoder that can't run.
class _TestFlow extends StatelessWidget {
  const _TestFlow({required this.id, required this.video, required this.state});
  final String id;
  final bool video;
  final VeAvailability state;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final bad = state.isProblem;
    Widget node(double left, double width, String title, String sub, {bool error = false}) => Positioned(
      left: left,
      top: 0,
      bottom: 2,
      width: width,
      // Centred on the wire (y 47); the text decides the height.
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: error ? c.errorBackground : c.surface,
            border: Border.all(color: error ? c.error : c.line2),
            borderRadius: BorderRadius.circular(VeRadius.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: t.text.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                sub,
                style: t.text.caption.copyWith(color: c.text2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: 'Test encode: testsrc2 into $id, ${state.label}, into the null output',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VeRadius.lg),
        child: Container(
          height: 96,
          foregroundDecoration: BoxDecoration(
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(VeRadius.lg),
          ),
          child: CustomPaint(
            painter: VeDotGridPainter(c),
            child: LayoutBuilder(
              builder: (context, box) {
                // The mockup's 418 px row, fitted to the panel: source at the
                // left, null at the right, the encoder centred between.
                final w = box.maxWidth;
                const srcLeft = 12.0, srcWidth = 92.0, nullWidth = 80.0, gap = 24.0;
                final nullLeft = w - 12 - nullWidth;
                final encWidth = (nullLeft - (srcLeft + srcWidth) - 2 * gap).clamp(90.0, 150.0);
                final encLeft = (srcLeft + srcWidth + nullLeft - encWidth) / 2;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _WirePainter(
                          color: video ? c.videoWire : c.audioWire,
                          width: video ? 10 : 6,
                          broken: bad,
                          first: (srcLeft + srcWidth, encLeft),
                          second: (encLeft + encWidth, nullLeft),
                        ),
                      ),
                    ),
                    node(srcLeft, srcWidth, 'testsrc2', video ? '60 frames' : 'sine tone'),
                    node(encLeft, encWidth, id, state.label, error: bad),
                    node(nullLeft, nullWidth, 'null', 'no file'),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WirePainter extends CustomPainter {
  _WirePainter({
    required this.color,
    required this.width,
    required this.broken,
    required this.first,
    required this.second,
  });
  final Color color;
  final double width;
  final bool broken;

  /// Where each wire starts and ends, along the middle line.
  final (double, double) first, second;

  static const double _y = 47;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width;
    canvas.drawLine(Offset(first.$1, _y), Offset(first.$2, _y), paint);
    if (!broken) {
      canvas.drawLine(Offset(second.$1, _y), Offset(second.$2, _y), paint);
      return;
    }
    // Past an encoder that can't run, the wire is dashed and faint.
    final faded = Paint()
      ..color = color.withValues(alpha: color.a * 0.35)
      ..strokeWidth = width;
    for (var x = second.$1; x < second.$2; x += 10) {
      canvas.drawLine(Offset(x, _y), Offset((x + 5).clamp(x, second.$2), _y), faded);
    }
  }

  @override
  bool shouldRepaint(_WirePainter old) =>
      old.color != color || old.width != width || old.broken != broken || old.first != first || old.second != second;
}
