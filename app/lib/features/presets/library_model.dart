import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/status.dart';
import '../../state/editor.dart';
import '../../state/presets.dart';
import '../../state/services.dart';
import 'display.dart';

/// One row in the library (UI_SPEC §2, Library). Its name, ID and search
/// text are worked out once (`Preset.recipe` copies the recipe each time).
@immutable
class LibraryEntry {
  LibraryEntry({
    required this.preset,
    required this.line,
    required this.favorite,
    required this.dirty,
    this.advanced = false,
    this.depth,
    this.problem,
    this.problemDetail,
    this.errors = const [],
  });

  final Preset preset;

  /// "x264 CRF 18, AAC", or the problem: "Needs x264: not in this FFmpeg".
  final String line;
  final bool favorite;

  /// Has unsaved changes.
  final bool dirty;

  /// The command renders (Advanced mode), as the draft or saved recipe has it.
  final bool advanced;

  /// Output bit depth for the wire glyph; null if the core couldn't say.
  final int? depth;
  final String? problem;

  /// The availability reason, for the tooltip.
  final String? problemDetail;

  /// The core's error messages for the chosen FFmpeg; the row shows an error
  /// mark (UI_SPEC §2, Errors). Empty when the core couldn't check it.
  final List<String> errors;

  late final Recipe _recipe = preset.recipe;
  late final String id = _recipe.id;
  late final String name = _recipe.name;
  bool get builtin => preset.builtin;
  late final String category = _recipe.category;

  /// Search text: name, tags, encoders and codecs, summary.
  late final String haystack = [
    _recipe.name,
    ..._recipe.tags,
    _recipe.video.encoder,
    ..._recipe.audio.map((a) => a.encoder),
    ...preset.requires.encoders,
    line,
    if (advanced) 'advanced command',
    categoryLabel(_recipe.category),
  ].join(' ').toLowerCase();
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
  // Only what changes a row: drafts. Search, filters and selection reuse the
  // rows.
  final drafts = ref.watch(presetsControllerProvider.select((s) => s.drafts));
  final core = ref.watch(veCoreProvider);
  final catalog = ref.watch(profilesProvider);
  final settings = ref.watch(machineSettingsProvider).value;
  final installationId = ref.watch(selectedInstallationIdProvider);
  final installation = settings?.installations.where((i) => i.id == installationId).firstOrNull;
  final probed = installationId == null ? null : ref.watch(capabilitiesProvider(installationId)).value;
  // Settings writes (the remembered length, window bounds) hand out new
  // installation objects with the same content; rows only need to know when
  // the content changes.
  final installationKey = installation == null ? '' : jsonEncode(installation.data);
  final rows = ref.watch(_libraryRowCacheProvider);
  return [
    for (final p in presets)
      rows.entry(p, drafts[presetId(p)]?.recipe, probed, installationKey, () {
        final recipe = drafts[presetId(p)]?.recipe ?? presetRecipe(p);
        return libraryEntry(
          p,
          recipe: recipe,
          favorite: p.favorite,
          dirty: drafts.containsKey(presetId(p)),
          compiled: compileSample(
            core,
            recipe,
            ext: catalog.container(recipe.container.format)?.ext,
            capabilities: capabilitiesFor(probed, recipe, label: installation?.label ?? ''),
          ).value,
          catalog: catalog,
          installation: installation,
        );
      }),
  ];
});

/// Library rows from the last build, so an edit recompiles only the edited
/// preset's row (TECH_ARCHITECTURE §9.3: ≤ 4 ms per edit, 500 presets). A row
/// is reused while its preset object, draft, capabilities and installation
/// are unchanged; the library hands out new preset objects when a preset
/// changes, and drafts are new objects after each edit.
final _libraryRowCacheProvider = Provider<_LibraryRowCache>((ref) {
  // A new core or catalog starts again.
  ref.watch(veCoreProvider);
  ref.watch(profilesProvider);
  return _LibraryRowCache();
});

class _LibraryRowCache {
  final _rows = Expando<({Recipe? draft, Object? probed, String installation, LibraryEntry entry})>();

  LibraryEntry entry(Preset preset, Recipe? draft, Object? probed, String installation, LibraryEntry Function() build) {
    final row = _rows[preset];
    if (row != null &&
        identical(row.draft, draft) &&
        identical(row.probed, probed) &&
        row.installation == installation) {
      return row.entry;
    }
    final entry = build();
    _rows[preset] = (draft: draft, probed: probed, installation: installation, entry: entry);
    return entry;
  }
}

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
    // The row's Advanced tag says where it comes from; the line names the
    // encoder the core read from the command.
    line = enc == null || enc.isEmpty ? 'Your command' : '$enc, your command';
  } else if (compiled != null) {
    final video = [summary['videoEncoder'], summary['videoQuality']].whereType<String>().join(' ');
    line = '$video, ${audio.enabled ? summary['audio'] ?? audio.encoder : 'no audio'}';
  } else {
    final vp = catalog.videoEncoder(recipe.video.encoder);
    final ap = catalog.audioEncoder(audio.encoder);
    line = '${vp?.label ?? recipe.video.encoder}, ${audio.enabled ? ap?.label ?? audio.encoder : 'no audio'}';
  }

  final needs = encodersNeeded(preset, recipe);
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
    advanced: advanced,
    // Advanced commands have no resolved Basic settings; the core's signal
    // facts give the output depth when the command sets one.
    depth: compiled?.resolved?.depth ?? compiled?.signalPath?.video?.outputBits,
    problem: problem,
    problemDetail: detail,
    errors: [
      for (final i in compiled?.issues ?? const <Issue>[])
        if (i.level == IssueLevel.error) i.message,
    ],
  );
}

/// Encoders [preset] needs to render, as [recipe] (its draft or saved
/// settings) has them: the recipe's own in Basic mode, or what the library
/// derived from an Advanced command (C3 `requires`).
List<String> encodersNeeded(Preset preset, Recipe recipe) {
  if (recipe.command.mode == 'template') return preset.requires.encoders;
  final audio = recipe.audio.first;
  return [if (recipe.video.enabled) recipe.video.encoder, if (audio.enabled) audio.encoder];
}

String _statePhrase(VeAvailability s) => switch (s) {
  VeAvailability.missing => 'not in this FFmpeg',
  VeAvailability.failed => 'failed its test on this PC',
  VeAvailability.testing => 'being tested',
  VeAvailability.unknown => 'not checked on this PC yet',
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
