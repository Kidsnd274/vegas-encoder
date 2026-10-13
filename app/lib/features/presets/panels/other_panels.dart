import 'package:flutter/widgets.dart';
import 'package:ve_services/ve_services.dart' hide SizeEstimate;

import '../../../design/components/field.dart';
import '../../../design/components/interactive.dart';
import '../../../design/components/size_card.dart';
import '../../../design/components/switch.dart';
import '../../../design/format.dart';
import '../../../design/tokens.dart';
import '../../../state/preview.dart';
import '../../../state/recipe_edit.dart';
import '../display.dart';
import 'field_anchor.dart';
import 'panel_kit.dart';

/// From VEGAS: what the project delivers. Read-only.
class SourcePanel extends StatelessWidget {
  const SourcePanel({super.key, required this.scope});
  final PanelScope scope;

  @override
  Widget build(BuildContext context) {
    final m = scope.data.media;
    final v = m.video;
    final a = m.audio;
    return PanelColumns(
      left: [
        PanelFacts([
          ('Frame size', '${v.width}×${v.height}'),
          ('Frame rate', '${VeFormat.fps(v.fps[0], v.fps[1])} (${v.fps[0]}/${v.fps[1]})'),
          ('Pixel format', deliveredPixelFormat(v.pixfmt)),
          (
            'Audio',
            a == null
                ? 'None'
                : '${kiloHertz(a.rate)}, ${deliveredSampleFormat(a.sampleFmt)}, ${channelsLabel(a.channels)}',
          ),
          ('Length', m.durationSec == null ? 'Set by the project' : VeFormat.duration(m.durationSec!)),
        ]),
      ],
      right: const [
        PanelStatic(
          'VEGAS renders every frame and sends it to FFmpeg through a pipe. This is read-only; '
          'the project settings in VEGAS decide it.',
        ),
        PanelBlurb('These are sample values for the preview. A real render uses the project’s own size and rate.'),
      ],
    );
  }
}

/// Container: where the streams are joined. Each choice says whether it can
/// hold the chosen codecs, from the core's codec-to-container table.
class ContainerPanel extends StatelessWidget {
  const ContainerPanel({super.key, required this.scope});
  final PanelScope scope;

