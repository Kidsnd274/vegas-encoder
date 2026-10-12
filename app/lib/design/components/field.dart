import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'message.dart';

/// `.fld`: a labelled setting. The read-out on the right states the value and
/// its meaning ("CRF 18, visually lossless"); messages sit under the control.
class VeField extends StatelessWidget {
  const VeField({
    super.key,
    required this.label,
    required this.child,
    this.readout,
    this.blurb,
    this.messages = const [],
    this.lit = false,
    this.modified = false,
    this.onReset,
  });

  final String label;
  final Widget child;

  /// Right-aligned value, usually a [VeReadout].
  final Widget? readout;

  /// One or two lines that explain the setting (`.blurb`).
  final Widget? blurb;
  final List<VeMessage> messages;

  /// Lit while the pointer is over its tokens in the command (`.fld.lit`).
  final bool lit;

  /// The user changed this field (UI_SPEC §2 "modified dot").
  final bool modified;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return AnimatedContainer(
      duration: VeTokens.motion(context, const Duration(milliseconds: 200)),
      decoration: BoxDecoration(
        color: lit ? c.lit : c.lit.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(VeRadius.lg),
        boxShadow: [BoxShadow(color: lit ? c.lit : c.lit.withValues(alpha: 0), spreadRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(label, style: t.text.label),
                if (modified) ...[
                  const SizedBox(width: 6),
                  Semantics(
                    label: 'Changed',
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
                    ),
                  ),
                ],
                if (readout == null)
                  const Spacer()
                else ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: DefaultTextStyle(
                        style: t.text.small.copyWith(color: c.muted),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: readout!,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          child,
          if (blurb != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: DefaultTextStyle(
                style: t.text.small.copyWith(color: c.muted),
                child: blurb!,
              ),
            ),
          if (messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < messages.length; i++) ...[if (i > 0) const SizedBox(height: 6), messages[i]],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A read-out with a strong value and a plain meaning: "**CRF 18**, visually
/// lossless".
class VeReadout extends StatelessWidget {
  const VeReadout({super.key, required this.value, this.meaning, this.mono = false});
  final String value;
  final String? meaning;

  /// Pixel formats and other FFmpeg names (`<span class="mono">`).
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final base = DefaultTextStyle.of(context).style;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: mono
                ? t.text.mono.copyWith(fontSize: 12.5, height: 1.4, color: t.colors.ink)
                : base.copyWith(color: t.colors.ink, fontWeight: const FontWeight(650)),
          ),
          if (meaning != null) TextSpan(text: meaning),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
    );
  }
}
