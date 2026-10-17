// Maps core and service results to the design system's display models. This is
// display work only: labels, grouping and formatting. Facts come from the core
// (compile, resolved settings, summary, issues, estimates) and from the profile
// catalog's tables; nothing here decides what FFmpeg does.

import 'package:ve_services/ve_services.dart' as core;

import '../../design/components/command_view.dart';
import '../../design/components/message.dart';
import '../../design/components/select.dart';
import '../../design/components/signal_path/signal_path_model.dart';
import '../../design/components/slider.dart';
import '../../design/components/status.dart';
import '../../design/format.dart';
import '../../state/editor.dart' show PreviewMedia;

// ------------------------------------------------------------ vocabulary

/// Preset categories (SETTINGS_AND_COMMANDS §2), in library order.
const presetCategories = <String, String>{
  'web': 'Web upload',
  'edit': 'Editing intermediate',
  'master': 'Master and archive',
  'review': 'Review',
  'social': 'Social',
  'custom': 'Custom command',
};

String categoryLabel(String id) => presetCategories[id] ?? 'Other';

/// The Save dialog's suggested name for an exported preset: the preset's
/// name with the characters Windows doesn't allow in a file name replaced,
/// plus `.vepreset` ("YouTube upload, H.264.vepreset").
String presetFileName(String name) {
  var base = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-').trim();
  base = base.replaceAll(RegExp(r'[. ]+$'), '');
  return '${base.isEmpty ? 'Preset' : base}.vepreset';
}

/// Display labels for what VEGAS delivers. The adapter sends P010 frames and
/// 32-bit float samples (ARCHITECTURE); other values show as FFmpeg names.
const _deliveredVideo = <String, ({String label, String short, int depth})>{
  'p010le': (label: 'P010, 10-bit 4:2:0', short: '10-bit', depth: 10),
};
const _deliveredAudio = <String, ({String label, String short, int bits})>{
  'f32le': (label: '32-bit float', short: 'float', bits: 32),
};

String deliveredPixelFormat(String pixfmt) => _deliveredVideo[pixfmt]?.label ?? pixfmt;
int? deliveredDepth(String pixfmt) => _deliveredVideo[pixfmt]?.depth;
String deliveredSampleFormat(String fmt) => _deliveredAudio[fmt]?.label ?? fmt;

/// What kind of samples an FFmpeg sample format holds, for wire labels. Bits
/// always come from the core's facts.
const _sampleKind = <String, String>{
  'flt': 'float',
  'fltp': 'float',
  'dbl': 'float',
  'dblp': 'float',
  's16': 'integer',
  's16p': 'integer',
  's32': 'integer',
  's32p': 'integer',
};

String channelsLabel(int channels) => switch (channels) {
  1 => 'mono',
  2 => 'stereo',
  6 => '5.1',
  8 => '7.1',
  _ => '$channels channels',
};

String kiloHertz(int rate) {
  final k = rate / 1000;
  return '${k == k.roundToDouble() ? k.round() : k} kHz';
}

/// "1920×1080, 29.97 fps, 48 kHz stereo"
String mediaSummary(core.MediaDescription media) {
  final v = media.video;
  final a = media.audio;
  return [
    '${v.width}×${v.height}',
    VeFormat.fps(v.fps[0], v.fps[1]),
    if (a != null) '${kiloHertz(a.rate)} ${channelsLabel(a.channels)}',
  ].join(', ');
}

/// "10 minutes", "1:30" for the preview context line.
String lengthPhrase(int seconds) =>
    seconds % 60 == 0 ? '${seconds ~/ 60} ${seconds == 60 ? 'minute' : 'minutes'}' : VeFormat.duration(seconds);

// ------------------------------------------------------------ catalog lookups

extension CatalogLookup on core.ProfileCatalog {
  core.EncoderProfile? videoEncoder(String id) => video.where((e) => e.id == id).firstOrNull;
  core.EncoderProfile? audioEncoder(String id) => audio.where((e) => e.id == id).firstOrNull;
  core.ContainerProfile? container(String id) => containers.where((c) => c.id == id).firstOrNull;

  /// The codec-to-container table: "ok", "warn" or "no"; null if not listed.
  String? compatibilityOf({required bool video, required String family, required String container}) {
    final table = core.jsonMap(compatibility[video ? 'video' : 'audio'] ?? <String, Object?>{});
    final row = table[family];
    return row is Map ? row[container] as String? : null;
  }

