import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import 'presets.dart';
import 'preview.dart';
import 'recipe_edit.dart';
import 'services.dart';
import 'ui_state.dart';

/// A core result, or why the core couldn't give one. A native failure (a
/// `CoreException` such as `JSON-LIMIT` or `NATIVE-LOAD`) stays a failure: the
/// editor says what went wrong instead of showing a stale or invented result.
/// The fake core (tests) only knows the built-in presets as shipped, so its
/// edits come back as `B0-FIXTURE-MISSING`, which gets its own notice.
@immutable
class CoreResult<T> {
  const CoreResult.ok(T this.value) : error = null;
  const CoreResult.failed(CoreException this.error) : value = null;
  final T? value;
  final CoreException? error;

  bool get ok => error == null;

  /// The fake core has no stored answer for this request. Never set by the
  /// native core.
  bool get notInPreviewCore => error?.code == 'B0-FIXTURE-MISSING';

  static CoreResult<T> run<T>(T Function() call) {
    try {
      return CoreResult.ok(call());
    } on CoreException catch (e) {
      return CoreResult.failed(e);
    }
  }
}

/// The last sample compile of each recipe object. The editor and the library
/// row of the draft being edited compile the same recipe object with the same
/// capability view, so they share one compile per edit (TECH_ARCHITECTURE
/// §9.3, ≤ 4 ms per change).
final _sampleCompiles =
    Expando<({VeCore core, CoreCapabilities? capabilities, String? ext, CoreResult<CompileResult> result})>();

/// Ask the core for the active container before presenting an Advanced preview
/// filename. The suffix is display guidance, never an input to muxer identity.
({CompilePaths paths, CoreResult<CompileResult> result}) compilePreview(
  VeCore core,
  Recipe recipe, {
  required MediaDescription media,
  String? basicExtension,
  CoreCapabilities? capabilities,
  JsonMap? target,
}) {
  final extension = recipe.command.mode == 'template' ? null : basicExtension;
  var paths = SamplePreview.paths(extension);
  if (target != null) paths = paths.copyWith(target: target);
  var result = CoreResult.run(() => core.compile(recipe, media: media, paths: paths, capabilities: capabilities));
  final activeExtension = result.value?.outputExtension;
  if (activeExtension != null && activeExtension != extension) {
    paths = SamplePreview.paths(activeExtension);
    if (target != null) paths = paths.copyWith(target: target);
    result = CoreResult.run(() => core.compile(recipe, media: media, paths: paths, capabilities: capabilities));
  }
  return (paths: paths, result: result);
}

/// [recipe] compiled by [core] for the documented sample, with [ext] as the
/// output's extension.
CoreResult<CompileResult> compileSample(VeCore core, Recipe recipe, {String? ext, CoreCapabilities? capabilities}) {
  final last = _sampleCompiles[recipe];
  if (last != null && identical(last.core, core) && identical(last.capabilities, capabilities) && last.ext == ext) {
    return last.result;
  }
  final result = compilePreview(
    core,
    recipe,
    media: SamplePreview.media,
    basicExtension: ext,
    capabilities: capabilities,
  ).result;
  _sampleCompiles[recipe] = (core: core, capabilities: capabilities, ext: ext, result: result);
  return result;
}

/// What the editor's panels change: the desktop's presets and the popup's
/// template.
abstract interface class RecipeEditor {
  void edit(Recipe Function(Recipe r) change);
}

/// Where the editor's media facts come from (UI_SPEC §4: project facts may be
/// unknown; sample facts are labelled as samples).
enum PreviewMedia {
  /// The documented sample: the desktop app has no project.
  sample,

  /// The VEGAS project's own facts (the popup, when VEGAS shared them).
  project,

  /// The popup when VEGAS didn't share the project's facts: they show as
  /// "Set by the project", and the preview uses the sample.
  projectUnknown,
}

/// Everything the editor shows for the selected preset. The size estimates
/// are worked out when first read (the File node), not on every edit
/// (TECH_ARCHITECTURE §9.1, §9.3).
@immutable
class EditorData {
  EditorData({
    required this.preset,
    required this.saved,
    required this.recipe,
    required this.draft,
    required this.catalog,
    required this.installations,
    required this.installation,
    required this.defaultInstallationId,
    required this.media,
    required this.paths,
    required this.compiled,
    required this._perMinute,
    required this._total,
    this.capabilities,
    this.lint,
    this.basic,
    this.preview = PreviewMedia.sample,
  });

  final CoreResult<SizeEstimate> Function() _perMinute;
  final CoreResult<SizeEstimate>? Function() _total;

  final Preset preset;

  /// What Reset goes back to and changed fields compare with: the saved
  /// preset, or in the popup the template as it opened.
  final Recipe saved;