  @override
  Widget build(BuildContext context) {
    final s = scope;
    final r = s.recipe;
    final vp = s.data.videoProfile;
    final ap = s.data.audioProfile;
    final current = r.container.format;
    return PanelColumns(
      left: [
        FieldAnchor(
          fields: ['container', 'container.format'],
          child: VeField(
            label: 'Container',
            modified: s.modified('container.format'),
            onReset: s.reset('container.format'),
            messages: s.messages(['container', 'container.format']),
            child: Semantics(
              label: 'Container',
              explicitChildNodes: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in s.catalog.containers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _ContainerOption(
                        profile: c,
                        selected: c.id == current,
                        note: _fitNote(s, c.id, r, vp, ap),
                        onTap: () => s.edit((r) => r.withContainer((x) => x.copyWith(format: c.id))),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
      right: [
        if (current == 'mp4')
          FieldAnchor(
            fields: ['container.faststart'],
            child: VeField(
              label: 'Fast start',
              modified: s.modified('container.faststart'),
              onReset: s.reset('container.faststart'),
              messages: s.messages(['container.faststart']),
              child: Align(
                alignment: Alignment.centerLeft,
                child: VeSwitch(
                  small: true,
                  label: 'Move the index to the front so playback starts early',
                  value: r.container.faststart,
                  onChanged: (on) => s.edit((r) => r.withContainer((x) => x.copyWith(faststart: on))),
                ),
              ),
            ),
          ),
        if (vp?.appleTag != null && (current == 'mp4' || current == 'mov'))
          PanelBlurb('Adds -tag:v ${vp!.appleTag} so Apple players open ${vp.codec}.'),
        const PanelBlurb('VEGAS chooses the folder and name in Render As. The extension follows the container.'),
      ],
    );
  }

  /// "Can't hold H.264" or "AAC audio: few players" from the catalog table.
  ({String text, bool error})? _fitNote(
    PanelScope s,
    String container,
    Recipe r,
    EncoderProfile? vp,
    EncoderProfile? ap,
  ) {
    const rank = {'ok': 0, 'warn': 1, 'no': 2};
    String? worst;
    String? why;
    for (final (on, profile, video) in [(r.video.enabled, vp, true), (r.audioTrack.enabled, ap, false)]) {
      if (!on || profile == null) continue;
      final fit = s.catalog.compatibilityOf(video: video, family: profile.family, container: container);
      if ((rank[fit] ?? 0) > (rank[worst] ?? 0)) {
        worst = fit;
        why = video ? profile.codec : '${profile.codec} audio';
      }
    }
    return switch (worst) {
      'no' => (text: 'Can’t hold $why', error: true),
      'warn' => (text: '$why: few players', error: false),
      _ => null,
    };
  }
}

class _ContainerOption extends StatelessWidget {
  const _ContainerOption({required this.profile, required this.selected, required this.note, required this.onTap});
  final ContainerProfile profile;
  final bool selected;
  final ({String text, bool error})? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: [profile.label, profile.blurb, if (note != null) note!.text].join('. '),
      child: VeInteractive(
        onTap: onTap,
        builder: (context, st) => VeFocusRing(
          visible: st.focused,
          radius: 7,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? c.fillSelected : (st.hovered ? c.fillHover : null),
              border: Border.all(color: selected ? c.line2 : const Color(0x00000000)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(top: 1, right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? c.ink : c.lineHover, width: selected ? 5 : 2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.label, style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(600))),
                      const SizedBox(height: 1),
                      Text(profile.blurb, style: t.text.caption.copyWith(color: c.muted)),
                    ],
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    note!.text,
                    style: t.text.caption.copyWith(
                      color: note!.error ? c.error : c.warningText,
                      fontWeight: const FontWeight(550),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// File: where the render goes, and how big it will be. The estimate lives
/// only here (UI_SPEC §2).
class FilePanel extends StatelessWidget {
  const FilePanel({
    super.key,
    required this.scope,
    required this.lengthSec,
    required this.lengthText,
    required this.onLengthTextChanged,
  });
  final PanelScope scope;
  final int? lengthSec;

  /// Exactly as typed (C7 remembers it); [lengthSec] is what it means.
  final String lengthText;
  final ValueChanged<String> onLengthTextChanged;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final d = scope.data;
    final advanced = d.recipe.command.mode == 'template';
    final perMinute = d.perMinute.value;
    final total = d.total?.value;
    return PanelColumns(
      left: [
        if (advanced)
          const PanelStatic('Advanced mode shows no estimate: a custom command can do anything.')
        else if (perMinute == null || !perMinute.available)
          PanelStatic(
            d.perMinute.notInPreviewCore
                ? 'The size estimate for this edit needs the real core (platform milestone B2). '
                      'The built-in presets as shipped show theirs.'
                : 'No estimate for these settings.',
          )
        else
          SizeQualityCard(
            estimate: SizeEstimate(
              videoKbps: perMinute.videoKbps,
              audioKbps: d.recipe.audioTrack.enabled ? perMinute.audioKbps : null,
              approximate: perMinute.approx,
              bytesPerMinute: perMinute.bytesPerMinute,
              totalBytes: total?.totalBytes,
              minBytesPerMinute: perMinute.minBytesPerMinute,
              maxBytesPerMinute: perMinute.maxBytesPerMinute,
              consequences: [if (perMinute.explanation.isNotEmpty) perMinute.explanation],
              totalNote: 'Total not available yet',
            ),
            lengthSeconds: lengthSec,
            lengthText: lengthText,
            onLengthTextChanged: onLengthTextChanged,
            onLengthChanged: (_) {},
          ),
      ],
      right: [
        VeField(
          label: 'File name',
          blurb: const Text(
            'VEGAS chooses the folder and name in Render As. Vegas Encoder writes to a temporary name '
            'and renames it when the render succeeds.',
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: t.colors.paper,
              border: Border.all(color: t.colors.line),
              borderRadius: BorderRadius.circular(VeRadius.md),
            ),
            child: Text(
              SamplePreview.outputPath(d.containerProfile?.ext),
              style: t.text.mono.copyWith(fontSize: 12.5, height: 1.4),
            ),
          ),
        ),
        if (!advanced && perMinute != null && perMinute.available)
          VeField(
            label: 'How this is worked out',
            blurb: const Text('After each render, History shows the real size and average bitrate.'),
            child: PanelStatic(
              perMinute.approx
                  ? 'Quality modes have no fixed size. This guide uses the frame size, frame rate and codec, '
                        'so treat it as a range.'
                  : 'Bitrate modes multiply the bitrate by the length, so the figure is close.',
            ),
          ),
        if (lengthSec != null && d.total != null && !d.total!.ok && perMinute != null)
          const PanelBlurb(
            'The total for a typed length comes from the real core (platform milestone B2). '
            'The rate per minute is from the preview core.',
          ),
      ],
    );
  }
}
