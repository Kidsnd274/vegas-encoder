import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../design/components/signal_path/signal_path_model.dart';
import 'recipe_edit.dart';
import 'services.dart';
import 'ui_state.dart';

enum LibraryFilter { all, builtin, mine }

/// Unsaved changes to one preset. [baseRevision] is the revision the edit
/// started from; a save expects the library to still be at it.
@immutable
class PresetDraft {
  const PresetDraft(this.recipe, this.baseRevision, {this.keepEditing = false});
  final Recipe recipe;
  final int baseRevision;

  /// The preset changed in another window and the user chose to keep editing.
  final bool keepEditing;

  PresetDraft copyWith({Recipe? recipe, int? baseRevision, bool? keepEditing}) => PresetDraft(
    recipe ?? this.recipe,
    baseRevision ?? this.baseRevision,
    keepEditing: keepEditing ?? this.keepEditing,
  );
}

/// The Presets screen's own state. Library contents come from [presetsProvider].
@immutable
class PresetsState {
  const PresetsState({
    this.selectedId,
    this.drafts = const {},
    this.node = SignalNode.video,
    this.query = '',
    this.filter = LibraryFilter.all,
    this.favoritesOnly = false,
    this.installationId,
    this.lengthText,
    this.builtinFavorites = const {},
    this.commandMultiline = true,
  });

  final String? selectedId;
  final Map<String, PresetDraft> drafts;
  final SignalNode node;
  final String query;
  final LibraryFilter filter;
  final bool favoritesOnly;

  /// The FFmpeg the checks are for; null is the default installation.
  final String? installationId;

  /// The length text typed in the size card this session; null until typed
  /// (then the remembered text, or 10:00, applies: see ui_state.dart).
  final String? lengthText;

  /// Favorites on built-in presets for this session. The library can't save
  /// them (built-ins are read-only in C3); see workstreams/app.md, Needs.
  final Map<String, bool> builtinFavorites;

  /// The command's layout: grouped lines, or one line (UI_SPEC §2).
  final bool commandMultiline;

  PresetsState copyWith({
    Object? selectedId = _keep,
    Map<String, PresetDraft>? drafts,
    SignalNode? node,
    String? query,
    LibraryFilter? filter,
    bool? favoritesOnly,
    Object? installationId = _keep,
    Object? lengthText = _keep,
    Map<String, bool>? builtinFavorites,
    bool? commandMultiline,
  }) => PresetsState(
    selectedId: identical(selectedId, _keep) ? this.selectedId : selectedId as String?,
    drafts: drafts ?? this.drafts,
    node: node ?? this.node,
    query: query ?? this.query,
    filter: filter ?? this.filter,
    favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    installationId: identical(installationId, _keep) ? this.installationId : installationId as String?,
    lengthText: identical(lengthText, _keep) ? this.lengthText : lengthText as String?,
    builtinFavorites: builtinFavorites ?? this.builtinFavorites,
    commandMultiline: commandMultiline ?? this.commandMultiline,
  );

  bool isFavorite(Preset p) => p.builtin ? (builtinFavorites[p.recipe.id] ?? p.favorite) : p.favorite;
}

const Object _keep = Object();

/// What a save did, for the confirmation toast and selection.
enum SaveOutcome { saved, savedAsNew, conflict, nothingToSave }

final presetsControllerProvider = NotifierProvider<PresetsController, PresetsState>(PresetsController.new);

class PresetsController extends Notifier<PresetsState> {
  @override
  PresetsState build() => const PresetsState();

  PresetLibrary get _library => ref.read(presetLibraryProvider);
  List<Preset> get _presets => ref.read(presetsProvider).value ?? const [];
  Preset? _find(String id) => _presets.where((p) => p.recipe.id == id).firstOrNull;

  void select(String id) => state = state.copyWith(selectedId: id);
  void selectNode(SignalNode node) => state = state.copyWith(node: node);
  void setQuery(String query) => state = state.copyWith(query: query);
  void setFilter(LibraryFilter filter) => state = state.copyWith(filter: filter);
  void toggleFavoritesOnly() => state = state.copyWith(favoritesOnly: !state.favoritesOnly);

