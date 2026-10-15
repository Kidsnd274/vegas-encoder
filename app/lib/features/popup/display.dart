// What the popup shows for a template's origin and its differences
// (UI_SPEC §4). Display work only: the differences are the core's (C2
// `diff`), the library's revisions are C3's; this file names them.

import 'package:ve_services/ve_services.dart' as core;

import '../../design/components/signal_path/signal_path_model.dart';
import '../../state/popup.dart';
import '../presets/display.dart';

/// The rows of UI_SPEC §4's origin table.
enum OriginState { unchanged, localChanges, libraryNewer, deleted, noOrigin, unreadable }

/// The header's origin line and the actions it offers.
class OriginLine {
  const OriginLine({
    required this.state,
    required this.lead,
    this.name,
    this.trail = '',
    this.changes,
    this.libraryRevision,
  });

  final OriginState state;

  /// Before the preset's name, which is bold: "From preset ".
  final String lead;
  final String? name;

  /// After the name: ", revision 5."
  final String trail;

  /// The template's own changes, when known.
  final int? changes;

  /// The library's newer revision, when it has one.
  final int? libraryRevision;

  /// "Show changes" is offered.
  bool get showChanges => (changes ?? 0) > 0;

  /// "Update from library" is offered.
  bool get updateFromLibrary => libraryRevision != null;

  /// "2 changes in this template", when there are any.
  String? get changesSentence {
    final n = changes ?? 0;
    return n <= 0 ? null : '$n ${n == 1 ? 'change' : 'changes'} in this template';
  }

  /// The whole line as plain text.
  String get text => ['$lead${name ?? ''}$trail', if (changesSentence case final changes?) '$changes.'].join(' ');
}

/// UI_SPEC §4's origin line for [s], with [local] the core's count of the
/// template's own changes (null without a copy of the origin revision).
OriginLine originLine(PopupState s, {int? local}) {
  final origin = s.origin;
  if (origin == null) return const OriginLine(state: OriginState.noOrigin, lead: 'Made in VEGAS', trail: '.');
  switch (s.library) {
    case OriginMissing():
      return OriginLine(
        state: OriginState.deleted,
        lead: 'Preset ',
        name: origin.name,
        trail: ' no longer exists in your library. This template still has all its settings.',
      );
    case OriginUnreadable(:final message):
      return OriginLine(
        state: OriginState.unreadable,
        lead: 'From ',
        name: origin.name,
        trail: ', revision ${origin.revision}. The library couldn’t be read: ${_sentence(message)}',
      );
    case OriginFound() || NoOrigin():
      break;
  }
  final changed = local != null && local > 0;
  final newer = s.libraryNewer ? s.libraryPreset!.revision : null;
  return OriginLine(
    state: newer != null
        ? OriginState.libraryNewer
        : changed
        ? OriginState.localChanges
        : OriginState.unchanged,
    lead: changed ? 'From ' : 'From preset ',
    name: origin.name,
    trail: ', revision ${origin.revision}.',
    changes: local,
    libraryRevision: newer,
  );
}

String _sentence(String text) {
  final t = text.trim();
  return t.isEmpty || '.!?'.contains(t[t.length - 1]) ? t : '$t.';
}

/// "revision 5 → 7" for Update "the origin": from the template's revision to the
/// one the save makes (the library's current one plus one).
String updateRevisions(PopupState s) {
  final latest = s.libraryPreset;
  final from = s.origin?.revision;
  if (latest == null || from == null) return '';
  return 'revision $from → ${latest.revision + 1}';
}

// ------------------------------------------------------------ differences

