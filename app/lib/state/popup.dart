import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../app/launch.dart';
import '../design/components/signal_path/signal_path_model.dart';
import '../design/format.dart';
import 'app_state.dart';
import 'editor.dart';
import 'presets.dart' show copyName, presetId, presetRecipe, uniqueId;
import 'preview.dart';
import 'recipe_edit.dart';
import 'services.dart';

// The VEGAS popup (`--edit-session <dir>`, UI_SPEC §4, CONTRACTS C4): one
// render template from VEGAS, edited and written back as one final result.
// Everything about recipes (compile, checks, diff) is the core's; the
// library is reached only through C3.

/// A session file that is missing or invalid stays so: no retries.
Duration? _noRetry(int count, Object error) => null;

/// The session's request, read once through EditSessionService. A missing or
/// invalid request fails this provider: the popup says so and closing it is
/// a Cancel (no result means cancel, C4).
final editSessionRequestProvider = FutureProvider<EditSessionRequest>(retry: _noRetry, (ref) {
  final mode = ref.watch(launchModeProvider);
  if (mode is! EditSessionLaunch) {
    throw const ServiceException('SESSION-NOT-FOUND', 'Vegas Encoder wasn’t started for an edit session.');
  }
  return ref.watch(editSessionServiceProvider).readRequest(mode.sessionDir);
});

/// The owner window C4 names (a decimal string), or null when it isn't one.
int? ownerHwndOf(EditSessionRequest request) {
  final value = int.tryParse(request.ownerHwnd);
  return value == null || value <= 0 ? null : value;
}

/// What the library has for the template's origin.
@immutable
sealed class OriginLibrary {
  const OriginLibrary();
}

/// The template has no origin: it was made in VEGAS.
final class NoOrigin extends OriginLibrary {
  const NoOrigin();
}

/// The origin preset as the library has it now.
final class OriginFound extends OriginLibrary {
  const OriginFound(this.preset);
  final Preset preset;
}

/// The origin preset is no longer in the library.
final class OriginMissing extends OriginLibrary {
  const OriginMissing();
}

/// The library couldn't be read; [message] says why.
final class OriginUnreadable extends OriginLibrary {
  const OriginUnreadable(this.message);
  final String message;
}

/// What Undo puts back after Load preset, Replace or Take library changes.
@immutable
class PopupSnapshot {
  const PopupSnapshot({
    required this.message,
    required this.recipe,
    required this.origin,
    required this.base,
    required this.library,
  });

  /// The Undo bar's text: "Loaded “Client review”."
  final String message;
  final Recipe recipe;
  final Origin? origin;
  final Recipe? base;
  final OriginLibrary library;
}

/// The popup's session: the template as it opened, its working settings, its
/// origin and the library's view of that origin.
@immutable
class PopupState {
  PopupState({
    required this.request,
    required this.opened,
    required this.recipe,
    required this.origin,
    required this.base,
    required this.library,
    this.node = SignalNode.video,
    this.commandMultiline = true,
    this.lengthText = '',
    this.undo,
    this.finished,
  });

  final EditSessionRequest request;

  /// The template's settings when the popup opened: Reset and the Cancel
  /// question compare with these.
  final Recipe opened;

  /// The settings Apply writes.
  final Recipe recipe;

  /// The preset these settings came from, or null (made in VEGAS).
  final Origin? origin;

  /// The origin revision's own settings, for "changes in this template" and
  /// a three-way update; null when the template carries no copy of them.
  final Recipe? base;
  final OriginLibrary library;
  final SignalNode node;
  final bool commandMultiline;

  /// The File node's length as typed; the project's length when VEGAS shared
  /// it (never written to the desktop's remembered length, C7).
  final String lengthText;
  final PopupSnapshot? undo;

  /// `apply` or `cancel` once the final result is written (C4: only one).
  final String? finished;

  String get templateName => request.templateName;

  /// The template as the shared editor's preset: nothing is saved from it.
  late final Preset asPreset = Preset(
    updatedAt: '1970-01-01T00:00:00Z',
    requires: PresetRequirements(known: false),
    recipe: opened,
  );

  /// The library's current preset for the origin, when it has one.
  Preset? get libraryPreset => switch (library) {
    OriginFound(:final preset) => preset,
    _ => null,
  };

  /// The library has a newer revision of the origin than the template's.
  bool get libraryNewer {
    final latest = libraryPreset;
    return latest != null && origin != null && latest.revision > origin!.revision;
  }

  /// Something differs from how the template opened (Cancel asks first).
  bool get changed => !sameRecipe(recipe, opened) || jsonEncodeOrigin(origin) != jsonEncodeOrigin(request.origin);