  /// Clears the search, the Built-in/Mine filter and Favorites only.
  void showAll() => state = state.copyWith(query: '', filter: LibraryFilter.all, favoritesOnly: false);
  void selectInstallation(String id) => state = state.copyWith(installationId: id);

  /// The size card's length as typed; remembered in C7 `uiState`.
  void setLengthText(String text) {
    state = state.copyWith(lengthText: text);
    ref.read(uiStateWriterProvider).later((ui) => ui.copyWith(lastSizeLengthText: text));
  }

  void toggleCommandLayout() => state = state.copyWith(commandMultiline: !state.commandMultiline);

  /// The recipe the editor shows for [id]: the draft, else the saved one.
  Recipe? working(String id) => state.drafts[id]?.recipe ?? _find(id)?.recipe;

  /// Applies an edit to the selected preset. Editing back to the saved recipe
  /// drops the draft, so the preset is clean again.
  void edit(Recipe Function(Recipe r) change) {
    final id = state.selectedId;
    final saved = id == null ? null : _find(id);
    if (id == null || saved == null) return;
    final current = state.drafts[id];
    final next = change(current?.recipe ?? saved.recipe);
    final drafts = Map.of(state.drafts);
    if (sameRecipe(next, saved.recipe)) {
      drafts.remove(id);
    } else {
      drafts[id] = current?.copyWith(recipe: next) ?? PresetDraft(next, saved.revision);
    }
    state = state.copyWith(drafts: drafts);
  }

  void revert(String id) => state = state.copyWith(drafts: Map.of(state.drafts)..remove(id));

  /// "Keep editing" on the changed-elsewhere banner.
  void keepEditing(String id) {
    final draft = state.drafts[id];
    if (draft == null) return;
    state = state.copyWith(drafts: {...state.drafts, id: draft.copyWith(keepEditing: true)});
  }

  /// Puts a draft back, for Undo after Revert.
  void restoreDraft(String id, PresetDraft draft) => state = state.copyWith(drafts: {...state.drafts, id: draft});

  /// Saves [id] (default: the selected preset). A built-in is saved as a new
  /// preset in Mine. [overwrite] replaces a preset that changed in another
  /// window.
  Future<SaveOutcome> save({String? id, bool overwrite = false}) async {
    id ??= state.selectedId;
    final saved = id == null ? null : _find(id);
    final draft = id == null ? null : state.drafts[id];
    if (id == null || saved == null || draft == null) return SaveOutcome.nothingToSave;
    if (saved.builtin) {
      await saveAsNew(id: id);
      return SaveOutcome.savedAsNew;
    }
    try {
      await _library.save(
        saved.copyWith(recipe: draft.recipe),
        expectedRevision: overwrite ? saved.revision : draft.baseRevision,
      );
      state = state.copyWith(drafts: Map.of(state.drafts)..remove(id));
      return SaveOutcome.saved;
    } on ServiceException catch (e) {
      if (e.code == 'REVISION-CONFLICT') return SaveOutcome.conflict;
      rethrow;
    }
  }

  /// Saves [id]'s working recipe (default: the selected preset) as a new
  /// preset in Mine. The draft moves to the new preset; when [id] was
  /// selected, the new preset is selected.
  Future<Preset?> saveAsNew({String? id}) async {
    id ??= state.selectedId;
    final source = id == null ? null : _find(id);
    final recipe = id == null ? null : working(id);
    if (id == null || source == null || recipe == null) return null;
    final created = await _create(source, recipe, name: recipe.name == source.recipe.name ? null : recipe.name);
    state = state.copyWith(
      selectedId: state.selectedId == id ? created.recipe.id : state.selectedId,
      drafts: Map.of(state.drafts)..remove(id),
    );
    return created;
  }

  /// Copies [id]'s working recipe into Mine and selects the copy. The source
  /// keeps any unsaved changes.
  Future<Preset?> duplicate(String id) async {
    final source = _find(id);
    final recipe = working(id);
    if (source == null || recipe == null) return null;
    final created = await _create(source, recipe);
    state = state.copyWith(selectedId: created.recipe.id);
    return created;
  }