  Map<String, Object?> rateMode(String id) => core.jsonMap(rateModes[id] ?? <String, Object?>{});
  String rateModeShort(String id) => rateMode(id)['short'] as String? ?? id;
  String rateModeLabel(String id) => rateMode(id)['label'] as String? ?? id;
  String rateModeBlurb(String id) => rateMode(id)['blurb'] as String? ?? '';
}

/// "CRF", "CQ", "QP" from a quality control's flag.
String qualityUnit(String flag) => switch (flag) {
  '-crf' => 'CRF',
  '-cq' => 'CQ',
  '-qp' || '-qp_i' => 'QP',
  '-global_quality' => 'Quality',
  _ => flag.replaceFirst('-', '').toUpperCase(),
};

/// The note at a control whose option Extra arguments replaced (UI_SPEC §2;
/// C2 `overriddenFields`).
const setInExtraArguments = 'Set in Extra arguments.';

/// "**2 s** (60 frames at 29.97 fps)": the keyframe interval the core emits
/// (`resolved.gopFrames`, after Extra arguments and fixed GOPs) at the
/// delivered frame rate. The seconds are what the user typed, so they're left
/// out ("**120 frames** at 29.97 fps") when Extra arguments set the interval
/// or no seconds were typed. Null when the core emits no interval.
({String value, String meaning})? keyframesReadout({
  required int? gopFrames,
  required num? gopSec,
  required bool overridden,
  required core.MediaDescription media,
}) {
  if (gopFrames == null) return null;
  final frames = '${VeFormat.count(gopFrames)} ${gopFrames == 1 ? 'frame' : 'frames'}';
  final rate = 'at ${VeFormat.fps(media.video.fps[0], media.video.fps[1])}';
  if (gopSec == null || overridden) return (value: frames, meaning: ' $rate');
  return (value: '${_num(gopSec)} s', meaning: ' ($frames $rate)');
}

/// "MP4", "MKV" from the container's extension.
String containerShortName(core.ContainerProfile? c, String id) =>
    c == null ? id.toUpperCase() : c.ext.replaceFirst('.', '').toUpperCase();

String runsOn(core.EncoderProfile? p) => p?.hw == null ? 'CPU' : '${p!.hw} GPU';

VeAvailability availabilityOf(core.FFmpegInstallation? installation, String encoder) {
  if (installation == null) return VeAvailability.ready;
  final raw = installation.availability[encoder];
  if (raw is! Map) return VeAvailability.missing;
  return switch (raw['state']) {
    'ok' => VeAvailability.ready,
    'failed' => VeAvailability.failed,
    'missing' => VeAvailability.missing,
    _ => VeAvailability.unknown,
  };
}

String? availabilityReason(core.FFmpegInstallation? installation, String encoder) {
  final raw = installation?.availability[encoder];
  if (raw is! Map) return installation == null ? null : 'Not in ${installation.label}.';
  final reason = raw['reason'] as String?;
  return reason == null || reason.isEmpty ? null : reason;
}

// ------------------------------------------------------------ encoder pickers

List<VeEncoderGroup> encoderGroups(
  core.ProfileCatalog catalog, {
  required bool video,
  core.FFmpegInstallation? installation,
}) {
  final order = core.jsonMap(video ? catalog.videoOrder : catalog.audioOrder);
  final groups = (order['groups'] as List? ?? const []).cast<Map>();
  return [
    for (final g in groups)
      VeEncoderGroup(video ? g['group'] as String : '${g['group']} audio', [
        for (final id in (g['ids'] as List).cast<String>())
          if ((video ? catalog.videoEncoder(id) : catalog.audioEncoder(id)) case final p?)
            VeEncoderChoice(
              id: id,
              label: p.label,
              detail: video ? _videoChoiceDetail(p) : p.codec,
              availability: availabilityOf(installation, id),
              reason: availabilityReason(installation, id),
            ),
      ]),
  ];
}

String _videoChoiceDetail(core.EncoderProfile p) {
  final depths = p.depths.keys.map(int.parse).toList()..sort();
  final bits = depths.contains(10) ? (depths.contains(8) ? '10-bit' : '10-bit only') : '8-bit only';
  return '${p.codec}, ${runsOn(p)}, $bits';
}

// ------------------------------------------------------------ quality scale

VeQualityScale qualityScale(core.NumericControl q, {VeRange? recommended}) => VeQualityScale(
  unit: qualityUnit(q.flag),
  min: q.min.round(),
  max: q.max.round(),
  lowerIsBetter: q.lowerIsBetter,
  marks: [
    for (final m in q.marks)
      if (m.length >= 2 && m[0] is num && m[1] is String) VeQualityMark((m[0] as num).round(), m[1] as String),
  ],
  recommended: recommended,
);

