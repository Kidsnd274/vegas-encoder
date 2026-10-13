import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'interactive.dart';

/// `.toast`: a short confirmation on ink ("Saved as a new preset in Mine"),
/// with an optional action such as Undo. Announced to screen readers.
class VeToast extends StatelessWidget {
  const VeToast({super.key, required this.message, this.actionLabel, this.onAction});
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final style = t.text.body.copyWith(color: c.onInk, fontWeight: const FontWeight(550));
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(VeRadius.lg),
          boxShadow: t.toastShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: style),
            if (actionLabel != null) ...[
              const SizedBox(width: 14),
              VeInteractive(
                onTap: onAction,
                excludeChildSemantics: false,
                builder: (context, s) => VeFocusRing(
                  visible: s.focused,
                  radius: VeRadius.xs,
                  child: Text(
                    actionLabel!,
                    style: style.copyWith(
                      fontWeight: const FontWeight(700),
                      decoration: TextDecoration.underline,
                      decorationColor: c.onInk,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