  /// A new preset in Mine, started from [templateId]'s settings (UI_SPEC §2,
  /// "New preset"), with its own name and no notes, tags or origin. Selected.
  Future<Preset?> createNew(String templateId) async {
    final template = _find(templateId);
    if (template == null) return null;
    final names = _presets.map((p) => p.recipe.name).toSet();
    var name = 'New preset';
    for (var n = 2; names.contains(name); n++) {
      name = 'New preset $n';
    }
    final created = await _library.save(
      Preset(
        updatedAt: template.updatedAt,
        requires: template.requires,
        recipe: template.recipe.copyWith(
          id: uniqueId(name, _presets.map((p) => p.recipe.id).toSet()),
          name: name,
          notes: '',
          tags: const <String>[],
        ),
      ),
    );
    state = state.copyWith(selectedId: created.recipe.id, query: '', filter: LibraryFilter.all, favoritesOnly: false);
    return created;
  }

  Future<Preset> _create(Preset source, Recipe recipe, {String? name}) {
    final newName = name ?? copyName(recipe.name, _presets.map((p) => p.recipe.name).toSet());
    final newId = uniqueId(newName, _presets.map((p) => p.recipe.id).toSet());
    return _library.save(
      Preset(
        updatedAt: source.updatedAt,
        favorite: false,
        origin: source.builtin ? 'builtin/${source.recipe.id}' : null,
        requires: source.requires,
        recipe: recipe.copyWith(id: newId, name: newName),
      ),
    );
  }

  /// Renames a preset in Mine. The name is part of the recipe, so this saves.
  Future<void> rename(String id, String name) async {
    final saved = _find(id);
    if (saved == null || saved.builtin || name.trim().isEmpty) return;
    final result = await _library.save(
      saved.copyWith(recipe: saved.recipe.copyWith(name: name.trim())),
      expectedRevision: saved.revision,
    );
    _rebase(id, saved.revision, result.revision, (r) => r.copyWith(name: result.recipe.name));
  }

  Future<void> toggleFavorite(String id) async {
    final saved = _find(id);
    if (saved == null) return;
    if (saved.builtin) {
      state = state.copyWith(builtinFavorites: {...state.builtinFavorites, id: !state.isFavorite(saved)});
      return;
    }
    final result = await _library.save(saved.copyWith(favorite: !saved.favorite), expectedRevision: saved.revision);
    _rebase(id, saved.revision, result.revision, (r) => r);
  }

  Future<void> delete(String id) async {
    final saved = _find(id);
    if (saved == null || saved.builtin) return;
    await _library.delete(id, expectedRevision: saved.revision);
    state = state.copyWith(
      drafts: Map.of(state.drafts)..remove(id),
      selectedId: state.selectedId == id ? null : state.selectedId,
    );
  }

  /// Our own save moved the library from [from] to [to]: a draft based on
  /// [from] is still current, not changed elsewhere.
  void _rebase(String id, int from, int to, Recipe Function(Recipe r) change) {
    final draft = state.drafts[id];
    if (draft == null || draft.baseRevision != from) return;
    state = state.copyWith(
      drafts: {
        ...state.drafts,
        id: draft.copyWith(recipe: change(draft.recipe), baseRevision: to),
      },
    );
  }
}

/// "YouTube upload, H.264 (copy)", then "(copy 2)" and so on.
String copyName(String name, Set<String> taken) {
  var candidate = '$name (copy)';
  for (var n = 2; taken.contains(candidate); n++) {
    candidate = '$name (copy $n)';
  }
  return candidate;
}

/// A recipe ID from a name (`^[A-Za-z0-9][A-Za-z0-9._-]*$`), unique in [taken].
String uniqueId(String name, Set<String> taken) {
  var base = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  if (base.isEmpty) base = 'preset';
  if (base.length > 48) base = base.substring(0, 48).replaceAll(RegExp(r'-+$'), '');
  var candidate = base;
  for (var n = 2; taken.contains(candidate); n++) {
    candidate = '$base-$n';
  }
  return candidate;
}