/// Speed values from slowest to fastest, so the slider reads "Smaller file"
/// at the left and "Faster encode" at the right.
List<String> speedOrder(core.ChoiceControl speed) => speed.slowFirst ? speed.values : speed.values.reversed.toList();

String choiceName(core.ChoiceControl c, String value) => c.names[value] as String? ?? value;

// ------------------------------------------------------------ command

/// Groups the core's display tokens the way the command view draws them:
/// the VEGAS inputs collapse into a chip, `-map` joins the program line, and
/// each stage gets its own line. Extra arguments stay with their stream. Each
/// token keeps the recipe field the core says produced it, and tokens an
/// error issue points at (`tokenIndices`, display indexes) are marked.
CommandDisplay commandDisplay(core.CompileResult result, {required bool audio}) {
  final inputs = <CommandToken>[];
  final lines = <CommandRole, List<CommandToken>>{for (final r in CommandRole.values) r: []};
  final errors = {
    for (final i in result.issues)
      if (i.level == core.IssueLevel.error) ...i.tokenIndices,
  };
  var program = result.executable;
  var lastStream = CommandRole.video;
  final display = result.display;
  for (var index = 0; index < display.length; index++) {
    final t = display[index];
    final token = CommandToken(
      quoteArgument(t.text),
      extra: t.role == core.TokenRole.extra,
      error: errors.contains(index),
      field: t.field,
      replacedField: t.replacedField,
    );
    switch (t.role) {
      case core.TokenRole.exe:
        program = t.text;
      case core.TokenRole.global || core.TokenRole.input:
        inputs.add(token);
      case core.TokenRole.map:
        lines[CommandRole.inputs]!.add(token);
      case core.TokenRole.video:
        lines[CommandRole.video]!.add(token);
        lastStream = CommandRole.video;
      case core.TokenRole.audio:
        lines[CommandRole.audio]!.add(token);
        lastStream = CommandRole.audio;
      case core.TokenRole.extra || core.TokenRole.macro:
        lines[lastStream]!.add(token);
      case core.TokenRole.mux:
        lines[CommandRole.mux]!.add(token);
      case core.TokenRole.output:
        lines[CommandRole.output]!.add(token);
    }
  }
  return CommandDisplay(
    program: program,
    inputs: inputs,
    inputsLabel: audio ? 'VEGAS video + audio' : 'VEGAS video',
    lines: [
      for (final r in CommandRole.values)
        if (lines[r]!.isNotEmpty) CommandLine(r, lines[r]!),
    ],
    copyText: result.commandLine,
  );
}

/// An argument as Windows quotes it, for display.
String quoteArgument(String arg) =>
    arg.isEmpty || RegExp(r'[\s"]').hasMatch(arg) ? '"${arg.replaceAll('"', r'\"')}"' : arg;

// ------------------------------------------------------------ checks

VeLevel levelOf(core.IssueLevel level) => switch (level) {
  core.IssueLevel.error => VeLevel.error,
  core.IssueLevel.warn => VeLevel.warning,
  core.IssueLevel.info => VeLevel.info,
  core.IssueLevel.hint => VeLevel.hint,
};

/// Which diagram node holds the control for an issue's field.
SignalNode? nodeForField(String field) {
  if (field.startsWith('video')) return SignalNode.video;
  if (field.startsWith('audio')) return SignalNode.audio;
  if (field.startsWith('container')) return SignalNode.container;
  if (field.startsWith('output')) return SignalNode.file;
  return null;
}

// ------------------------------------------------------------ signal path

