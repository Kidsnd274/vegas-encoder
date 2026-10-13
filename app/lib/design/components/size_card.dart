import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../format.dart';
import '../icons.dart';
import '../tokens.dart';
import 'text_field.dart';

/// An estimate as the core reports it (SETTINGS_AND_COMMANDS §7, CONTRACTS C2
/// `SizeEstimate`). The card only formats these figures; it never works out a
/// size itself.
@immutable
class SizeEstimate {
  const SizeEstimate({
    required this.videoKbps,
    required this.audioKbps,
    required this.approximate,
    required this.bytesPerMinute,
    this.totalBytes,
    this.minBytesPerMinute,
    this.maxBytesPerMinute,
    this.minTotalBytes,
    this.maxTotalBytes,
    this.consequences = const [],
    this.totalNote,
  });

  final double videoKbps;

  /// Null when audio is off.
  final double? audioKbps;

  /// Quality modes have no fixed size; bitrate modes are close.
  final bool approximate;
  final double bytesPerMinute;

  /// The total for the typed length; null when there is none.
  final double? totalBytes;

  /// Typical range per minute, for quality modes.
  final double? minBytesPerMinute;
  final double? maxBytesPerMinute;

  /// Typical range for the typed length, for quality modes; null without a
  /// length. The core's figures, not the per-minute range scaled here.
  final double? minTotalBytes;
  final double? maxTotalBytes;

  /// Plain-language results of the rate mode and bit depth.
  final List<String> consequences;

  /// Shown in place of the total when a length is typed but the core gave
  /// no total ("Total not available yet").
  final String? totalNote;

  double get totalKbps => videoKbps + (audioKbps ?? 0);
}

/// `SizeQualityCard` (UI_SPEC §2): shown only behind the File node. A rate per
/// minute always; the core's total for a length the user types; a range for
/// quality modes; the video and audio split; consequences.
class SizeQualityCard extends StatefulWidget {
  const SizeQualityCard({
    super.key,
    required this.estimate,
    required this.lengthSeconds,
    required this.onLengthChanged,
    this.lengthText,
    this.onLengthTextChanged,
    this.lengthHint = 'Type how long the video is.',
    this.compact = false,
  });

  final SizeEstimate estimate;

  /// Null shows "Type a length".
  final int? lengthSeconds;
  final ValueChanged<int?> onLengthChanged;

  /// The text to show, exactly as last typed (it may not be a length yet);
  /// defaults to [lengthSeconds] formatted.
  final String? lengthText;
  final ValueChanged<String>? onLengthTextChanged;

  /// Desktop: "Type how long the video is." Popup: "Project length from VEGAS."
  final String lengthHint;

  /// Popup variant: a smaller total.
  final bool compact;

  @override
  State<SizeQualityCard> createState() => _SizeQualityCardState();
}

class _SizeQualityCardState extends State<SizeQualityCard> {
  late final TextEditingController _length = TextEditingController(text: _text);

  String get _text =>
      widget.lengthText ?? (widget.lengthSeconds == null ? '' : VeFormat.duration(widget.lengthSeconds!));
  final FocusNode _focus = FocusNode(debugLabel: 'length');

  @override
  void didUpdateWidget(SizeQualityCard old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && (old.lengthSeconds != widget.lengthSeconds || old.lengthText != widget.lengthText)) {
      _length.text = _text;
    }
  }

  @override
  void dispose() {
    _length.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final e = widget.estimate;
    final len = widget.lengthSeconds;
    final about = e.approximate ? 'About ' : '';
    final low = e.minBytesPerMinute, high = e.maxBytesPerMinute;
    final totalLow = e.minTotalBytes, totalHigh = e.maxTotalBytes;
    final String tail;
    if (len != null && e.totalBytes != null && totalLow != null && totalHigh != null) {
      // The range for the typed length (the mockup's wording).
      tail = '. Typically ${VeFormat.bytes(totalLow)} to ${VeFormat.bytes(totalHigh)} for ${VeFormat.duration(len)}.';
    } else if (low != null && high != null) {
      tail = ', typically ${VeFormat.bytes(low)} to ${VeFormat.bytes(high)}.';
    } else {
      tail = e.approximate ? '.' : ', set by the bitrate.';
    }
    final range = '$about${VeFormat.bytes(e.bytesPerMinute)} per minute$tail';

    final bigStyle = widget.compact ? t.text.display.copyWith(fontSize: 28) : t.text.display;
    final smallBig = t.text.body.copyWith(fontSize: 17, fontWeight: const FontWeight(600), color: c.muted);
    final videoShare = math.max(2.0, e.videoKbps / math.max(1, e.totalKbps) * 100);

    return Semantics(
      container: true,
      label: 'Size and quality',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(VeRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Size and quality', style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(650))),
                const Spacer(),
                Text('Length', style: t.text.small.copyWith(color: c.muted)),
                const SizedBox(width: 8),
                VeTextField(
                  controller: _length,
                  focusNode: _focus,
                  width: 84,
                  height: 28,
                  textAlign: TextAlign.right,
                  placeholder: 'm:ss',
                  semanticLabel: 'Length to estimate, minutes and seconds',
                  onChanged: (s) {
                    widget.onLengthTextChanged?.call(s);
                    widget.onLengthChanged(VeFormat.parseLength(s));
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.lengthHint,
                textAlign: TextAlign.right,
                style: t.text.caption.copyWith(color: c.muted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Semantics(
                liveRegion: true,
                child: Text.rich(
                  len == null || e.totalBytes == null
                      ? TextSpan(text: len == null ? 'Type a length' : e.totalNote ?? 'Type a length', style: smallBig)
                      : TextSpan(
                          children: [
                            if (e.approximate) TextSpan(text: 'About ', style: smallBig),
                            TextSpan(text: VeFormat.bytes(e.totalBytes!), style: bigStyle),
                          ],
                        ),
                  style: bigStyle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(range, style: t.text.small.copyWith(color: c.text2)),
            ),
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: SizedBox(
                height: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: (videoShare * 10).round(),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: c.videoWire, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      if (e.audioKbps != null) ...[
                        const SizedBox(width: 2),
                        Expanded(
                          flex: math.max(1, ((100 - videoShare) * 10).round()),
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: c.audioWire, borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            DefaultTextStyle(
              style: t.text.small.copyWith(color: c.muted),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Legend(label: 'Video', value: VeFormat.rate(e.videoKbps)),
                  _Legend(label: 'Audio', value: e.audioKbps == null ? 'off' : VeFormat.rate(e.audioKbps!)),
                ],
              ),
            ),
            if (e.consequences.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.line)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < e.consequences.length; i++)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: VeIcon(VeIcons.bullet, color: c.muted),
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(e.consequences[i], style: t.text.small)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: TextStyle(color: t.colors.ink, fontWeight: const FontWeight(600)),
          ),
        ],
      ),
    );
  }
}
