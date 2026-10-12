import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../tokens.dart';
import 'interactive.dart';
import 'popover.dart';
import 'status.dart';

/// `.sel`: a dropdown for a short list (tune, profile, sample rate).
class VeSelect<T> extends StatelessWidget {
  const VeSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.width,
  });

  final List<VeOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String semanticLabel;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final current = options.where((o) => o.value == value).firstOrNull;
    return VePopover(
      anchorBuilder: (context, open, toggle) => Semantics(
        button: true,
        expanded: open,
        label: semanticLabel,
        value: current?.label,
        child: VeInteractive(
          enabled: onChanged != null,
          onTap: toggle,
          builder: (context, s) => VeFocusRing(
            visible: s.focused,
            child: VeDisabled(
              disabled: onChanged == null,
              child: Container(
                height: 32,
                width: width,
                padding: const EdgeInsets.only(left: 10, right: 8),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: s.hovered ? c.lineHover : c.line2),
                  borderRadius: BorderRadius.circular(VeRadius.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        current?.label ?? '',
                        style: t.text.body.copyWith(height: 1.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    VeIcon(VeIcons.chevronDown, size: 16, color: c.muted),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      contentBuilder: (context, close) => VeListbox<T>(
        groups: [VeOptionGroup(options)],
        selected: value,
        semanticLabel: semanticLabel,
        onClose: close,
        onPick: (v) => onChanged?.call(v),
      ),
      width: width,
    );
  }
}

/// One encoder in the picker.
@immutable
class VeEncoderChoice {
  const VeEncoderChoice({
    required this.id,
    required this.label,
    required this.detail,
    required this.availability,
    this.reason,
  });

  /// FFmpeg name, such as `libx264`.
  final String id;

  /// "x264".
  final String label;

  /// "H.264, CPU, 10-bit" in the list; "H.264, CPU" on the closed picker.
  final String detail;
  final VeAvailability availability;

  /// Why it is not ready ("Not listed by this FFmpeg").
  final String? reason;
}

@immutable
class VeEncoderGroup {
  const VeEncoderGroup(this.name, this.encoders);

  /// Codec family ("H.264", "HEVC", "Intermediate").
  final String name;
  final List<VeEncoderChoice> encoders;
}

/// `EncoderPicker` (UI_SPEC §11): grouped by codec, with hardware and
/// availability shown. Unavailable encoders stay selectable, so a preset made
/// on another PC remains editable; the field then shows the error.
class VeEncoderPicker extends StatelessWidget {
  const VeEncoderPicker({
    super.key,
    required this.groups,
    required this.selectedId,
    required this.onChanged,
    required this.kindLabel,
    required this.installationLabel,
    this.closedDetail,
  });

  final List<VeEncoderGroup> groups;
  final String selectedId;
  final ValueChanged<String>? onChanged;

  /// "Video" or "Audio"; names the control for screen readers.
  final String kindLabel;

  /// "FFmpeg 8.1 full", for the footnote.
  final String installationLabel;

  /// Detail on the closed picker; defaults to the choice's detail.
  final String? closedDetail;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final current = [for (final g in groups) ...g.encoders].where((e) => e.id == selectedId).firstOrNull;
    return VePopover(
      width: 390,
      anchorBuilder: (context, open, toggle) => Semantics(
        button: true,
        expanded: open,
        label: '$kindLabel encoder: ${current?.label ?? selectedId}',
        value: current == null || current.availability == VeAvailability.ready ? null : current.availability.label,
        child: VeInteractive(
          enabled: onChanged != null,
          onTap: toggle,
          builder: (context, s) => VeFocusRing(
            visible: s.focused,
            radius: 7,
            child: Container(
              height: 40,
              padding: const EdgeInsets.only(left: 12, right: 10),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: s.hovered ? c.lineHover : c.line2),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Text(
                    current?.label ?? selectedId,
                    style: t.text.body.copyWith(fontSize: 14, fontWeight: const FontWeight(650), height: 1.2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      closedDetail ?? current?.detail ?? '',
                      style: t.text.small.copyWith(color: c.muted, height: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (current != null && current.availability != VeAvailability.ready) ...[
                    const SizedBox(width: 10),
                    VeStatusTag(current.availability),
                  ],
                  const SizedBox(width: 10),
                  VeIcon(VeIcons.chevronDown, color: c.ink),
                ],
              ),
            ),
          ),
        ),
      ),
      contentBuilder: (context, close) => VeListbox<String>(
        semanticLabel: '$kindLabel encoders',
        selected: selectedId,
        onClose: close,
        onPick: (v) => onChanged?.call(v),
        footnote: 'Availability in $installationLabel.',
        groups: [
          for (final g in groups)
            VeOptionGroup([
              for (final e in g.encoders)
                VeOption(e.id, e.label, detail: e.detail, trailing: VeStatusTag(e.availability)),
            ], header: g.name),
        ],
      ),
    );
  }
}