/// Builds the diagram from the core's signal-path facts (CONTRACTS C2,
/// `CompileResult.signalPath`): bits, formats, chroma, whether a conversion
/// happens and whether the container can hold each stream. Without a compile
/// result the recipe and catalog name the stages, and the wires claim no
/// conversion either way.
SignalPathModel signalPathModel({
  required core.Recipe recipe,
  required core.ProfileCatalog catalog,
  required core.MediaDescription media,
  core.CompileResult? compiled,
  core.FFmpegInstallation? installation,
  int? lengthSec,
  PreviewMedia preview = PreviewMedia.sample,
}) {
  if (recipe.command.mode == 'template') {
    return _commandSignalPath(
      recipe: recipe,
      catalog: catalog,
      media: media,
      compiled: compiled,
      installation: installation,
      lengthSec: lengthSec,
      preview: preview,
    );
  }
  final summary = compiled?.summary ?? const <String, Object?>{};
  final facts = compiled?.signalPath;
  final issues = compiled?.issues ?? const <core.Issue>[];
  final v = recipe.video;
  final a = recipe.audio.first;
  final vp = catalog.videoEncoder(v.encoder);
  final ap = catalog.audioEncoder(a.encoder);
  final cp = catalog.container(recipe.container.format);
  final vf = facts?.video;
  final af = facts?.audio.firstOrNull;
  final inDepth = vf?.inputBits ?? deliveredDepth(media.video.pixfmt) ?? 8;
  final audioIn = _deliveredAudio[media.audio?.sampleFmt];

  SignalStream? video;
  if (v.enabled) {
    final outDepth = vf?.outputBits ?? inDepth;
    video = SignalStream(
      encoder: summary['videoEncoder'] as String? ?? vp?.label ?? v.encoder,
      detail: compiled != null ? _videoDetail(summary) : _videoDetailFromRecipe(v, vp),
      codec: vp?.codec ?? summary['video'] as String? ?? v.encoder,
      inputBits: inDepth,
      outputBits: outDepth,
      availability: availabilityOf(installation, v.encoder),
      runsOn: runsOn(vp),
      conversion: vf?.conversion == true ? _videoConversion(vf!, inDepth, outDepth, issues) : null,
      formatLabel: vf == null ? '$outDepth-bit' : ['$outDepth-bit', ?vf.outputChroma].join(' '),
      inputLabel: '$inDepth-bit',
      outputLabel: '$outDepth-bit',
      muxProblem: vf?.containerSupport == 'no',
      conversionKnown: vf?.conversion != null,
    );
  }

  SignalStream? audio;
  if (a.enabled && media.audio != null) {
    final inBits = af?.inputBits ?? audioIn?.bits ?? 32;
    final outBits = af?.outputBits ?? inBits;
    final outLabel = '$outBits-bit ${_sampleKind[af?.outputFormat] ?? audioIn?.short ?? ''}'.trim();
    audio = SignalStream(
      encoder: summary['audio'] as String? ?? ap?.label ?? a.encoder,
      detail: compiled != null ? (summary['audioQuality'] as String? ?? '') : _audioDetailFromRecipe(a, ap),
      codec: ap?.codec ?? a.encoder,
      inputBits: inBits,
      outputBits: outBits,
      availability: availabilityOf(installation, a.encoder),
      conversion: af?.conversion == true
          ? SignalConversion(
              label: '${af!.inputFormat ?? 'VEGAS samples'} to ${af.outputFormat ?? 'encoder format'}',
              shortLabel: outBits != inBits ? '$inBits to $outBits-bit' : 'Layout change',
              note: [outLabel, if (outBits < inBits) 'precision lost'].join(', '),
            )
          : null,
      formatLabel: outLabel,
      muxProblem: af?.containerSupport == 'no',
      conversionKnown: af?.conversion != null,
    );
  }

  final ext = cp?.ext ?? '';
  return SignalPathModel(
    source: _signalSource(media, inDepth, preview),
    video: video,
    audio: audio,
    container: SignalContainer(
      label: containerShortName(cp, recipe.container.format),
      detail: recipe.container.faststart && recipe.container.format == 'mp4' ? 'Fast start' : ext,
      spokenLabel: cp?.label,
    ),
    fileName: 'Sample project$ext',
    contextLabel: _contextLabel(media, lengthSec, preview),
  );
}

/// What the preview is worked out with: the sample, or the project's facts.
String _contextLabel(core.MediaDescription media, int? lengthSec, PreviewMedia preview) {
  final length = lengthSec == null ? '' : ', ${lengthPhrase(lengthSec)}';
  return switch (preview) {
    PreviewMedia.sample => 'Preview with: ${mediaSummary(media)}$length',
    PreviewMedia.project => 'The project: ${mediaSummary(media)}$length',
    PreviewMedia.projectUnknown => 'Set by the project. Preview with the sample: ${mediaSummary(media)}$length',
  };
}