  PopupSnapshot snapshot(String message) =>
      PopupSnapshot(message: message, recipe: recipe, origin: origin, base: base, library: library);

  PopupState copyWith({
    Recipe? recipe,
    Object? origin = _keep,
    Object? base = _keep,
    OriginLibrary? library,
    SignalNode? node,
    bool? commandMultiline,
    String? lengthText,
    Object? undo = _keep,
    String? finished,
  }) => PopupState(
    request: request,
    opened: opened,
    recipe: recipe ?? this.recipe,
    origin: identical(origin, _keep) ? this.origin : origin as Origin?,
    base: identical(base, _keep) ? this.base : base as Recipe?,
    library: library ?? this.library,
    node: node ?? this.node,
    commandMultiline: commandMultiline ?? this.commandMultiline,
    lengthText: lengthText ?? this.lengthText,
    undo: identical(undo, _keep) ? this.undo : undo as PopupSnapshot?,
    finished: finished ?? this.finished,
  );
}

const Object _keep = Object();

/// Origins compared by content (models have no `==`).
String jsonEncodeOrigin(Origin? origin) => origin == null ? '' : canonicalJson(origin.toJson());

final popupProvider = AsyncNotifierProvider<PopupController, PopupState>(PopupController.new, retry: _noRetry);

/// Edits, Load preset, the library flows, Apply and Cancel.
class PopupController extends AsyncNotifier<PopupState> implements RecipeEditor {
  @override
  Future<PopupState> build() async {
    final request = await ref.watch(editSessionRequestProvider.future);
    final origin = request.origin;
    final length = request.context.media?.durationSec;
    return PopupState(
      request: request,
      opened: request.recipe,
      recipe: request.recipe,
      origin: origin,
      base: request.baseRecipe,
      library: origin == null ? const NoOrigin() : await _lookUp(origin.presetId),
      lengthText: length == null ? '' : VeFormat.duration(length),
    );
  }

  /// One read of the origin preset (no watch: the popup stays light).
  Future<OriginLibrary> _lookUp(String id) async {
    try {
      final preset = await ref.read(presetLibraryProvider).get(id);
      return preset == null ? const OriginMissing() : OriginFound(preset);
    } on ServiceException catch (e) {
      return OriginUnreadable(e.message);
    }
  }

  PopupState get _s => state.requireValue;
  void _set(PopupState next) => state = AsyncData(next);

  @override
  void edit(Recipe Function(Recipe r) change) {
    if (_s.finished != null) return;
    _set(_s.copyWith(recipe: change(_s.recipe)));
  }

  /// Advanced mode's command text (`command.template`).
  void setTemplate(String text) => edit((r) => r.copyWith(command: r.command.copyWith(template: text)));

  /// Basic or Advanced; both settings are kept (SETTINGS_AND_COMMANDS §5).
  void setMode({required bool advanced, String? template}) => edit(
    (r) => r.copyWith(
      command: r.command.copyWith(mode: advanced ? 'template' : 'structured', template: template ?? r.command.template),
    ),
  );

  void selectNode(SignalNode node) => _set(_s.copyWith(node: node));
  void toggleCommandLayout() => _set(_s.copyWith(commandMultiline: !_s.commandMultiline));
  void setLengthText(String text) => _set(_s.copyWith(lengthText: text));

  /// Load preset (UI_SPEC §4): the template takes [preset]'s settings at once
  /// and keeps its own name; the preset becomes its origin. Undo puts back
  /// what was there.
  void loadPreset(Preset preset) {
    final s = _s;
    final recipe = presetRecipe(preset);
    _set(
      s.copyWith(
        recipe: recipe.copyWith(name: s.recipe.name),
        origin: Origin(presetId: recipe.id, revision: preset.revision, name: recipe.name),
        base: recipe,
        library: OriginFound(preset),
        undo: s.snapshot('Loaded “${recipe.name}”.'),
      ),
    );
  }

  /// Update from library, "Replace with revision N": the library's settings,
  /// keeping the template's name.
  void replaceWithLibrary() {
    final s = _s;
    final latest = s.libraryPreset;
    if (latest == null || s.origin == null) return;
    final recipe = presetRecipe(latest);
    _set(
      s.copyWith(
        recipe: recipe.copyWith(name: s.recipe.name),
        origin: s.origin!.copyWith(revision: latest.revision, name: recipe.name),
        base: recipe,
        undo: s.snapshot('Replaced with revision ${latest.revision}.'),
      ),
    );
  }

