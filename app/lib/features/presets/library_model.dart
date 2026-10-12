import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/status.dart';
import '../../state/editor.dart';
import '../../state/presets.dart';
import '../../state/preview.dart';
import '../../state/services.dart';
import 'display.dart';

/// One row in the library (UI_SPEC §2, Library).
@immutable
class LibraryEntry {
  const LibraryEntry({
    required this.preset,
    required this.line,
    required this.favorite,
    required this.dirty,
    this.depth,
    this.problem,
    this.problemDetail,
  });

  final Preset preset;

  /// "x264 CRF 18, AAC", or the problem: "Needs x264: not in this FFmpeg".
  final String line;
  final bool favorite;

  /// Has unsaved changes.
  final bool dirty;

  /// Output bit depth for the wire glyph; null if the core couldn't say.
  final int? depth;
  final String? problem;

  /// The availability reason, for the tooltip.
  final String? problemDetail;

  String get id => preset.recipe.id;
  String get name => preset.recipe.name;
  bool get builtin => preset.builtin;
  bool get advanced => preset.recipe.command.mode == 'template';
  String get category => preset.recipe.category;

  /// Search text: name, tags, encoders and codecs, summary.
  String get haystack {
    final r = preset.recipe;
    return [
      r.name,
      ...r.tags,
      r.video.encoder,
      ...r.audio.map((a) => a.encoder),
      ...preset.requires.encoders,
      line,
      categoryLabel(r.category),
    ].join(' ').toLowerCase();
  }
}

/// A header and its rows: "Favorites", "Web upload", …
typedef LibrarySubgroup = ({String title, List<LibraryEntry> entries});

@immutable
class LibraryGroup {
  const LibraryGroup(this.title, this.count, this.subgroups);
  final String title;
  final int count;
  final List<LibrarySubgroup> subgroups;
}

/// Every preset as a library row, using drafts where there are any.
final libraryEntriesProvider = Provider<List<LibraryEntry>>((ref) {
  final presets = ref.watch(presetsProvider).value ?? const <Preset>[];
  final state = ref.watch(presetsControllerProvider);
  final core = ref.watch(veCoreProvider);
  final catalog = ref.watch(profilesProvider);
  final settings = ref.watch(machineSettingsProvider).value;
  final installationId = ref.watch(selectedInstallationIdProvider);
  final installation = settings?.installations.where((i) => i.id == installationId).firstOrNull;
  return [
    for (final p in presets)
      libraryEntry(
        p,
        recipe: state.drafts[p.recipe.id]?.recipe ?? p.recipe,
        favorite: state.isFavorite(p),
        dirty: state.drafts.containsKey(p.recipe.id),
        compiled: CoreResult.run(() {
          final recipe = state.drafts[p.recipe.id]?.recipe ?? p.recipe;
          final ext = catalog.container(recipe.container.format)?.ext;
          return core.compile(recipe, media: SamplePreview.media, paths: SamplePreview.paths(ext));
        }).value,
        catalog: catalog,
        installation: installation,
      ),
  ];
});

LibraryEntry libraryEntry(
  Preset preset, {
  required Recipe recipe,
  required bool favorite,
  required bool dirty,
  required CompileResult? compiled,
  required ProfileCatalog catalog,
  FFmpegInstallation? installation,
}) {
  final summary = compiled?.summary ?? const <String, Object?>{};
  final advanced = recipe.command.mode == 'template';
  final audio = recipe.audio.first;
  final String line;
  if (advanced) {
    final enc = summary['videoEncoder'] as String?;
    line = enc == null ? 'Advanced command' : 'Advanced command, $enc';
  } else if (compiled != null) {
    final video = [summary['videoEncoder'], summary['videoQuality']].whereType<String>().join(' ');
    line = '$video, ${audio.enabled ? summary['audio'] ?? audio.encoder : 'no audio'}';
  } else {
    final vp = catalog.videoEncoder(recipe.video.encoder);
    final ap = catalog.audioEncoder(audio.encoder);
    line = '${vp?.label ?? recipe.video.encoder}, ${audio.enabled ? ap?.label ?? audio.encoder : 'no audio'}';
  }

  // Encoders this preset needs: the recipe's own, or what the library
  // derived from an Advanced command.
  final needs = advanced
      ? preset.requires.encoders
      : [if (recipe.video.enabled) recipe.video.encoder, if (audio.enabled) audio.encoder];
  String? problem;
  String? detail;
  for (final id in needs) {
    final state = availabilityOf(installation, id);
    if (state == VeAvailability.ready) continue;
    final label = catalog.videoEncoder(id)?.label ?? catalog.audioEncoder(id)?.label ?? id;
    problem = 'Needs $label: ${_statePhrase(state)}';
    detail = availabilityReason(installation, id);
    break;
  }

  return LibraryEntry(
    preset: preset,
    line: problem ?? line,
    favorite: favorite,
    dirty: dirty,
    depth: compiled?.resolved?.depth,
    problem: problem,
    problemDetail: detail,
  );
}

String _statePhrase(VeAvailability s) => switch (s) {
  VeAvailability.missing => 'not in this FFmpeg',
  VeAvailability.failed => 'failed its test on this PC',
  VeAvailability.testing => 'being tested',
  VeAvailability.ready => 'ready',
};

/// Built-in, then Mine. Favorites float to the top of their group, then
/// categories in vocabulary order, then names.
List<LibraryGroup> groupLibrary(
  List<LibraryEntry> entries, {
  String query = '',
  LibraryFilter filter = LibraryFilter.all,
  bool favoritesOnly = false,
}) {
  final q = query.trim().toLowerCase();
  bool matches(LibraryEntry e) =>
      (q.isEmpty || q.split(RegExp(r'\s+')).every(e.haystack.contains)) &&
      (filter == LibraryFilter.all || (filter == LibraryFilter.builtin) == e.builtin) &&
      (!favoritesOnly || e.favorite);
  final order = presetCategories.keys.toList();
  int rank(String c) => order.contains(c) ? order.indexOf(c) : order.length;

  LibraryGroup? group(String title, bool builtin) {
    final list = entries.where((e) => e.builtin == builtin && matches(e)).toList()
      ..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        final c = rank(a.category).compareTo(rank(b.category));
        return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    if (list.isEmpty) return null;
    final subgroups = <LibrarySubgroup>[];
    for (final e in list) {
      final title = e.favorite ? 'Favorites' : categoryLabel(e.category);
      if (subgroups.isEmpty || subgroups.last.title != title) subgroups.add((title: title, entries: []));
      subgroups.last.entries.add(e);
    }
    return LibraryGroup(title, list.length, subgroups);
  }

  return [?group('Built-in', true), ?group('Mine', false)];
}
