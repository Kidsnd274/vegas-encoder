import 'dart:convert';

import 'package:ve_core/ve_core.dart';

/// Recipe JSON in a canonical form: keys sorted, whole doubles written as
/// integers, null entries left out (a null control and an absent one both
/// mean "encoder default"). Used only to tell whether a draft differs from
/// what is saved; the core's `diff` names the differences.
String canonicalJson(Object? value) {
  Object? canon(Object? v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().where((k) => v[k] != null).toList()..sort();
      return {for (final k in keys) k: canon(v[k])};
    }
    if (v is List) return v.map(canon).toList();
    if (v is double && v.isFinite && v == v.truncateToDouble()) return v.toInt();
    return v;
  }

  return jsonEncode(canon(value));
}

bool sameRecipe(Recipe a, Recipe b) => canonicalJson(a.toJson()) == canonicalJson(b.toJson());

/// A number as recipe JSON stores it: 18, not 18.0, so a value typed back to
/// what it was makes the recipe identical to the saved one again.
num jsonNumber(num value) => value is double && value == value.truncateToDouble() ? value.toInt() : value;

/// Edits the Basic editor makes. They set recipe fields only; resolving what a
/// null (encoder default) means, and checking combinations, is the core's job.
extension RecipeEdits on Recipe {
  AudioSettings get audioTrack => audio.first;

  Recipe withVideo(VideoSettings Function(VideoSettings v) change) => copyWith(video: change(video));

  Recipe withAudio(AudioSettings Function(AudioSettings a) change) =>
      copyWith(audio: [change(audioTrack), ...audio.skip(1)]);

  Recipe withContainer(ContainerSettings Function(ContainerSettings c) change) =>
      copyWith(container: change(container));

  /// A new video encoder starts from its own defaults (null means "encoder
  /// default"). The rate mode stays when the new encoder has it; bitrate,
  /// keyframes, color tags and Extra arguments are kept.
  Recipe withVideoEncoder(String id, EncoderProfile? profile) => withVideo(
    (v) => v.copyWith(
      encoder: id,
      mode: profile != null && profile.modes.contains(v.mode) ? v.mode : null,
      quality: null,
      qp: null,
      speed: null,
      tune: null,
      profile: null,
      multipass: null,
      depth: profile != null && profile.depths.containsKey('${v.depth}') ? v.depth : null,
    ),
  );

  /// A new audio encoder starts from its own defaults; a bitrate or sample
  /// rate the new encoder offers is kept.
  Recipe withAudioEncoder(String id, EncoderProfile? profile) => withAudio((a) {
    final rates = profile?.rates ?? const <int>[];
    final bitrates = (profile?.bitrate['values'] as List?)?.cast<int>() ?? const <int>[];
    return a.copyWith(
      encoder: id,
      mode: profile != null && profile.modes.contains(a.mode) ? a.mode : null,
      bitrateK: bitrates.contains(a.bitrateK) ? a.bitrateK : null,
      vbr: null,
      level: null,
      sampleRate: a.sampleRate == 'source' || rates.contains(a.sampleRate) ? a.sampleRate : 'source',
    );
  });
}

/// A recipe field path as the core reports it ("video.quality",
/// "audio[0].bitrateK"), split into map keys and list indexes.
List<Object> _segments(String path) => [
  for (final part in path.split('.'))
    for (final m in RegExp(r'([^\[\]]+)|\[(\d+)\]').allMatches(part)) m[1] ?? int.parse(m[2]!),
];

/// The value at [path], and whether the key is there at all.
({bool present, Object? value}) readPath(JsonMap json, String path) {
  Object? node = json;
  for (final s in _segments(path)) {
    if (s is String && node is Map && node.containsKey(s)) {
      node = node[s];
    } else if (s is int && node is List && s < node.length) {
      node = node[s];
    } else {
      return (present: false, value: null);
    }
  }
  return (present: true, value: node);
}

/// Whether [path] differs between two recipes. Absent and null are the same.
bool fieldDiffers(Recipe a, Recipe b, String path) =>
    canonicalJson(readPath(a.toJson(), path).value) != canonicalJson(readPath(b.toJson(), path).value);

/// [recipe] with [path] put back as it is in [saved], including leaving the
/// key out when [saved] doesn't have it.
Recipe resetField(Recipe recipe, Recipe saved, String path) {
  final from = readPath(saved.toJson(), path);
  final json = recipe.toJson();
  final segments = _segments(path);
  Object? parent = json;
  for (final s in segments.take(segments.length - 1)) {
    parent = s is String ? (parent as Map)[s] : (parent as List)[s as int];
    if (parent == null) return recipe;
  }
  final last = segments.last;
  if (parent is Map) {
    if (from.present) {
      parent[last] = from.value;
    } else {
      parent.remove(last);
    }
  } else if (parent is List && last is int && last < parent.length) {
    parent[last] = from.value;
  }
  return Recipe.fromJson(json);
}
