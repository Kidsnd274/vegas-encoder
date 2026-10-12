import 'package:flutter/widgets.dart';

import '../../design/components/button.dart';
import '../../design/components/command_view.dart';
import '../../design/components/field.dart';
import '../../design/components/message.dart';
import '../../design/components/popover.dart';
import '../../design/components/segmented.dart';
import '../../design/components/select.dart';
import '../../design/components/signal_path/signal_path.dart';
import '../../design/components/size_card.dart';
import '../../design/components/slider.dart';
import '../../design/components/status.dart';
import '../../design/components/switch.dart';
import '../../design/components/text_field.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import 'samples.dart';

/// A titled panel in the gallery.
class GallerySection extends StatelessWidget {
  const GallerySection({super.key, required this.title, required this.child, this.note, this.padded = true});

  final String title;
  final String? note;
  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(VeRadius.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(title, style: t.text.panelTitle),
                if (note != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(note!, style: t.text.small.copyWith(color: c.muted)),
                  ),
                ],
              ],
            ),
          ),
          if (padded) Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: child) else child,
        ],
      ),
    );
  }
}

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class TokensSection extends StatelessWidget {
  const TokensSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final swatches = <(String, Color)>[
      ('Paper', c.paper),
      ('Grid dots', c.dots),
      ('Surface', c.surface),
      ('Ink', c.ink),
      ('Muted', c.muted),
      ('Line', c.line2),
      ('Video wire', c.videoWire),
      ('Audio wire', c.audioWire),
      ('Conversion pip', c.pip),
      ('Container', c.containerWire),
      ('Error', c.error),
      ('Warning', c.warning),
      ('Ready', c.success),
      ('Macro', c.macro),
    ];
    return GallerySection(
      title: 'Tokens',
      note: 'Colours from the mockup’s :root, ${t.brightness == Brightness.dark ? 'dark' : 'light'} set.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              for (final (name, color) in swatches)
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: t.shadow(0.16)),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(name, style: t.text.captionStrong),
                      Text(_hex(color), style: t.text.caption.copyWith(color: c.muted)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: c.line),
          const SizedBox(height: 14),
          Wrap(
            spacing: 28,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text('Instrument Sans', style: t.text.headline),
              Text('UI and labels, 13 px base', style: t.text.small.copyWith(color: c.muted)),
              Text('-c:v libx264 -crf 18', style: t.text.mono.copyWith(fontSize: 14)),
              Text('JetBrains Mono, command only. Both OFL, bundled.', style: t.text.small.copyWith(color: c.muted)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final i in VeIcons.all) VeIcon(i, color: c.ink),
              const VeLogo(),
              const WireGlyph(outputDepth: 8),
              const WireGlyph(outputDepth: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class ButtonsSection extends StatefulWidget {
  const ButtonsSection({super.key});

  @override
  State<ButtonsSection> createState() => _ButtonsSectionState();
}

class _ButtonsSectionState extends State<ButtonsSection> {
  bool _favorite = true;
  bool _favoritesOnly = false;
  bool _pinned = true;

  @override
  Widget build(BuildContext context) {
    final c = VeTokens.of(context).colors;
    return GallerySection(
      title: 'Buttons',
      note: 'Primary, secondary, ghost and small; icon buttons; a text link; key caps.',
      child: Wrap(
        spacing: 10,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          VeButton(label: 'Save preset', icon: VeIcons.save, variant: VeButtonVariant.primary, onPressed: () {}),
          const VeButton(
            label: 'Save as new preset',
            icon: VeIcons.save,
            variant: VeButtonVariant.primary,
            onPressed: null,
            tooltip: 'Nothing changed yet.',
          ),
          VeButton(label: 'Duplicate', icon: VeIcons.layers, onPressed: () {}),
          VeButton(label: 'Load preset', icon: VeIcons.folder, onPressed: () {}),
          VeButton(label: 'Save to library', icon: VeIcons.save, trailingIcon: VeIcons.chevronDown, onPressed: () {}),
          VeButton(label: 'Cancel', variant: VeButtonVariant.ghost, onPressed: () {}),
          VeButton(
            label: 'Copy',
            icon: VeIcons.copy,
            variant: VeButtonVariant.ghost,
            size: VeButtonSize.small,
            onPressed: () {},
          ),
          VeButton(
            label: 'Replace with revision 6',
            variant: VeButtonVariant.primary,
            size: VeButtonSize.small,
            onPressed: () {},
          ),
          VeButton(label: 'Take library changes, keep mine', size: VeButtonSize.small, onPressed: () {}),
          VeIconButton(
            icon: VeIcons.star,
            selectedIcon: VeIcons.starFilled,
            label: 'Favorite',
            selected: _favorite,
            selectedColor: c.favorite,
            dimension: 24,
            onPressed: () => setState(() => _favorite = !_favorite),
          ),
          VeIconButton(
            icon: VeIcons.star,
            selectedIcon: VeIcons.starFilled,
            label: 'Favorites only',
            selected: _favoritesOnly,
            selectedColor: c.favorite,
            selectedBackground: c.favoriteBackground,
            bordered: true,
            onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
          ),
          VeIconButton(
            icon: VeIcons.pin,
            label: 'Keep on top',
            selected: _pinned,
            dimension: 34,
            onPressed: () => setState(() => _pinned = !_pinned),
          ),
          VeLinkButton(label: 'Show setting', onPressed: () {}),
          const Row(mainAxisSize: MainAxisSize.min, children: [VeKbd('Ctrl'), SizedBox(width: 4), VeKbd('Space')]),
        ],
      ),
    );
  }
}

class InputsSection extends StatefulWidget {
  const InputsSection({super.key});

  @override
  State<InputsSection> createState() => _InputsSectionState();
}

class _InputsSectionState extends State<InputsSection> {
  String _extra = '-bf 3 -foo 1';
  num? _bitrate = 8000;
  num? _gop = 2;

  @override
  Widget build(BuildContext context) {
    final unknown = _extra.split(RegExp(r'\s+')).where((a) => a == '-foo').toList();
    return GallerySection(
      title: 'Inputs',
      note: 'Search, Extra arguments (monospace, with its option check), numbers with units.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 228,
                child: VeTextField(
                  search: true,
                  placeholder: 'Search name, encoder or tag',
                  semanticLabel: 'Search presets',
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: VeField(
                  label: 'Average bitrate',
                  readout: VeReadout(value: '${((_bitrate ?? 0) / 1000).toStringAsFixed(1)} Mb/s'),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: VeNumberField(
                      value: _bitrate,
                      unit: 'kb/s',
                      semanticLabel: 'Video bitrate',
                      onChanged: (v) => setState(() => _bitrate = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: VeField(
                  label: 'Keyframes every',
                  readout: VeReadout(value: '${((_gop ?? 0) * 30).round()} frames'),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: VeNumberField(
                      value: _gop,
                      unit: 'seconds',
                      decimals: true,
                      semanticLabel: 'Keyframe interval in seconds',
                      onChanged: (v) => setState(() => _gop = v),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          VeField(
            label: 'Extra arguments',
            blurb: const Text(
              'For anything without a control here. An option typed here replaces the generated one of the same name.',
            ),
            messages: [
              for (final u in unknown)
                VeMessage(
                  level: VeLevel.warning,
                  text: '$u isn’t an option of x264 in FFmpeg 8.1 full.',
                  fix: 'FFmpeg stops with an error if it doesn’t know an option. Check the spelling.',
                ),
            ],
            child: VeTextField(
              mono: true,
              initialValue: _extra,
              placeholder: 'Such as -bf 3',
              semanticLabel: 'Extra video arguments',
              onChanged: (s) => setState(() => _extra = s),
            ),
          ),
        ],
      ),
    );
  }
}

class ChoicesSection extends StatefulWidget {
  const ChoicesSection({super.key});

  @override
  State<ChoicesSection> createState() => _ChoicesSectionState();
}

class _ChoicesSectionState extends State<ChoicesSection> {
  String _mode = 'Basic';
  String _rate = 'Quality';
  int _depth = 8;
  bool _audio = true;
  bool _problems = false;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return GallerySection(
      title: 'Segmented controls and switches',
      note: 'Arrow keys move a segmented choice.',
      child: Wrap(
        spacing: 28,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: [
          VeSegmented<String>(
            semanticLabel: 'Editing mode',
            segments: const [VeSegment('Basic', 'Basic'), VeSegment('Advanced', 'Advanced')],
            selected: _mode,
            onChanged: (v) => setState(() => _mode = v),
          ),
          SizedBox(
            width: 340,
            child: VeField(
              label: 'Rate control',
              blurb: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Constant quality. ',
                      style: TextStyle(color: t.colors.ink, fontWeight: const FontWeight(600)),
                    ),
                    const TextSpan(text: 'Every scene gets the same visual quality; file size varies with content.'),
                  ],
                ),
              ),
              child: VeSegmented<String>(
                semanticLabel: 'Rate control',
                expand: true,
                segments: const [
                  VeSegment('Quality', 'Quality'),
                  VeSegment('Bitrate', 'Bitrate'),
                  VeSegment('CBR', 'CBR'),
                  VeSegment('QP', 'QP'),
                ],
                selected: _rate,
                onChanged: (v) => setState(() => _rate = v),
              ),
            ),
          ),
          SizedBox(
            width: 340,
            child: VeField(
              label: 'Bit depth',
              readout: VeReadout(
                value: _depth == 8 ? 'yuv420p' : 'yuv420p10le',
                meaning: ', $_depth-bit 4:2:0',
                mono: true,
              ),
              messages: [
                if (_depth == 8)
                  const VeMessage(
                    level: VeLevel.info,
                    text: 'VEGAS delivers 10-bit frames. This encode stores 8-bit, which can show banding in smooth gradients.',
                  ),
              ],
              child: Align(
                alignment: Alignment.centerLeft,
                child: VeSegmented<int>(
                  semanticLabel: 'Bit depth',
                  segments: const [VeSegment(8, '8-bit'), VeSegment(10, '10-bit')],
                  selected: _depth,
                  onChanged: (v) => setState(() => _depth = v),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VeSwitch(value: _audio, label: 'Audio', onChanged: (v) => setState(() => _audio = v)),
              const SizedBox(height: 14),
              VeSwitch(
                value: _problems,
                small: true,
                label: 'Only show problems',
                onChanged: (v) => setState(() => _problems = v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PickersSection extends StatefulWidget {
  const PickersSection({super.key});

  @override
  State<PickersSection> createState() => _PickersSectionState();
}

class _PickersSectionState extends State<PickersSection> {
  String _encoder = 'libx264';
  String _tune = 'None';
  String _profile = 'high';

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      title: 'Pickers',
      note: 'Encoder picker grouped by codec with availability; selects. Unavailable encoders stay selectable.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: VeField(
              label: 'Encoder',
              blurb: const Text('Plays everywhere. Excellent quality for its size; runs on the CPU.'),
              child: VeEncoderPicker(
                groups: Samples.videoEncoders,
                selectedId: _encoder,
                kindLabel: 'Video',
                installationLabel: 'FFmpeg 8.1 full',
                onChanged: (v) => setState(() => _encoder = v),
              ),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: VeField(
                    label: 'Tune',
                    child: VeSelect<String>(
                      semanticLabel: 'Tune',
                      value: _tune,
                      options: [
                        for (final v in const [
                          'None',
                          'film',
                          'animation',
                          'grain',
                          'stillimage',
                          'fastdecode',
                          'zerolatency',
                        ])
                          VeOption(v, v),
                      ],
                      onChanged: (v) => setState(() => _tune = v),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: VeField(
                    label: 'Profile',
                    child: VeSelect<String>(
                      semanticLabel: 'Profile',
                      value: _profile,
                      options: [
                        for (final v in const ['baseline', 'main', 'high', 'high10', 'high422', 'high444'])
                          VeOption(v, v),
                      ],
                      onChanged: (v) => setState(() => _profile = v),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SlidersSection extends StatefulWidget {
  const SlidersSection({super.key});

  @override
  State<SlidersSection> createState() => _SlidersSectionState();
}

class _SlidersSectionState extends State<SlidersSection> {
  int _crf = 18;
  int _speed = 3;

  @override
  Widget build(BuildContext context) {
    final speed = Samples.x264Speeds[_speed];
    return GallerySection(
      title: 'Quality and speed',
      note: 'Right is always higher quality: CRF runs 51 to 0. The band marks the recommended range.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: VeQualityControl(scale: Samples.crf, value: _crf, onChanged: (v) => setState(() => _crf = v)),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: VeField(
              label: 'Encoder speed',
              readout: VeReadout(value: speed),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  VeSlider(
                    value: _speed.toDouble(),
                    min: 0,
                    max: (Samples.x264Speeds.length - 1).toDouble(),
                    semanticLabel: 'Encoder speed',
                    semanticValue: (v) => Samples.x264Speeds[v.round()],
                    onChanged: (v) => setState(() => _speed = v.round()),
                  ),
                  const SizedBox(height: 2),
                  const VeSliderEnds(left: 'Smaller file', right: 'Faster encode'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessagesSection extends StatelessWidget {
  const MessagesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      title: 'Messages and checks',
      note: 'At the field, and summarised beside the command. Colour always comes with an icon and words.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VeMessage(
                  level: VeLevel.error,
                  text: 'QSV HEVC isn’t in FFmpeg 8.1 full. Not listed by this FFmpeg.',
                  fix: 'Choose another encoder, or choose another FFmpeg.',
                ),
                SizedBox(height: 6),
                VeMessage(
                  level: VeLevel.warning,
                  text: '-foo isn’t an option of x264 in FFmpeg 8.1 full.',
                  fix: 'FFmpeg stops with an error if it doesn’t know an option. Check the spelling.',
                ),
                SizedBox(height: 6),
                VeMessage(
                  level: VeLevel.info,
                  text: 'VEGAS delivers 10-bit frames. This encode stores 8-bit, which can show banding in smooth gradients.',
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    VeStatusTag(VeAvailability.ready),
                    SizedBox(width: 16),
                    VeStatusTag(VeAvailability.missing),
                    SizedBox(width: 16),
                    VeStatusTag(VeAvailability.failed),
                    SizedBox(width: 16),
                    VeStatusTag(VeAvailability.testing),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VeCheckList(
                  emptyText: 'No problems with FFmpeg 8.1 full.',
                  checks: [
                    VeCheck(
                      level: VeLevel.info,
                      text: 'Fast start rewrites the file once encoding ends so playback can begin before download finishes. Large renders take a little longer to finish.',
                      actionLabel: 'Show setting',
                      onAction: () {},
                    ),
                    VeCheck(
                      level: VeLevel.info,
                      text: 'VEGAS delivers 10-bit frames. This encode stores 8-bit, which can show banding in smooth gradients.',
                      actionLabel: 'Show setting',
                      onAction: () {},
                    ),
                    const VeCheck(
                      level: VeLevel.error,
                      text: 'NVENC HEVC failed its test encode on this PC.',
                      fix: 'Choose another encoder, or test again after updating the driver.',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const VeCheckList(emptyText: 'No problems with FFmpeg 8.1 full.', checks: []),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The full desktop diagram with a live selection.
class SignalPathSection extends StatefulWidget {
  const SignalPathSection({
    super.key,
    this.model = Samples.youtube,
    this.title = 'Signal path',
    this.note,
    this.initial = SignalNode.video,
  });

  final SignalPathModel model;
  final String title;
  final String? note;
  final SignalNode initial;

  @override
  State<SignalPathSection> createState() => _SignalPathSectionState();
}

class _SignalPathSectionState extends State<SignalPathSection> {
  late SignalNode _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      title: widget.title,
      note:
          widget.note ??
          'Wire thickness is bit depth; the pip marks the 10 to 8-bit conversion. Arrow keys move between nodes.',
      padded: false,
      child: SignalPath(model: widget.model, selected: _selected, onSelect: (n) => setState(() => _selected = n)),
    );
  }
}

class StripSection extends StatefulWidget {
  const StripSection({super.key});

  @override
  State<StripSection> createState() => _StripSectionState();
}

class _StripSectionState extends State<StripSection> {
  SignalNode _selected = SignalNode.video;

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      title: 'Signal path strip (popup)',
      note: 'One row; a dot marks a change in this template, the badge a newer library revision.',
      padded: false,
      child: Center(
        child: SizedBox(
          width: 752,
          child: SignalPath(
            model: Samples.popupStrip,
            layout: SignalPathLayout.strip,
            selected: _selected,
            onSelect: (n) => setState(() => _selected = n),
          ),
        ),
      ),
    );
  }
}

class FileAndCommandSection extends StatefulWidget {
  const FileAndCommandSection({super.key});

  @override
  State<FileAndCommandSection> createState() => _FileAndCommandSectionState();
}

class _FileAndCommandSectionState extends State<FileAndCommandSection> {
  int? _length = 600;
  CommandRole _role = CommandRole.video;
  String? _tapped;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return GallerySection(
      title: 'Size and quality, and the command',
      note: 'The estimate lives behind the File node only. Click a token to find its control.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 340,
            child: Column(
              children: [
                SizeQualityCard(
                  estimate: Samples.estimate,
                  lengthSeconds: _length,
                  onLengthChanged: (v) => setState(() => _length = v),
                ),
                const SizedBox(height: 16),
                SizeQualityCard(
                  estimate: Samples.estimateBitrate,
                  lengthSeconds: null,
                  onLengthChanged: (_) {},
                  lengthHint: 'Project length from VEGAS.',
                  compact: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CommandHeader(onCopy: () => copyCommand(Samples.command.copyText)),
                const SizedBox(height: 8),
                CommandView(
                  command: Samples.command,
                  activeRole: _role,
                  litFields: const {'video.quality'},
                  onTokenTap: (tok) => setState(() => _tapped = tok.field),
                ),
                const SizedBox(height: 10),
                VeSegmented<CommandRole>(
                  semanticLabel: 'Highlighted group',
                  segments: const [
                    VeSegment(CommandRole.video, 'Video'),
                    VeSegment(CommandRole.audio, 'Audio'),
                    VeSegment(CommandRole.mux, 'Container'),
                    VeSegment(CommandRole.output, 'File'),
                  ],
                  selected: _role,
                  onChanged: (r) => setState(() => _role = r),
                ),
                if (_tapped != null) ...[
                  const SizedBox(height: 8),
                  Text('Clicked a token from $_tapped.', style: t.text.small.copyWith(color: t.colors.muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