/// The "From VEGAS" node: what the project delivers. When VEGAS didn't share
/// the project's facts they are "Set by the project", and the lines name the
/// sample the preview uses (UI_SPEC §4).
SignalSource _signalSource(core.MediaDescription media, int depth, PreviewMedia preview) {
  final mediaAudio = media.audio;
  final audioIn = _deliveredAudio[mediaAudio?.sampleFmt];
  final fps = VeFormat.fps(media.video.fps[0], media.video.fps[1]);
  if (preview == PreviewMedia.projectUnknown) {
    const unset = 'Set by the project';
    return SignalSource(
      frameSize: unset,
      // What fits in the strip's node; the panel says it in full.
      stripTitle: 'Set by project',
      frameRate: unset,
      pixelFormat: unset,
      audio: unset,
      stripVideo: 'Sample: $fps',
      stripAudio: mediaAudio == null
          ? 'Sample: no audio'
          : 'Sample: ${kiloHertz(mediaAudio.rate)} ${audioIn?.short ?? mediaAudio.sampleFmt}',
      depth: depth,
      spokenSummary: '$unset. The preview uses a sample: ${mediaSummary(media)}',
    );
  }
  return SignalSource(
    frameSize: '${media.video.width}×${media.video.height}',
    frameRate: fps,
    pixelFormat: deliveredPixelFormat(media.video.pixfmt),
    audio: mediaAudio == null
        ? 'No audio'
        : '${kiloHertz(mediaAudio.rate)} ${audioIn?.short ?? mediaAudio.sampleFmt} ${channelsLabel(mediaAudio.channels)}',
    stripVideo: '$fps, ${_deliveredVideo[media.video.pixfmt]?.short ?? media.video.pixfmt}',
    stripAudio: mediaAudio == null
        ? 'No audio'
        : '${kiloHertz(mediaAudio.rate)} ${audioIn?.short ?? mediaAudio.sampleFmt}',
    depth: depth,
    spokenSummary: '${media.video.width} by ${media.video.height}, $fps',
  );
}

/// The pip on a video wire, from the core's facts.
SignalConversion _videoConversion(core.StreamSignalFacts vf, int inDepth, int outDepth, List<core.Issue> issues) {
  final chroma = vf.chromaChanged == true
      ? '${vf.inputChroma} to ${vf.outputChroma}${issues.any((i) => i.id == 'V-CHROMA-UP') ? ', interpolated' : ''}'
      : vf.outputChroma;
  final notes = [?chroma, if (outDepth < inDepth) 'precision lost'];
  return SignalConversion(
    label: '${vf.inputFormat ?? 'VEGAS frames'} to ${vf.outputFormat ?? 'encoder format'}',
    shortLabel: outDepth != inDepth
        ? '$inDepth to $outDepth-bit'
        : vf.chromaChanged == true
        ? '${vf.inputChroma} to ${vf.outputChroma}'
        : 'Layout change',
    note: notes.isEmpty ? null : notes.join(', '),
  );
}

