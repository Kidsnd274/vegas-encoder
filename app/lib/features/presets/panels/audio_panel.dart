import 'package:flutter/widgets.dart';
import 'package:ve_services/ve_services.dart';

import '../../../design/components/field.dart';
import '../../../design/components/popover.dart';
import '../../../design/components/segmented.dart';
import '../../../design/components/select.dart';
import '../../../design/components/slider.dart';
import '../../../design/components/switch.dart';
import '../../../state/recipe_edit.dart';
import '../display.dart';
import 'extra_field.dart';
import 'field_anchor.dart';
import 'panel_kit.dart';

/// The Audio encoder node's settings. Turning audio off removes the audio path
/// from the diagram; the settings are kept for when it is turned back on.
class AudioPanel extends StatelessWidget {
  const AudioPanel({super.key, required this.scope});
  final PanelScope scope;

  static const _path = 'audio[0]';

  @override
  Widget build(BuildContext context) {
    final s = scope;
    final a = s.recipe.audioTrack;
    final media = s.data.media.audio;
    final toggle = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: VeSwitch(
          label: 'Audio',
          value: a.enabled,
          onChanged: (on) => s.edit((r) => r.withAudio((a) => a.copyWith(enabled: on))),
        ),
      ),
    );
    if (!a.enabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toggle,
          const PanelBlurb(
            'Audio is off, so the audio path is gone from the diagram and the file has video only. '
            'Turn it on to add it back.',
          ),
        ],
      );
    }
    final p = s.data.audioProfile;
    final mode = a.mode ?? s.resolved?.audioMode ?? p?.modes.firstOrNull;
    final rates = p?.rates ?? const <int>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toggle,
        PanelColumns(
          left: [
            FieldAnchor(
              fields: ['$_path.encoder', 'audio.encoder'],
              child: VeField(
                label: 'Encoder',
                modified: s.modified('$_path.encoder'),
                onReset: s.reset('$_path.encoder'),
                blurb: p == null || p.blurb.isEmpty ? null : Text(p.blurb),
                messages: s.messages(['$_path.encoder', 'audio.encoder']),
                child: VeEncoderPicker(
                  groups: encoderGroups(s.catalog, video: false, installation: s.data.installation),
                  selectedId: a.encoder,
                  kindLabel: 'Audio',
                  installationLabel: s.data.installation?.label ?? 'FFmpeg',
                  closedDetail: p?.codec,
                  onChanged: (id) => s.edit((r) => r.withAudioEncoder(id, s.catalog.audioEncoder(id))),
                ),
              ),
            ),
            if (p != null && p.modes.length > 1)
              FieldAnchor(
                fields: ['$_path.mode'],
                child: VeField(
                  label: 'Rate control',
                  modified: s.modified('$_path.mode'),
                  onReset: s.reset('$_path.mode'),
                  messages: s.messages(['$_path.mode']),
                  child: VeSegmented<String>(
                    semanticLabel: 'Audio rate control',
                    expand: true,
                    segments: [for (final m in p.modes) VeSegment(m, m == 'bitrate' ? 'Bitrate' : 'Variable quality')],
                    selected: mode,
                    onChanged: (m) => s.edit((r) => r.withAudio((a) => a.copyWith(mode: m))),
                  ),
                ),
              ),
            ?_rate(s, p, mode),
          ],
          right: [
            FieldAnchor(
              fields: ['$_path.sampleRate'],
              child: VeField(
                label: 'Sample rate',
                modified: s.modified('$_path.sampleRate'),
                onReset: s.reset('$_path.sampleRate'),
                messages: s.messages(['$_path.sampleRate']),
                child: VeSelect<Object>(
                  semanticLabel: 'Sample rate',
                  value: a.sampleRate,
                  options: [
                    VeOption<Object>(
                      'source',
                      media == null ? 'Same as VEGAS' : 'Same as VEGAS, ${kiloHertz(media.rate)}',
                    ),
                    for (final x in rates) VeOption<Object>(x, kiloHertz(x)),
                  ],
                  onChanged: (x) => s.edit((r) => r.withAudio((a) => a.copyWith(sampleRate: x))),
                ),
              ),
            ),
            FieldAnchor(
              fields: ['$_path.channels'],
              child: VeField(
                label: 'Channels',
                modified: s.modified('$_path.channels'),
                onReset: s.reset('$_path.channels'),
                messages: s.messages(['$_path.channels']),
                child: VeSelect<String>(
                  semanticLabel: 'Channels',
                  value: a.channels,
                  options: [
                    VeOption(
                      'source',
                      media == null ? 'Same as VEGAS' : 'Same as VEGAS, ${channelsLabel(media.channels)}',
                    ),
                    const VeOption('stereo', 'Stereo'),
                    const VeOption('mono', 'Mono'),
                  ],
                  onChanged: (x) => s.edit((r) => r.withAudio((a) => a.copyWith(channels: x))),
                ),
              ),
            ),
          ],
        ),
        PanelMore(
          child: FieldAnchor(
            fields: ['$_path.extra'],
            child: ExtraArgumentsField(
              kind: 'audio',
              value: a.extra,
              modified: s.modified('$_path.extra'),
              onReset: s.reset('$_path.extra'),
              messages: s.messages(['$_path.extra']),
              onChanged: (text) => s.edit((r) => r.withAudio((a) => a.copyWith(extra: text))),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _rate(PanelScope s, EncoderProfile? p, String? mode) {
    final a = s.recipe.audioTrack;
    if (p == null) return null;
    final bitrates = (p.bitrate['values'] as List?)?.cast<int>() ?? const <int>[];
    if (mode == 'bitrate' && bitrates.isNotEmpty) {
      return FieldAnchor(
        fields: ['$_path.bitrateK'],
        child: VeField(
          label: 'Bitrate',
          modified: s.modified('$_path.bitrateK'),
          onReset: s.reset('$_path.bitrateK'),
          messages: s.messages(['$_path.bitrateK']),
          blurb: const Text('Kilobits per second for all channels together.'),
          child: VeSegmented<int>(
            semanticLabel: 'Audio bitrate in kilobits per second',
            expand: true,
            segments: [for (final x in bitrates) VeSegment(x, '$x')],
            selected: a.bitrateK ?? p.bitrate['def'] as int?,
            onChanged: (x) => s.edit((r) => r.withAudio((a) => a.copyWith(bitrateK: x))),
          ),
        ),
      );
    }
    if (mode == 'vbr' && p.vbr != null) {
      final q = p.vbr!;
      final value = a.vbr ?? q.def ?? q.min;
      return FieldAnchor(
        fields: ['$_path.vbr'],
        child: VeField(
          label: 'Quality',
          modified: s.modified('$_path.vbr'),
          onReset: s.reset('$_path.vbr'),
          messages: s.messages(['$_path.vbr']),
          readout: VeReadout(value: 'VBR ${value.round()}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VeSlider(
                value: value,
                min: q.min,
                max: q.max,
                reversed: q.lowerIsBetter,
                semanticLabel: 'Audio quality. Right is higher quality',
                onChanged: (x) => s.edit((r) => r.withAudio((a) => a.copyWith(vbr: x.round()))),
              ),
              const SizedBox(height: 2),
              const VeSliderEnds(left: 'Smaller file', right: 'Higher quality'),
            ],
          ),
        ),
      );
    }
    if (p.level != null) {
      final l = p.level!;
      final value = (a.level ?? l.def ?? l.min).toDouble();
      return FieldAnchor(
        fields: ['$_path.level'],
        child: VeField(
          label: 'Compression level',
          modified: s.modified('$_path.level'),
          onReset: s.reset('$_path.level'),
          messages: s.messages(['$_path.level']),
          readout: VeReadout(value: '${value.round()}'),
          blurb: const Text('Lossless at every level.'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VeSlider(
                value: value,
                min: l.min,
                max: l.max,
                semanticLabel: 'Compression level',
                onChanged: (x) => s.edit((r) => r.withAudio((a) => a.copyWith(level: x.round()))),
              ),
              const SizedBox(height: 2),
              const VeSliderEnds(left: 'Faster', right: 'Smaller file'),
            ],
          ),
        ),
      );
    }
    if (mode == 'lossless') {
      final bits = p.data['bits'] as int?;
      return VeField(
        label: 'Lossless',
        child: PanelStatic(
          bits == null
              ? 'Decodes to exactly the samples VEGAS delivered.'
              : '$bits-bit ${p.family == 'pcmf' ? 'float' : 'integer'} samples, uncompressed.',
        ),
      );
    }
    return null;
  }
}
