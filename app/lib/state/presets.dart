import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../design/components/signal_path/signal_path_model.dart';
import 'editor.dart' show RecipeEditor;
import 'recipe_edit.dart';
import 'services.dart';
import 'ui_state.dart';

enum LibraryFilter { all, builtin, mine }

final _presetRecipes = Expando<Recipe>();

/// [preset]'s saved recipe, one object per preset object. `Preset.recipe`
/// makes a new copy each time; one shared (immutable) object lets the editor
/// and the library row share a compile, and lookups by ID stay cheap
/// (TECH_ARCHITECTURE §9.3).
Recipe presetRecipe(Preset preset) => _presetRecipes[preset] ??= preset.recipe;

/// [preset]'s ID, without copying its recipe.
String presetId(Preset preset) => presetRecipe(preset).id;

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
    commandMultiline: commandMultiline ?? this.commandMultiline,
  );
}

const Object _keep = Object();

/// What a save did, for the confirmation toast and selection.
enum SaveOutcome { saved, savedAsNew, conflict, nothingToSave }

final presetsControllerProvider = NotifierProvider<PresetsController, PresetsState>(PresetsController.new);

class PresetsController extends Notifier<PresetsState> implements RecipeEditor {
  @override
  PresetsState build() => const PresetsState();

  PresetLibrary get _library => ref.read(presetLibraryProvider);
  List<Preset> get _presets => ref.read(presetsProvider).value ?? const [];
  Preset? _find(String id) => _presets.where((p) => presetId(p) == id).firstOrNull;

  /// Waits for the library's list to include this window's own write. The file
  /// library polls (C3 `watch`, 250 ms): without this the editor would show the
  /// old list for a moment, a new preset's selection would fall back to the
  /// first preset, and a rebased draft would look changed elsewhere.
  Future<void> _refresh() async {
    ref.invalidate(presetsProvider);
    // Listen while waiting: Riverpod pauses a provider nobody listens to
    // (History is open, not Presets), and a paused watch never delivers.
    final listening = ref.listen(presetsProvider, (_, _) {});
    try {
      await ref.read(presetsProvider.future);
    } finally {
      listening.close();
    }
  }

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
  Recipe? working(String id) {
    final saved = _find(id);
    return state.drafts[id]?.recipe ?? (saved == null ? null : presetRecipe(saved));
  }

  /// Applies an edit to the selected preset. Editing back to the saved recipe
  /// drops the draft, so the preset is clean again.
  @override
  void edit(Recipe Function(Recipe r) change) {
    final id = state.selectedId;
    final saved = id == null ? null : _find(id);
    if (id == null || saved == null) return;
    final current = state.drafts[id];
    final next = change(current?.recipe ?? presetRecipe(saved));
    final drafts = Map.of(state.drafts);
    if (sameRecipe(next, presetRecipe(saved))) {
      drafts.remove(id);
    } else {
      drafts[id] = current?.copyWith(recipe: next) ?? PresetDraft(next, saved.revision);
    }
    state = state.copyWith(drafts: drafts);
  }

  /// Advanced mode's command text (`command.template`).
  void setTemplate(String text) => edit((r) => r.copyWith(command: r.command.copyWith(template: text)));