/// Advanced mode (UI_SPEC §2, §3): the nodes are read back from the command,
/// so only the core's facts for the active command fill them (CONTRACTS C2:
/// in Advanced mode it supplies what it can establish and leaves the rest
/// null). The inactive Basic settings never appear. An unknown format claims
/// no conversion either way and no wire label; the wire keeps VEGAS's depth.
/// Availability is shown only for the core's established encoder IDs; neither
/// display labels nor inactive Basic settings supply one.
SignalPathModel _commandSignalPath({
  required core.Recipe recipe,
  required core.ProfileCatalog catalog,
  required core.MediaDescription media,
  core.CompileResult? compiled,
  core.FFmpegInstallation? installation,
  int? lengthSec,
  PreviewMedia preview = PreviewMedia.sample,
}) {
  String? s(String key) {
    final v = compiled?.summary[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  const fromCommand = 'From command';
  final videoEncoderId = s('videoEncoderId');
  final audioEncoderId = s('audioEncoderId');
  final facts = compiled?.signalPath;
  final issues = compiled?.issues ?? const <core.Issue>[];
  final sourceDepth = facts?.source?.video.bits ?? deliveredDepth(media.video.pixfmt) ?? 8;
  final audioIn = _deliveredAudio[media.audio?.sampleFmt];
  // Without a compile result nothing is known but that VEGAS delivers.
  final vf = facts?.video;
  final af = facts?.audio.firstOrNull;
  final hasVideo = facts == null || facts.video != null;
  final hasAudio = facts == null ? recipe.audio.first.enabled && media.audio != null : facts.audio.isNotEmpty;

  SignalStream? video;
  if (hasVideo) {
    final inDepth = vf?.inputBits ?? sourceDepth;
    final outBits = vf?.outputBits;
    final outDepth = outBits ?? inDepth;
    video = SignalStream(
      encoder: s('videoEncoder') ?? s('video') ?? fromCommand,
      detail: _videoDetail(compiled?.summary ?? const {}),
      codec: s('video') ?? fromCommand,
      inputBits: inDepth,
      outputBits: outDepth,
      availability: videoEncoderId == null ? null : availabilityOf(installation, videoEncoderId),
      conversion: vf != null && vf.conversion == true ? _videoConversion(vf, inDepth, outDepth, issues) : null,
      formatLabel: outBits == null ? null : ['$outBits-bit', ?vf?.outputChroma].join(' '),
      inputLabel: vf?.inputBits == null ? null : '$inDepth-bit',
      outputLabel: outBits == null ? null : '$outBits-bit',
      muxProblem: vf?.containerSupport == 'no',
      conversionKnown: vf?.conversion != null,
    );
  }

  SignalStream? audio;
  if (hasAudio) {
    final inBits = af?.inputBits ?? audioIn?.bits ?? 32;
    final outBits = af?.outputBits;
    final outLabel = outBits == null ? null : '$outBits-bit ${_sampleKind[af?.outputFormat] ?? ''}'.trim();
    audio = SignalStream(
      encoder: s('audio') ?? fromCommand,
      detail: s('audioQuality') ?? '',
      codec: s('audio') ?? fromCommand,
      inputBits: inBits,
      outputBits: outBits ?? inBits,
      availability: audioEncoderId == null ? null : availabilityOf(installation, audioEncoderId),
      conversion: af != null && af.conversion == true
          ? SignalConversion(
              label: '${af.inputFormat ?? 'VEGAS samples'} to ${af.outputFormat ?? 'encoder format'}',
              shortLabel: outBits != null && outBits != inBits ? '$inBits to $outBits-bit' : 'Layout change',
              note: [?outLabel, if (outBits != null && outBits < inBits) 'precision lost'].join(', '),
            )
          : null,
      formatLabel: outLabel,
      muxProblem: af?.containerSupport == 'no',
      conversionKnown: af?.conversion != null,
    );
  }

  // Only an active-command core fact can supply the preview's suffix.
  final ext = compiled?.outputExtension ?? '';
  final muxer = s('container');
  final cp = muxer == null ? null : catalog.containers.where((c) => c.label == muxer).firstOrNull;
  return SignalPathModel(
    source: _signalSource(media, sourceDepth, preview),
    video: video,
    audio: audio,
    container: muxer == null
        ? SignalContainer(
            label: 'From file name',
            detail: ext,
            spokenLabel: 'Chosen by FFmpeg from the file name${ext.isEmpty ? '' : ', $ext'}',
          )
        : SignalContainer(
            label: cp == null ? muxer : containerShortName(cp, cp.id),
            detail: fromCommand,
            spokenLabel: muxer,
          ),
    fileName: 'Sample project$ext',
    contextLabel: _contextLabel(media, lengthSec, preview),
    fromCommand: true,
  );
}

String _videoDetail(Map<String, Object?> summary) =>
    [summary['videoQuality'], summary['speed']].whereType<String>().where((s) => s.isNotEmpty).join(', ');

/// The node's detail line from the recipe, when the core couldn't compile it.
String _videoDetailFromRecipe(core.VideoSettings v, core.EncoderProfile? p) {
  final parts = <String>[];
  final mode = v.mode;
  final q = p?.quality;
  if ((mode == 'crf' || mode == 'cq') && q != null) {
    final value = v.quality ?? q.def;
    if (value != null) parts.add('${qualityUnit(q.flag)} ${_num(value)}');
  } else if ((mode == 'abr' || mode == 'cbr') && v.bitrateK != null) {
    parts.add(VeFormat.rate(v.bitrateK!));
  } else if (mode == 'cqp' && v.qp != null) {
    parts.add('QP ${_num(v.qp!)}');
  } else if (mode == 'profile' && p?.profileQuality != null && v.profile != null) {
    parts.add(choiceName(p!.profileQuality!, v.profile!));
  } else if (mode == 'lossless') {
    parts.add('Lossless');
  }
  final speed = v.speed ?? p?.speed?.def;
  if (speed != null && p?.speed != null) parts.add(choiceName(p!.speed!, speed));
  return parts.join(', ');
}

String _audioDetailFromRecipe(core.AudioSettings a, core.EncoderProfile? p) {
  if (a.bitrateK != null && (a.mode == null || a.mode == 'bitrate')) return VeFormat.rate(a.bitrateK!);
  if (p != null && p.modes.contains('lossless')) return 'Lossless';
  return '';
}

String _num(num v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