  /// "Take library changes, keep mine": each field the library changed since
  /// the origin revision ([since], the core's diff) takes the library's value;
  /// the template's own changes stay. Offered only when no field changed in
  /// both places.
  void takeLibraryChanges(List<FieldDiff> since) {
    final s = _s;
    final latest = s.libraryPreset;
    if (latest == null || s.origin == null) return;
    final recipe = presetRecipe(latest);
    var next = s.recipe;
    for (final d in since) {
      next = resetField(next, recipe, d.path);
    }
    _set(
      s.copyWith(
        recipe: next,
        origin: s.origin!.copyWith(revision: latest.revision, name: recipe.name),
        base: recipe,
        undo: s.snapshot('Took the revision ${latest.revision} changes and kept yours.'),
      ),
    );
  }

  void undo() {
    final s = _s;
    final u = s.undo;
    if (u == null) return;
    _set(s.copyWith(recipe: u.recipe, origin: u.origin, base: u.base, library: u.library, undo: null));
  }

  void dismissUndo() => _set(_s.copyWith(undo: null));

  /// Save as new preset…: a preset in Mine named [name] (made unique) with
  /// the template's settings; it becomes the template's origin. Its own
  /// origin is the template's, in C3's copy form.
  Future<Preset> saveAsNew(String name) async {
    final s = _s;
    final library = ref.read(presetLibraryProvider);
    final presets = await library.list();
    final names = presets.map((p) => presetRecipe(p).name).toSet();
    final newName = names.contains(name) ? copyName(name, names) : name;
    final origin = s.origin;
    final from = s.libraryPreset;
    final created = await library.save(
      Preset(
        // The library stamps its own time on save.
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        origin: origin == null
            ? null
            : from?.builtin == true
            ? 'builtin/${origin.presetId}'
            : 'preset/${origin.presetId}@${origin.revision}',
        requires: PresetRequirements(known: false),
        recipe: s.recipe.copyWith(id: uniqueId(newName, presets.map(presetId).toSet()), name: newName),
      ),
    );
    if (!ref.mounted) return created;
    final recipe = presetRecipe(created);
    _set(
      _s.copyWith(
        origin: Origin(presetId: recipe.id, revision: created.revision, name: recipe.name),
        base: recipe,
        library: OriginFound(created),
        undo: null,
      ),
    );
    return created;
  }

  /// Update "the origin": the library preset takes the template's settings at
  /// its next revision. Not for built-ins (the library refuses them). A
  /// change made elsewhere meanwhile comes back as `REVISION-CONFLICT`, and
  /// the library is read again.
  Future<Preset> updateOrigin() async {
    final s = _s;
    final latest = s.libraryPreset;
    if (latest == null || latest.builtin || s.origin == null) {
      throw const ServiceException('READ-ONLY', 'Only a preset in Mine can be updated.');
    }
    final library = ref.read(presetLibraryProvider);
    final latestRecipe = presetRecipe(latest);
    final Preset saved;
    try {
      saved = await library.save(
        latest.copyWith(
          recipe: s.recipe.copyWith(id: latestRecipe.id, name: latestRecipe.name),
        ),
        expectedRevision: latest.revision,
      );
    } on ServiceException catch (e) {
      if (e.code == 'REVISION-CONFLICT' && ref.mounted) {
        final library = await _lookUp(latestRecipe.id);
        if (ref.mounted) _set(_s.copyWith(library: library));
      }
      rethrow;
    }
    if (!ref.mounted) return saved;
    final recipe = presetRecipe(saved);
    _set(
      _s.copyWith(
        origin: Origin(presetId: recipe.id, revision: saved.revision, name: recipe.name),
        base: recipe,
        library: OriginFound(saved),
        undo: null,
      ),
    );
    return saved;
  }

  /// Apply to template (C4): the complete settings and their origin, as the
  /// session's one final result.
  Future<void> apply() {
    final s = _s;
    return _finish(
      EditSessionResult(sessionId: s.request.sessionId, action: 'apply', recipe: s.recipe, origin: s.origin),
    );
  }

  /// Cancel: a cancel result, so VEGAS keeps the template as it was.
  Future<void> cancel() => _finish(EditSessionResult(sessionId: _s.request.sessionId, action: 'cancel'));

  Future<void> _finish(EditSessionResult result) async {
    if (_s.finished != null) return;
    final mode = ref.read(launchModeProvider);
    if (mode is! EditSessionLaunch) return;
    await ref.read(editSessionServiceProvider).writeResult(mode.sessionDir, result);
    if (ref.mounted) _set(_s.copyWith(finished: result.action));
  }
}

/// The FFmpeg the popup checks against: the default one.
final popupInstallationProvider = Provider<FFmpegInstallation?>((ref) {
  final settings = ref.watch(machineSettingsProvider).value;
  final id = settings?.defaultFFmpegId;
  return settings?.installations.where((i) => i.id == id).firstOrNull;
});

