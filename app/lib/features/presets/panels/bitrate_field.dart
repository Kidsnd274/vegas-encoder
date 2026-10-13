import 'package:flutter/widgets.dart';

import '../../../design/components/button.dart';
import '../../../design/components/popover.dart';
import '../../../design/components/text_field.dart';
import '../../../design/format.dart';
import '../../../design/icons.dart';

/// Common video bitrates offered beside the field, in kb/s (UI_SPEC §2,
/// Quality control: "Bitrate modes switch the control to Mb/s or kb/s with
/// common values"). A convenience list, not a rule: any value can be typed.
const commonVideoBitratesK = [2000, 4000, 6000, 8000, 10000, 12000, 16000, 20000, 25000, 35000, 50000, 80000];

/// A bitrate typed in Mb/s and stored in kb/s, with common values to pick.
class BitrateField extends StatelessWidget {
  const BitrateField({
    super.key,
    required this.valueK,
    required this.onChanged,
    required this.semanticLabel,
    this.placeholder,
    this.common = commonVideoBitratesK,
  });

  final int? valueK;
  final ValueChanged<int?> onChanged;
  final String semanticLabel;

  /// Shown when empty, such as "No cap".
  final String? placeholder;
  final List<int> common;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        VeNumberField(
          value: valueK == null ? null : valueK! / 1000,
          unit: 'Mb/s',
          decimals: true,
          width: 90,
          placeholder: placeholder,
          semanticLabel: semanticLabel,
          onChanged: (mbps) => onChanged(mbps == null || mbps <= 0 ? null : (mbps * 1000).round()),
        ),
        const SizedBox(width: 6),
        VePopover(
          width: 200,
          maxHeight: 320,
          anchorBuilder: (context, open, toggle) => VeButton(
            label: 'Common',
            trailingIcon: VeIcons.chevronDown,
            variant: VeButtonVariant.ghost,
            size: VeButtonSize.small,
            semanticLabel: 'Common values for $semanticLabel',
            onPressed: toggle,
          ),
          contentBuilder: (context, close) => VeListbox<int>(
            semanticLabel: 'Common values',
            selected: valueK,
            onClose: close,
            onPick: onChanged,
            groups: [
              VeOptionGroup([for (final k in common) VeOption(k, VeFormat.rate(k))]),
            ],
          ),
        ),
      ],
    );
  }
}

/// "8 Mb/s average, 12 Mb/s peak", "8 Mb/s constant".
String bitrateMeaning(String mode, int? bitrateK, int? maxrateK) {
  if (bitrateK == null) return 'Not set';
  final rate = VeFormat.rate(bitrateK);
  if (mode == 'cbr') return '$rate constant';
  return maxrateK == null ? '$rate average, no peak cap' : '$rate average, ${VeFormat.rate(maxrateK)} peak';
}
