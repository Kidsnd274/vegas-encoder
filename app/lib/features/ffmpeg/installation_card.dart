import 'package:flutter/widgets.dart';

import '../../design/components/button.dart';
import '../../design/components/interactive.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import 'display.dart';

/// `.ic`: one FFmpeg installation and its actions. Pressing it shows its
/// encoders below.
class InstallationCard extends StatelessWidget {
  const InstallationCard({
    super.key,
    required this.model,
    required this.selected,
    required this.onSelect,
    required this.onSetDefault,
    required this.onCopyPath,
    required this.onRemove,
  });

  final InstallationCardModel model;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onSetDefault;
  final VoidCallback onCopyPath;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final m = model;
    final muted = t.text.small.copyWith(color: c.muted);
    final strong = t.text.small.copyWith(fontWeight: const FontWeight(600));

    Widget facts(List<InlineSpan> spans) => Text.rich(TextSpan(style: muted, children: spans), maxLines: 1);

    return Semantics(
      button: true,
      selected: selected,
      label: '${m.title}${m.isDefault ? ', default' : ''}',
      child: VeInteractive(
        onTap: onSelect,
        excludeChildSemantics: false,
        builder: (context, s) => VeFocusRing(
          visible: s.focused,
          radius: VeRadius.xl,
          child: AnimatedContainer(
            duration: VeTokens.motion(context, VeDurations.short),
            padding: EdgeInsets.all(selected ? 12 : 13).copyWith(left: selected ? 14 : 15, right: selected ? 14 : 15),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(VeRadius.xl),
              border: Border.all(
                color: selected ? c.ink : (s.hovered ? c.lineHover : c.line2),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected ? t.raisedShadow : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(m.title, style: t.text.panelTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (m.isDefault) ...[const SizedBox(width: 8), const _DefaultPill()],
                  ],
                ),
                const SizedBox(height: 7),
                Text(m.line, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 7),
                VeTooltip(
                  message: 'ffmpeg.exe: ${m.path}\nffprobe.exe: ${m.ffprobePath}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: c.paper, borderRadius: BorderRadius.circular(VeRadius.sm)),
                    child: Text(
                      m.path,
                      style: t.text.monoSmall.copyWith(color: c.ink2),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                if (m.progress case final p?)
                  _Progress(label: p.label, fraction: p.fraction)
                else ...[
                  facts([TextSpan(text: m.checked)]),
                  if (m.counts case final n?) ...[
                    const SizedBox(height: 7),
                    facts([
                      TextSpan(text: '${n.video}', style: strong),
                      const TextSpan(text: ' video encoders    '),
                      TextSpan(text: '${n.audio}', style: strong),
                      const TextSpan(text: ' audio    '),
                      TextSpan(text: '${n.muxers}', style: strong),
                      const TextSpan(text: ' muxers'),
                    ]),
                  ],
                ],
                if (m.failure case final f?) ...[
                  const SizedBox(height: 7),
                  _Note(icon: VeIcons.error, color: c.error, text: f),
                ],
                if (m.blocked.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  VeTooltip(
                    message: m.blocked.join('\n'),
                    child: _Note(
                      icon: VeIcons.warning,
                      color: c.warning,
                      text:
                          'Can’t render ${m.blocked.length} ${m.blocked.length == 1 ? 'preset' : 'presets'}: '
                          'needs ${m.blockedNeeds.join(', ')}',
                    ),
                  ),
                ],
                // Actions sit at the bottom of every card, so selecting one
                // doesn't change the strip's height.
                const Spacer(),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (!m.isDefault)
                      VeButton(label: 'Set as default', size: VeButtonSize.small, onPressed: onSetDefault),
                    VeButton(
                      label: 'Copy path',
                      size: VeButtonSize.small,
                      variant: VeButtonVariant.ghost,
                      icon: VeIcons.copy,
                      onPressed: onCopyPath,
                    ),
                    if (!m.isDefault)
                      VeButton(
                        label: 'Remove…',
                        size: VeButtonSize.small,
                        variant: VeButtonVariant.ghost,
                        onPressed: onRemove,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.defpill`
class _DefaultPill extends StatelessWidget {
  const _DefaultPill();

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.colors.ink, borderRadius: BorderRadius.circular(10)),
      child: Text(
        'Default',
        style: t.text.micro.copyWith(color: t.colors.onInk, fontWeight: const FontWeight(650)),
      ),
    );
  }
}

/// A probe running now: its phase and a thin video-wire bar.
class _Progress extends StatelessWidget {
  const _Progress({required this.label, required this.fraction});
  final String label;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: t.text.small.copyWith(color: c.text2), maxLines: 1),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: c.track)),
                  FractionallySizedBox(
                    widthFactor: (fraction ?? 0.15).clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: ColoredBox(color: c.videoWire),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});
  final VeIconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: VeIcon(icon, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: t.text.small.copyWith(color: t.colors.text2), maxLines: 2),
        ),
      ],
    );
  }
}
