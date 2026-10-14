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

/// Everything the editor shows for the selected preset.
@immutable
class EditorData {
  const EditorData({
    required this.preset,
    required this.recipe,
    required this.draft,
    required this.catalog,
    required this.installations,
    required this.installation,
    required this.defaultInstallationId,
    required this.media,
    required this.compiled,
    required this.perMinute,
    required this.total,
    this.capabilities,
    this.lint,
    this.basic,
  });

  final Preset preset;

  /// What the editor shows: the draft, else the saved recipe.
  final Recipe recipe;
  final PresetDraft? draft;
  final ProfileCatalog catalog;
  final List<FFmpegInstallation> installations;

  /// The FFmpeg the checks are for.
  final FFmpegInstallation? installation;
  final String? defaultInstallationId;
  final MediaDescription media;
  final CoreResult<CompileResult> compiled;

  /// Rate per minute and range (no length).
  final CoreResult<SizeEstimate> perMinute;

  /// The total for the typed length; null when no length is typed.
  final CoreResult<SizeEstimate>? total;

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
  final preset = presets.where((p) => p.recipe.id == id).firstOrNull;
  if (preset == null) return null;

  final core = ref.watch(veCoreProvider);
  final catalog = ref.watch(profilesProvider);
  final settings = ref.watch(machineSettingsProvider).value;
  final installations = settings?.installations ?? const <FFmpegInstallation>[];
  final installationId = ref.watch(selectedInstallationIdProvider);
  final installation = installations.where((i) => i.id == installationId).firstOrNull;
  final capabilities = installationId == null ? null : ref.watch(capabilitiesProvider(installationId)).value;

  final draft = state.drafts[id];
  final recipe = draft?.recipe ?? preset.recipe;
  final media = SamplePreview.media;
  final ext = catalog.containers.where((c) => c.id == recipe.container.format).firstOrNull?.ext;
  final length = ref.watch(sizeLengthSecProvider);
  final paths = SamplePreview.paths(ext);
  final advanced = recipe.command.mode == 'template';

  return EditorData(
    preset: preset,
    recipe: recipe,
    draft: draft,
    catalog: catalog,
    installations: installations,
    installation: installation,
    defaultInstallationId: settings?.defaultFFmpegId,
    media: media,
    compiled: CoreResult.run(() => core.compile(recipe, media: media, paths: paths, capabilities: capabilities)),
    perMinute: CoreResult.run(() => core.estimate(recipe, media: media)),
    total: length == null
        ? null
        : CoreResult.run(() => core.estimate(recipe, media: media, durationSec: length.toDouble())),
    capabilities: capabilities,
    lint: advanced ? CoreResult.run(() => core.lint(recipe.command.template, capabilities: capabilities)) : null,
    basic: advanced
        ? CoreResult.run(
            () => core.compile(
              recipe.copyWith(command: recipe.command.copyWith(mode: 'structured')),
              media: media,
              paths: paths,
              capabilities: capabilities,
            ),
          )
        : null,
  );
});
