import 'package:flutter/widgets.dart';
import 'package:ve_services/ve_services.dart';

import '../../../design/components/field.dart';
import '../../../design/components/segmented.dart';
import '../../../design/components/select.dart';
import '../../../design/components/popover.dart';
import '../../../design/components/slider.dart';
import '../../../design/components/text_field.dart';
import '../../../design/tokens.dart';
import '../../../state/recipe_edit.dart';
import '../display.dart';
import 'bitrate_field.dart';
import 'extra_field.dart';
import 'field_anchor.dart';
import 'panel_kit.dart';

/// The Video encoder node's settings (UI_SPEC §2, Basic editor). Controls the
/// encoder doesn't have are hidden; their recipe values stay.
class VideoPanel extends StatelessWidget {
  const VideoPanel({super.key, required this.scope});
  final PanelScope scope;

  @override
  Widget build(BuildContext context) {
    final s = scope;
    final v = s.recipe.video;
    if (!v.enabled) return const PanelStatic('Video is off.');
    final p = s.data.videoProfile;
    final mode = v.mode ?? s.resolved?.videoMode ?? p?.modes.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelColumns(
          left: [
            FieldAnchor(
              fields: ['video.encoder'],
              child: VeField(
                label: 'Encoder',
                modified: s.modified('video.encoder'),
                onReset: s.reset('video.encoder'),
                blurb: p == null || p.blurb.isEmpty ? null : Text(p.blurb),
                messages: s.messages(['video.encoder']),
                child: VeEncoderPicker(
                  groups: encoderGroups(s.catalog, video: true, installation: s.data.installation),
                  selectedId: v.encoder,
                  kindLabel: 'Video',
                  installationLabel: s.data.installation?.label ?? 'FFmpeg',
                  closedDetail: p == null ? null : '${p.codec}, ${runsOn(p)}',
                  onChanged: (id) => s.edit((r) => r.withVideoEncoder(id, s.catalog.videoEncoder(id))),
                ),
              ),
            ),
            if (p != null && p.modes.length > 1)
              FieldAnchor(
                fields: ['video.mode'],
                child: VeField(
                  label: 'Rate control',
                  modified: s.modified('video.mode'),
                  onReset: s.reset('video.mode'),
                  messages: s.messages(['video.mode']),
                  blurb: mode == null
                      ? null
                      : _ModeBlurb(label: s.catalog.rateModeLabel(mode), blurb: s.catalog.rateModeBlurb(mode)),
                  child: VeSegmented<String>(
                    semanticLabel: 'Rate control',
                    expand: true,
                    segments: [for (final m in p.modes) VeSegment(m, s.catalog.rateModeShort(m))],
                    selected: mode,
                    onChanged: (m) => s.edit((r) => r.withVideo((v) => v.copyWith(mode: m))),
                  ),
                ),
              ),
            ..._quality(s, p, mode),
          ],
          right: [
            if (p?.speed case final speed?) _speed(s, speed),
            if (_selects(s, p, mode) case final selects when selects.isNotEmpty) PanelRow(children: selects),
            if (p != null) _depth(s, p),
            // A row of its own, so "2 s (60 frames at 29.97 fps)" fits.
            if (mode != 'profile' && mode != 'lossless') _keyframes(s),
            _color(s),
          ],
        ),
        PanelMore(
          child: FieldAnchor(
            fields: ['video.extra'],
            child: ExtraArgumentsField(
              kind: 'video',
              value: v.extra,
              modified: s.modified('video.extra'),
              onReset: s.reset('video.extra'),
              messages: s.messages(['video.extra']),
              onChanged: (text) => s.edit((r) => r.withVideo((v) => v.copyWith(extra: text))),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _quality(PanelScope s, EncoderProfile? p, String? mode) {
    final v = s.recipe.video;
    switch (mode) {
      case 'crf' || 'cq' when p?.quality != null:
        final q = p!.quality!;
        final value = (v.quality ?? s.resolved?.quality ?? q.def ?? q.min).round();
        return [
          FieldAnchor(
            fields: ['video.quality'],
            child: VeQualityControl(
              scale: qualityScale(q),
              value: value,
              modified: s.modified('video.quality'),
              onReset: s.reset('video.quality'),
              messages: s.messages(['video.quality']),
              onChanged: (n) => s.edit((r) => r.withVideo((v) => v.copyWith(quality: n))),
            ),
          ),
        ];
      case 'abr' || 'cbr':
        return [
          FieldAnchor(
            fields: ['video.bitrateK'],
            child: VeField(
              label: mode == 'abr' ? 'Average bitrate' : 'Bitrate',
              modified: s.modified('video.bitrateK'),
              onReset: s.reset('video.bitrateK'),
              messages: s.messages(['video.bitrateK']),
              readout: VeReadout(value: bitrateMeaning(mode!, v.bitrateK, mode == 'abr' ? v.maxrateK : null)),
              child: BitrateField(
                valueK: v.bitrateK,
                semanticLabel: 'Video bitrate in megabits per second',
                onChanged: (k) => s.edit((r) => r.withVideo((v) => v.copyWith(bitrateK: k))),
              ),
            ),
          ),
          if (mode == 'abr')
            FieldAnchor(
              fields: ['video.maxrateK'],
              child: VeField(
                label: 'Peak bitrate',
                modified: s.modified('video.maxrateK'),
                onReset: s.reset('video.maxrateK'),
                messages: s.messages(['video.maxrateK']),
                blurb: const Text('Leave empty for no cap. A cap keeps busy scenes within what players can stream.'),
                child: BitrateField(
                  valueK: v.maxrateK,
                  placeholder: 'No cap',
                  semanticLabel: 'Peak bitrate in megabits per second',
                  onChanged: (k) => s.edit((r) => r.withVideo((v) => v.copyWith(maxrateK: k))),
                ),
              ),
            ),
        ];
      case 'cqp' when p?.qp != null:
        return [
          FieldAnchor(
            fields: ['video.qp'],
            child: VeField(
              label: 'Quantizer',
              modified: s.modified('video.qp'),
              onReset: s.reset('video.qp'),
              messages: s.messages(['video.qp']),
              child: VeNumberField(
                value: v.qp ?? p!.qp!.def,
                unit: 'lower is higher quality',
                width: 100,
                semanticLabel: 'Quantizer',
                onChanged: (n) => s.edit((r) => r.withVideo((v) => v.copyWith(qp: n == null ? null : jsonNumber(n)))),
              ),
            ),
          ),
        ];
      case 'profile' when p?.profileQuality != null:
        final pq = p!.profileQuality!;
        return [
          FieldAnchor(
            fields: ['video.profile'],
            child: VeField(
              label: 'Profile',
              modified: s.modified('video.profile'),
              onReset: s.reset('video.profile'),
              messages: s.messages(['video.profile']),
              blurb: const Text('The profile sets the data rate. There is no quality dial.'),
              child: VeSegmented<String>(
                semanticLabel: 'Profile',
                expand: true,
                segments: [for (final x in pq.values) VeSegment(x, choiceName(pq, x))],
                selected: v.profile ?? s.resolved?.profile ?? pq.def,
                onChanged: (x) => s.edit((r) => r.withVideo((v) => v.copyWith(profile: x))),
              ),
            ),
          ),
        ];
      case 'lossless':
        return [
          const VeField(
            label: 'Lossless',
            child: PanelStatic('Every frame decodes to exactly the pixels VEGAS delivered. Nothing to tune.'),
          ),
        ];
    }
    return const [];
  }

  Widget _speed(PanelScope s, ChoiceControl speed) {
    final values = speedOrder(speed);
    final current = s.recipe.video.speed ?? s.resolved?.speed ?? speed.def ?? values.first;
    final index = values.indexOf(current);
    return FieldAnchor(
      fields: ['video.speed'],
      child: VeField(
        label: 'Encoder speed',
        modified: s.modified('video.speed'),
        onReset: s.reset('video.speed'),
        messages: s.messages(['video.speed']),
        readout: VeReadout(value: choiceName(speed, current)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VeSlider(
              value: (index < 0 ? 0 : index).toDouble(),
              min: 0,
              max: (values.length - 1).toDouble(),
              semanticLabel: 'Encoder speed',
              semanticValue: (x) => choiceName(speed, values[x.round()]),
              onChanged: (x) => s.edit((r) => r.withVideo((v) => v.copyWith(speed: values[x.round()]))),
            ),
            const SizedBox(height: 2),
            VeSliderEnds(left: speed.slowLabel, right: speed.fastLabel),
          ],
        ),
      ),
    );
  }

  List<Widget> _selects(PanelScope s, EncoderProfile? p, String? mode) {
    final v = s.recipe.video;
    return [
      if (p?.tune case final tune?)
        FieldAnchor(
          fields: ['video.tune'],
          child: VeField(
            label: 'Tune',
            modified: s.modified('video.tune'),
            onReset: s.reset('video.tune'),
            messages: s.messages(['video.tune']),
            child: VeSelect<String?>(
              semanticLabel: 'Tune',
              value: v.tune,
              options: [const VeOption<String?>(null, 'None'), for (final x in tune.values) VeOption<String?>(x, x)],
              onChanged: (x) => s.edit((r) => r.withVideo((v) => v.copyWith(tune: x))),
            ),
          ),
        ),
      if (p?.profile case final profile? when mode != 'profile')
        FieldAnchor(
          fields: ['video.profile'],
          child: VeField(
            label: 'Profile',
            modified: s.modified('video.profile'),
            onReset: s.reset('video.profile'),
            messages: s.messages(['video.profile']),
            child: VeSelect<String>(
              semanticLabel: 'Profile',
              value: v.profile ?? s.resolved?.profile ?? profile.def,
              options: [for (final x in profile.values) VeOption(x, x)],
              onChanged: (x) => s.edit((r) => r.withVideo((v) => v.copyWith(profile: x))),
            ),
          ),
        ),
      if (p?.multipass case final multipass?)
        FieldAnchor(
          fields: ['video.multipass'],
          child: VeField(
            label: 'Multipass',
            modified: s.modified('video.multipass'),
            onReset: s.reset('video.multipass'),
            messages: s.messages(['video.multipass']),
            child: VeSelect<String?>(
              semanticLabel: 'Multipass',
              value: v.multipass,
              options: [
                const VeOption<String?>(null, 'Encoder default'),
                for (final x in multipass.values) VeOption<String?>(x, _multipassNames[x] ?? x),
              ],
              onChanged: (x) => s.edit((r) => r.withVideo((v) => v.copyWith(multipass: x))),
            ),
          ),
        ),
    ];
  }

  Widget _depth(PanelScope s, EncoderProfile p) {
    final depths = p.depths.keys.map(int.parse).toList()..sort();
    final depth = s.recipe.video.depth ?? s.resolved?.depth ?? p.depthDef ?? depths.first;
    final pixfmt = s.resolved?.pixfmt ?? p.depths['$depth'] as String?;
    return FieldAnchor(
      fields: ['video.depth'],
      child: VeField(
        label: 'Bit depth',
        modified: s.modified('video.depth'),
        onReset: s.reset('video.depth'),
        messages: s.messages(['video.depth']),
        readout: depths.length > 1 && pixfmt != null ? VeReadout(value: pixfmt, mono: true) : null,
        child: depths.length > 1
            ? Align(
                alignment: Alignment.centerLeft,
                child: VeSegmented<int>(
                  semanticLabel: 'Bit depth',
                  segments: [for (final d in depths) VeSegment(d, '$d-bit')],
                  selected: depth,
                  onChanged: (d) => s.edit((r) => r.withVideo((v) => v.copyWith(depth: d))),
                ),
              )
            : PanelStatic('${pixfmt ?? '$depth-bit'}, fixed by ${p.label}'),
      ),
    );
  }

  Widget _keyframes(PanelScope s) {
    const fields = ['video.gopSec', 'video.gop'];
    final readout = keyframesReadout(
      gopFrames: s.resolved?.gopFrames,
      gopSec: s.recipe.video.gopSec,
      overridden: s.overridden(fields),
      media: s.data.media,
    );
    return FieldAnchor(
      fields: fields,
      child: VeField(
        label: 'Keyframes every',
        modified: s.modified('video.gopSec'),
        onReset: s.reset('video.gopSec'),
        messages: s.messages(fields),
        readout: readout == null ? null : VeReadout(value: readout.value, meaning: readout.meaning),
        child: VeNumberField(
          value: s.recipe.video.gopSec,
          unit: 'seconds',
          decimals: true,
          placeholder: 'Default',
          semanticLabel: 'Keyframe interval in seconds',
          onChanged: (n) => s.edit((r) => r.withVideo((v) => v.copyWith(gopSec: n == null ? null : jsonNumber(n)))),
        ),
      ),
    );
  }

  Widget _color(PanelScope s) => FieldAnchor(
    fields: ['video.color'],
    child: VeField(
      label: 'Color tags',
      modified: s.modified('video.color'),
      onReset: s.reset('video.color'),
      messages: s.messages(['video.color']),
      child: VeSelect<String>(
        semanticLabel: 'Color tags',
        value: s.recipe.video.color,
        options: const [VeOption('bt709', 'BT.709, SDR'), VeOption('none', 'Don’t write tags')],
        onChanged: (x) => s.edit((r) => r.withVideo((v) => v.copyWith(color: x))),
      ),
    ),
  );
}

const _multipassNames = {'disabled': 'Off', 'qres': 'Quarter resolution', 'fullres': 'Full resolution'};

/// "**Constant quality.** Every scene gets the same visual quality…"
class _ModeBlurb extends StatelessWidget {
  const _ModeBlurb({required this.label, required this.blurb});
  final String label;
  final String blurb;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label. ',
            style: TextStyle(color: t.colors.ink, fontWeight: const FontWeight(600)),
          ),
          TextSpan(text: blurb),
        ],
      ),
    );
  }
}
