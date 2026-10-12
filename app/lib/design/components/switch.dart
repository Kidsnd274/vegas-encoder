import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'interactive.dart';

/// `.swt`: an on/off switch with its label ("Audio", "Only show problems").
class VeSwitch extends StatelessWidget {
  const VeSwitch({super.key, required this.value, required this.onChanged, required this.label, this.small = false});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  /// `.swt.small`: 13 px, weight 500.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final duration = VeTokens.motion(context, VeDurations.short);
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      label: label,
      child: VeInteractive(
        enabled: onChanged != null,
        onTap: () => onChanged?.call(!value),
        builder: (context, s) => VeDisabled(
          disabled: onChanged == null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              VeFocusRing(
                visible: s.focused,
                radius: 9,
                child: AnimatedContainer(
                  duration: duration,
                  width: 32,
                  height: 18,
                  decoration: BoxDecoration(color: value ? c.ink : c.track, borderRadius: BorderRadius.circular(9)),
                  child: AnimatedAlign(
                    duration: duration,
                    alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(color: value ? c.onInk : c.knob, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  style: small
                      ? t.text.body.copyWith(fontWeight: const FontWeight(500))
                      : t.text.body.copyWith(fontSize: 14, fontWeight: const FontWeight(600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