  /// What the editor shows: the draft, else the saved recipe.
  final Recipe recipe;
  final PresetDraft? draft;
  final ProfileCatalog catalog;
  final List<FFmpegInstallation> installations;

  /// The FFmpeg the checks are for.
  final FFmpegInstallation? installation;
  final String? defaultInstallationId;
  final MediaDescription media;

  /// The paths the command is compiled with (pipes, output, project).
  final CompilePaths paths;
  final PreviewMedia preview;
  final CoreResult<CompileResult> compiled;

  /// Rate per minute and range (no length).
  late final CoreResult<SizeEstimate> perMinute = _perMinute();

  /// The total for the typed length; null when no length is typed.
  late final CoreResult<SizeEstimate>? total = _total();

  /// What the core knows of the chosen FFmpeg, for checks, lint and
  /// suggestions; null until probed.
  final CoreCapabilities? capabilities;

  /// Advanced mode: the core's lint of the command (`VeCore.lint`, UTF-16
  /// ranges). Null in Basic mode.
  final CoreResult<List<Diagnostic>>? lint;

  /// Advanced mode: the same recipe compiled as Basic, for what switching back
  /// would render and for replacing the command with the Basic settings
  /// (`advancedTemplate`). Null in Basic mode.
  final CoreResult<CompileResult>? basic;

  /// The command, not the Basic settings, renders (`command.mode` template).
  bool get advanced => recipe.command.mode == 'template';

  bool get dirty => draft != null;

  /// The library moved on since this draft started, and the user hasn't
  /// chosen to keep editing.
  bool get changedElsewhere => draft != null && draft!.baseRevision != preset.revision && !draft!.keepEditing;

  /// The library moved on since this draft started.
  bool get behindLibrary => draft != null && draft!.baseRevision != preset.revision;

  List<Issue> get issues => compiled.value?.issues ?? const [];

  /// Recipe fields whose generated option Basic Extra arguments replaced.
  List<String> get overriddenFields => compiled.value?.overriddenFields ?? const [];
  List<Issue> issuesFor(String field) => issues.where((i) => i.field == field).toList();
  bool get hasErrors => issues.any((i) => i.level == IssueLevel.error);

  /// The first core failure, for the editor's notice.
  CoreException? get coreError => compiled.error ?? perMinute.error;

  EncoderProfile? get videoProfile => catalog.video.where((e) => e.id == recipe.video.encoder).firstOrNull;
  EncoderProfile? get audioProfile => catalog.audio.where((e) => e.id == recipe.audioTrack.encoder).firstOrNull;
  ContainerProfile? get containerProfile =>
      catalog.containers.where((c) => c.id == recipe.container.format).firstOrNull;
}

/// The FFmpeg the editor checks against: the chosen one, else the default.
final selectedInstallationIdProvider = Provider<String?>((ref) {
  final chosen = ref.watch(presetsControllerProvider.select((s) => s.installationId));
  return chosen ?? ref.watch(machineSettingsProvider).value?.defaultFFmpegId;
});

final editorProvider = Provider<EditorData?>((ref) {
  final presets = ref.watch(presetsProvider).value;
  final state = ref.watch(presetsControllerProvider);
  final id = state.selectedId;
  if (presets == null || id == null) return null;
  final preset = presets.where((p) => presetId(p) == id).firstOrNull;
  if (preset == null) return null;

  final core = ref.watch(veCoreProvider);
  final catalog = ref.watch(profilesProvider);
  final settings = ref.watch(machineSettingsProvider).value;
  final installations = settings?.installations ?? const <FFmpegInstallation>[];
  final installationId = ref.watch(selectedInstallationIdProvider);
  final installation = installations.where((i) => i.id == installationId).firstOrNull;
  final probed = installationId == null ? null : ref.watch(capabilitiesProvider(installationId)).value;

  final draft = state.drafts[id];
  final recipe = draft?.recipe ?? presetRecipe(preset);
  final label = installation?.label ?? '';
  final capabilities = capabilitiesFor(probed, recipe, label: label);
  final media = SamplePreview.media;
  final ext = catalog.containers.where((c) => c.id == recipe.container.format).firstOrNull?.ext;
  final length = ref.watch(sizeLengthSecProvider);
  final advanced = recipe.command.mode == 'template';
  final compiled = compileSample(core, recipe, ext: ext, capabilities: capabilities);
  final paths = SamplePreview.paths(compiled.value?.outputExtension ?? (advanced ? null : ext));
  final asBasic = advanced ? recipe.copyWith(command: recipe.command.copyWith(mode: 'structured')) : recipe;

  return EditorData(
    preset: preset,
    saved: presetRecipe(preset),
    recipe: recipe,
    draft: draft,
    catalog: catalog,
    installations: installations,
    installation: installation,
    defaultInstallationId: settings?.defaultFFmpegId,
    media: media,
    paths: paths,
    compiled: compiled,
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