const _labels = <String, String>{
  'video.enabled': 'Video',
  'video.encoder': 'Video encoder',
  'video.mode': 'Rate control',
  'video.quality': 'Quality',
  'video.bitrateK': 'Bitrate',
  'video.maxrateK': 'Peak bitrate',
  'video.qp': 'QP',
  'video.speed': 'Encoder speed',
  'video.tune': 'Tune',
  'video.profile': 'Profile',
  'video.multipass': 'Multipass',
  'video.depth': 'Bit depth',
  'video.gopSec': 'Keyframes every',
  'video.color': 'Color tags',
  'video.extra': 'Video extra arguments',
  'audio[0].enabled': 'Audio',
  'audio[0].encoder': 'Audio encoder',
  'audio[0].mode': 'Audio rate control',
  'audio[0].bitrateK': 'Audio bitrate',
  'audio[0].vbr': 'Audio quality',
  'audio[0].level': 'Audio level',
  'audio[0].sampleRate': 'Sample rate',
  'audio[0].channels': 'Channels',
  'audio[0].extra': 'Audio extra arguments',
  'container.format': 'Container',
  'container.faststart': 'Fast start',
  'command.mode': 'Mode',
  'command.template': 'Command',
  'vegas.frame': 'Frame from VEGAS',
  'vegas.inputFormat': 'Format from VEGAS',
};

/// The setting a recipe path names, as the controls call it.
String fieldLabel(String path) => _labels[path] ?? path;

/// [value] at [path] as the controls show it ("CRF 17", "320 kb/s", "x264"),
/// from the profile catalog; the raw value when there is no better name.
String fieldValue(String path, Object? value, core.ProfileCatalog catalog, core.Recipe recipe) {
  if (value == null) return path.endsWith('.extra') || path == 'command.template' ? 'None' : 'Encoder default';
  if (value is bool) return value ? 'On' : 'Off';
  final video = catalog.videoEncoder(recipe.video.encoder);
  final audio = catalog.audioEncoder(recipe.audio.first.encoder);
  switch (path) {
    case 'video.encoder':
      return catalog.videoEncoder('$value')?.label ?? '$value';
    case 'audio[0].encoder':
      return catalog.audioEncoder('$value')?.label ?? '$value';
    case 'container.format':
      return containerShortName(catalog.container('$value'), '$value');
    case 'video.mode' || 'audio[0].mode':
      final mode = core.jsonMap(catalog.rateModes[value] ?? <String, Object?>{});
      return mode['label'] as String? ?? '$value';
    case 'video.quality' when value is num && video?.quality != null:
      return '${qualityUnit(video!.quality!.flag)} ${_number(value)}';
    case 'video.qp' when value is num:
      return 'QP ${_number(value)}';
    case 'video.bitrateK' || 'video.maxrateK' when value is num:
      return '${_number(value / 1000)} Mb/s';
    case 'audio[0].bitrateK' when value is num:
      return '${_number(value)} kb/s';
    case 'video.speed' when video?.speed != null:
      return choiceName(video!.speed!, '$value');
    case 'video.tune' when video?.tune != null:
      return choiceName(video!.tune!, '$value');
    case 'video.profile' when video?.profile != null:
      return choiceName(video!.profile!, '$value');
    case 'video.depth' when value is num:
      return '${_number(value)}-bit';
    case 'video.gopSec' when value is num:
      return '${_number(value)} s';
    case 'audio[0].sampleRate':
      return value == 'source' ? 'As the project' : (value is num ? kiloHertz(value.toInt()) : '$value');
    case 'audio[0].channels':
      return value == 'source' ? 'As the project' : (value is num ? channelsLabel(value.toInt()) : '$value');
    case 'command.mode':
      return value == 'template' ? 'Advanced' : 'Basic';
    case 'audio[0].vbr' || 'audio[0].level' when value is num && audio != null:
      return _number(value);
  }
  if (value is String) return value.isEmpty ? 'None' : value;
  if (value is num) return _number(value);
  return '$value';
}

String _number(num n) =>
    n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

/// Diagram marks (S3): a dot on each node this template changed from its
/// origin revision, and the library's revision on each node the library
/// changed since, both from the core's diff.
Map<SignalNode, SignalMarks> originMarks({List<core.FieldDiff>? local, List<core.FieldDiff>? since, int? revision}) {
  final changed = {for (final d in local ?? const <core.FieldDiff>[]) ?nodeForField(d.path)};
  final library = {
    if (revision != null)
      for (final d in since ?? const <core.FieldDiff>[]) ?nodeForField(d.path),
  };
  return {
    for (final node in {...changed, ...library})
      node: SignalMarks(changed: changed.contains(node), libraryRevision: library.contains(node) ? revision : null),
  };
}
