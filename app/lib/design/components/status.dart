import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../tokens.dart';

/// Encoder availability on this PC (brief §2 vocabulary).
enum VeAvailability {
  ready('Ready'),
  missing('Not in this FFmpeg'),
  failed('Failed test on this PC'),
  testing('Testing…'),

  /// Listed, but not tested on this PC yet (C3 state "unknown").
  unknown('Not checked yet');

  const VeAvailability(this.label);
  final String label;

  bool get isProblem => this == missing || this == failed;
}

/// `.st`: icon plus state text, coloured by state.
class VeStatusTag extends StatelessWidget {
  const VeStatusTag(this.state, {super.key, this.label, this.iconOnly = false});

  final VeAvailability state;

  /// Replaces the state's own text, as the node's "CPU" or "NVIDIA GPU" does.
  final String? label;
  final bool iconOnly;

  static VeIconData iconOf(VeAvailability s) => switch (s) {
    VeAvailability.ready => VeIcons.check,
    VeAvailability.missing => VeIcons.dash,
    VeAvailability.failed => VeIcons.error,
    VeAvailability.testing => VeIcons.refresh,
    VeAvailability.unknown => VeIcons.info,
  };

  static Color colorOf(VePalette c, VeAvailability s) => switch (s) {
    VeAvailability.ready => c.success,
    VeAvailability.missing => c.warning,
    VeAvailability.failed => c.error,
    VeAvailability.testing => c.ink,
    VeAvailability.unknown => c.muted,
  };

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final color = colorOf(t.colors, state);
    final text = label ?? state.label;
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VeIcon(iconOf(state), color: color),
          if (!iconOnly) ...[
            const SizedBox(width: 5),
            Text(
              text,
              style: t.text.caption.copyWith(color: color, fontWeight: const FontWeight(550)),
              maxLines: 1,
              softWrap: false,
            ),
          ],
        ],
      ),
    );
  }
}