/// Everything the shared editor shows for the template: the core's compile,
/// checks and estimates with the project's facts when VEGAS shared them, the
/// sample's otherwise (labelled so).
final popupEditorProvider = Provider<EditorData?>((ref) {
  final s = ref.watch(popupProvider).value;
  if (s == null) return null;
  final core = ref.watch(veCoreProvider);
  final catalog = ref.watch(profilesProvider);
  final settings = ref.watch(machineSettingsProvider).value;
  final installation = ref.watch(popupInstallationProvider);
  final probed = installation == null ? null : ref.watch(capabilitiesProvider(installation.id)).value;
  final recipe = s.recipe;
  final label = installation?.label ?? '';
  final capabilities = capabilitiesFor(probed, recipe, label: label);
  final projectMedia = s.request.context.media;
  final media = projectMedia ?? SamplePreview.media;
  final ext = catalog.containers.where((c) => c.id == recipe.container.format).firstOrNull?.ext;
  final preview = compilePreview(core, recipe, media: media, basicExtension: ext, capabilities: capabilities, target: s.request.context.target);
  final paths = preview.paths;
  final length = VeFormat.parseLength(s.lengthText);
  final advanced = recipe.command.mode == 'template';
  final asBasic = advanced ? recipe.copyWith(command: recipe.command.copyWith(mode: 'structured')) : recipe;

  return EditorData(
    preset: s.asPreset,
    saved: s.opened,
    recipe: recipe,
    draft: null,
    catalog: catalog,
    installations: settings?.installations ?? const [],
    installation: installation,
    defaultInstallationId: settings?.defaultFFmpegId,
    media: media,
    paths: paths,
    preview: projectMedia == null ? PreviewMedia.projectUnknown : PreviewMedia.project,
    compiled: preview.result,
    perMinute: () => CoreResult.run(() => core.estimate(recipe, media: media)),
    total: () => length == null
        ? null
        : CoreResult.run(() => core.estimate(recipe, media: media, durationSec: length.toDouble())),
    capabilities: capabilities,
    lint: advanced ? CoreResult.run(() => core.lint(recipe.command.template, capabilities: capabilities)) : null,
    basic: advanced
        ? CoreResult.run(
            () => core.compile(
              asBasic,
              media: media,
              paths: paths,
              capabilities: capabilitiesFor(probed, asBasic, label: label),
            ),
          )
        : null,
  );
});

/// The core's differences (C2 `diff`) between the template's origin revision
/// and now: what this template changed, and what the library changed since.
@immutable
class PopupChanges {
  const PopupChanges({this.local, this.since, this.fromLibrary});

  /// The template's own changes from the origin revision; null without a
  /// copy of that revision.
  final CoreResult<List<FieldDiff>>? local;

  /// The library's changes since the origin revision; null unless the library
  /// is newer and the template carries the origin revision.
  final CoreResult<List<FieldDiff>>? since;

  /// The library is newer but the template carries no copy of its revision:
  /// how the template differs from the library now (Replace only).
  final CoreResult<List<FieldDiff>>? fromLibrary;

  /// "Take library changes, keep mine" is possible: both lists are known and
  /// no field is in both.
  bool get canMerge {
    final mine = local?.value;
    final theirs = since?.value;
    if (mine == null || theirs == null || theirs.isEmpty) return false;
    final paths = {for (final d in mine) d.path};
    return !theirs.any((d) => paths.contains(d.path));
  }
}

final popupChangesProvider = Provider<PopupChanges>((ref) {
  final s = ref.watch(popupProvider).value;
  if (s == null) return const PopupChanges();
  final core = ref.watch(veCoreProvider);
  final base = s.base;
  final latest = s.libraryPreset;
  return PopupChanges(
    local: base == null ? null : CoreResult.run(() => core.diff(base, s.recipe)),
    since: base == null || !s.libraryNewer ? null : CoreResult.run(() => core.diff(base, presetRecipe(latest!))),
    fromLibrary: base != null || !s.libraryNewer
        ? null
        : CoreResult.run(() => core.diff(s.recipe, presetRecipe(latest!))),
  );
});

/// Why Apply is off, or null when the template can render: the core's errors
/// (Basic checks, Advanced lint), or no result from the core at all.
String? applyBlocked(EditorData data) {
  if (!data.compiled.ok) return 'The core couldn’t check these settings: ${data.compiled.error!.message}';
  final lintErrors = data.lint?.value?.any((d) => d.level == IssueLevel.error) ?? false;
  if (data.hasErrors || lintErrors) return 'Fix the errors first. The template can’t render with them.';
  return null;
}