  /// Basic or Advanced (`command.mode` structured or template). Both settings
  /// are kept (SETTINGS_AND_COMMANDS §5); [template] replaces the command,
  /// such as the seed from the Basic settings.
  void setMode({required bool advanced, String? template}) => edit(
    (r) => r.copyWith(
      command: r.command.copyWith(mode: advanced ? 'template' : 'structured', template: template ?? r.command.template),
    ),
  );

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
      await _refresh();
      if (!ref.mounted) return SaveOutcome.saved;
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
    await _refresh();
    if (!ref.mounted) return created;
    state = state.copyWith(
      selectedId: state.selectedId == id ? created.recipe.id : state.selectedId,
      drafts: Map.of(state.drafts)..remove(id),
    );
    return created;
  }

  /// Copies [id]'s working recipe into Mine and selects the copy. The source
  /// keeps any unsaved changes. The copy starts unstarred (C3's
  /// `PresetTransfer.duplicate` would copy the star, and only the saved
  /// recipe).
  Future<Preset?> duplicate(String id) async {
    final source = _find(id);
    final recipe = working(id);
    if (source == null || recipe == null) return null;
    final created = await _create(source, recipe);
    await _refresh();
    if (!ref.mounted) return created;
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
    await _refresh();
    if (!ref.mounted) return created;
    state = state.copyWith(selectedId: created.recipe.id, query: '', filter: LibraryFilter.all, favoritesOnly: false);
    return created;
  }

  /// A new preset in Mine holding [job]'s settings (History's "Open settings
  /// as new preset"), named after its template, or "[name] (copy)" when that
  /// name is taken. The library records where it came from (C3
  /// `PresetTransfer.fromJob`, origin `job/<id>`). Selected, with the
  /// library's search and filters cleared so it shows.
  Future<Preset?> createFromJob(JobRecord job) async {
    final names = _presets.map((p) => p.recipe.name).toSet();
    final name = job.templateName;
    final newName = names.contains(name) ? copyName(name, names) : name;
    final created = await ref
        .read(presetTransferProvider)
        .fromJob(job, newId: uniqueId(newName, _presets.map((p) => p.recipe.id).toSet()), name: newName);
    await _refresh();
    if (!ref.mounted) return created;
    state = state.copyWith(selectedId: created.recipe.id, query: '', filter: LibraryFilter.all, favoritesOnly: false);
    return created;
  }

  /// Adds the preset in a share string (`vepreset:1:…`, C3
  /// `PresetTransfer.importShareString`) to Mine and selects it, with the
  /// library's search and filters cleared so it shows. The library decodes,
  /// bounds and checks it; its refusal (`SHARE-VERSION`, `SHARE-INVALID`,
  /// `RECIPE-INVALID`…) reaches the caller. The name stays as shared; the ID is
  /// new ("imported-preset", "imported-preset-2"…), since the name is only
  /// known once the library has read it.
  Future<Preset> importShareString(String text) async {
    final created = await ref
        .read(presetTransferProvider)
        .importShareString(text.trim(), newId: uniqueId('imported preset', _presets.map((p) => p.recipe.id).toSet()));
    await _refresh();
    if (!ref.mounted) return created;
    state = state.copyWith(selectedId: created.recipe.id, query: '', filter: LibraryFilter.all, favoritesOnly: false);
    return created;
  }

  /// Imports the caller-selected file through the service's bounded read and
  /// validation. Like a share import, this creates a new preset without
  /// replacing an existing one, then refreshes and selects it.
  Future<Preset> importFile(String selectedPath) async {
    final created = await ref
        .read(presetTransferProvider)
        .importFrom(selectedPath, newId: uniqueId('imported preset', _presets.map((p) => p.recipe.id).toSet()));
    await _refresh();
    if (!ref.mounted) return created;
    state = state.copyWith(selectedId: created.recipe.id, query: '', filter: LibraryFilter.all, favoritesOnly: false);
    return created;
  }

  /// Saves [recipe] as a new preset in Mine copied from [source], with the
  /// origin C3 defines for a copy: `builtin/<id>`, or `preset/<id>@<revision>`
  /// (the revision the edit started from).
  Future<Preset> _create(Preset source, Recipe recipe, {String? name}) {
    final newName = name ?? copyName(recipe.name, _presets.map((p) => p.recipe.name).toSet());
    final newId = uniqueId(newName, _presets.map((p) => p.recipe.id).toSet());
    final id = source.recipe.id;
    final revision = state.drafts[id]?.baseRevision ?? source.revision;
    return _library.save(
      Preset(
        updatedAt: source.updatedAt,
        favorite: false,
        origin: source.builtin ? 'builtin/$id' : 'preset/$id@$revision',
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
    await _refresh();
    if (!ref.mounted) return;
    _rebase(id, saved.revision, result.revision, (r) => r.copyWith(name: result.recipe.name));
  }

  /// Stars or unstars [id], built-ins included (C3 `PresetPreferences`; the
  /// library keeps built-in stars beside them). A preset in Mine moves to its
  /// next revision; its draft stays current.
  Future<void> toggleFavorite(String id) async {
    final saved = _find(id);
    if (saved == null) return;
    final result = await ref.read(presetPreferencesProvider).setPreferences(id, favorite: !saved.favorite);
    await _refresh();
    if (!ref.mounted || saved.builtin) return;
    _rebase(id, saved.revision, result.revision, (r) => r);
  }

  Future<void> delete(String id) async {
    final saved = _find(id);
    if (saved == null || saved.builtin) return;
    await _library.delete(id, expectedRevision: saved.revision);
    await _refresh();
    if (!ref.mounted) return;
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
