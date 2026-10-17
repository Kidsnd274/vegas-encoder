import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../app/launch.dart';
import 'app_state.dart';

export 'package:ve_services/ve_services.dart' show DesktopAppLauncher;

// The app's only ways into the core (C2) and the system (C3). The core is the
// real C++ core (B2); the services are the platform's Windows services (B3),
// composed once in [servicesProvider]. Tests override that with the platform's
// fakes. Nothing in the app implements compile, validate, lint, completion,
// estimates or diffs itself (TECH_ARCHITECTURE T1).

/// The product core through `dart:ffi`, one per isolate; ve_core's build hook
/// bundles its DLL. If it can't load, [UnavailableCore] carries why, and
/// nothing falls back to the fake core.
VeCore loadCore() {
  try {
    return NativeVeCore();
  } on CoreException catch (e) {
    return UnavailableCore(e);
  }
}

final veCoreProvider = Provider<VeCore>((ref) => loadCore());

/// Why the core couldn't load, or null when it did.
final coreLoadErrorProvider = Provider<CoreException?>(
  (ref) => switch (ref.watch(veCoreProvider)) {
    UnavailableCore(:final error) => error,
    _ => null,
  },
);

/// The core that didn't load (a missing or mismatched DLL). Every call throws
/// the load failure, so results stay explicit failures; the desktop window
/// shows it in place of the screens that need the core.
final class UnavailableCore implements VeCore {
  const UnavailableCore(this.error);
  final CoreException error;

  @override
  CoreVersion get version => throw error;
  @override
  ProfileCatalog profiles() => throw error;
  @override
  NormalizeResult normalize(Map<String, Object?> json) => throw error;
  @override
  List<Issue> validate(Recipe recipe, {MediaDescription? media, CoreCapabilities? capabilities}) => throw error;
  @override
  CompileResult compile(
    Recipe recipe, {
    required MediaDescription media,
    required CompilePaths paths,
    CoreCapabilities? capabilities,
  }) => throw error;
  @override
  List<Diagnostic> lint(String text, {CoreCapabilities? capabilities}) => throw error;
  @override
  CompletionResult complete(String text, int caret, {CoreCapabilities? capabilities}) => throw error;
  @override
  SizeEstimate estimate(Recipe recipe, {required MediaDescription media, double? durationSec}) => throw error;
  @override
  List<FieldDiff> diff(Recipe before, Recipe after) => throw error;
  @override
  Uint8List encodePayload(TemplateSnapshot snapshot) => throw error;
  @override
  PayloadResult decodePayload(Uint8List bytes) => throw error;
}

// ------------------------------------------------------------ services (C3)

/// The system services the app uses, from one place so tests swap them all
/// together (`servicesOverride` in test/helpers.dart). Screens reach them
/// through the providers below, never through this directly.
abstract interface class AppServices {
  PresetLibrary get library;
  MachineSettingsRepository get machineSettings;
  FFmpegDiscovery get discovery;
  FFmpegProbe get probe;
  HardwareTests get hardwareTests;
  CapabilityCache get capabilityCache;

  /// "Test this preset": a short synthetic encode with an installation.
  PresetTests get presetTests;
  JobRepository get jobs;

  /// A job's full FFmpeg log (C6 `logFile`).
  JobLogs get jobLogs;
  LiveRenderStatusReader get liveStatus;
  EditSessionService get editSessions;

  /// Shows a file or folder in Explorer.
  FileReveal get fileReveal;

  /// Where the services keep their files, for Settings > About; null for
  /// the fakes, which keep nothing.
  ServicePaths? get paths;

  Future<void> dispose();
}

/// The platform's Windows services (CONTRACTS C3, `WindowsServices`). Built
/// on first use, so the progress window, which reads only its live file and
/// keep on top while VEGAS renders, loads neither the core nor the library
/// then. Constructing them scans nothing and writes nothing.
final class WindowsAppServices implements AppServices {
  /// [core] gives the process's core when the services are first used.
  WindowsAppServices(this._core, {ServicePaths? paths}) : _paths = paths ?? ServicePaths.windows();

  final VeCore Function() _core;
  final ServicePaths _paths;
  late final WindowsServices _windows = WindowsServices(core: _core(), paths: _paths);

  @override
  ServicePaths get paths => _paths;
  @override
  PresetLibrary get library => _windows.library;

  /// The settings file on its own, without the core, so the progress window
  /// can read keep on top (C7). Discovery writes through the copy inside
  /// [WindowsServices]; both use the same file, lock and revision check.
  @override
  late final MachineSettingsRepository machineSettings = FileMachineSettingsRepository(paths: _paths);
  @override
  FFmpegDiscovery get discovery => _windows.discovery;
  @override
  FFmpegProbe get probe => _windows.probe;
  @override
  HardwareTests get hardwareTests => _windows.hardwareTests;
  @override
  CapabilityCache get capabilityCache => _windows.capabilityCache;
  @override
  PresetTests get presetTests => _windows.presetTests;
  @override
  JobRepository get jobs => _windows.jobs;
  @override
  JobLogs get jobLogs => _windows.jobs;
  @override
  late final LiveRenderStatusReader liveStatus = FileLiveRenderStatusReader();
  @override
  late final FileReveal fileReveal = WindowsFileReveal();

  /// Needs the native core: a core that didn't load makes this throw
  /// `CORE-CONTRACT`, which the popup shows like any unreadable session.
  @override
  late final EditSessionService editSessions = _windows.editSessions;

  @override
  Future<void> dispose() async {}
}

/// `VEGAS_ENCODER_DATA_ROOT=<folder>` keeps settings, library, cache and jobs
/// under `<folder>\Roaming` and `<folder>\Local` instead of the user's
/// `%APPDATA%` and `%LOCALAPPDATA%`. For development, spikes and fake-host
/// runs only; the VEGAS exporter doesn't read it.
ServicePaths? dataRootOverride() {
  final root = Platform.environment['VEGAS_ENCODER_DATA_ROOT'];
  if (root == null || root.trim().isEmpty) return null;
  return ServicePaths(roaming: '$root\\Roaming', local: '$root\\Local');
}

/// The services for this process. Under `flutter test` this refuses to build
/// the real ones: a test that forgot its fakes would otherwise read and write
/// the user's library and settings.
final servicesProvider = Provider<AppServices>((ref) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    throw StateError('Tests use fake services: add servicesOverride() from test/helpers.dart.');
  }
  final services = WindowsAppServices(() => ref.read(veCoreProvider), paths: dataRootOverride());
  ref.onDispose(services.dispose);
  return services;
});

final presetLibraryProvider = Provider<PresetLibrary>((ref) => ref.watch(servicesProvider).library);

/// Stars and pins, built-ins included (C3 `PresetPreferences`). The library
/// implements it, real and fake alike.
final presetPreferencesProvider = Provider<PresetPreferences>(
  (ref) => ref.watch(presetLibraryProvider) as PresetPreferences,
);

/// Duplicates and History copies with their C3 origins; export, share
/// strings and import.
final presetTransferProvider = Provider<PresetTransfer>((ref) => PresetTransfer(ref.watch(presetLibraryProvider)));

/// Where a preset's file is, for Show in folder (C3 `PresetLocations`; null
/// for a built-in). The library implements it, real and fake alike.
final presetLocationsProvider = Provider<PresetLocations>((ref) => ref.watch(presetLibraryProvider) as PresetLocations);

/// "Test this preset" (UI_SPEC §2): FFmpeg encodes synthetic frames with the
/// preset, then the output is checked as a render's is.
final presetTestsProvider = Provider<PresetTests>((ref) => ref.watch(servicesProvider).presetTests);

/// The machine settings store (C7).
final machineSettingsRepositoryProvider = Provider<MachineSettingsRepository>(
  (ref) => ref.watch(servicesProvider).machineSettings,
);

final ffmpegProbeProvider = Provider<FFmpegProbe>((ref) => ref.watch(servicesProvider).probe);

final capabilityCacheProvider = Provider<CapabilityCache>((ref) => ref.watch(servicesProvider).capabilityCache);

/// Finds FFmpeg installations (PATH, winget, Scoop, Chocolatey, added by hand)
/// and records them in machine settings itself (C7 ownership, B3).
final ffmpegDiscoveryProvider = Provider<FFmpegDiscovery>((ref) => ref.watch(servicesProvider).discovery);

/// Test encodes for hardware encoders on this PC.
final hardwareTestsProvider = Provider<HardwareTests>((ref) => ref.watch(servicesProvider).hardwareTests);

/// Render records (C6), for History.
final jobRepositoryProvider = Provider<JobRepository>((ref) => ref.watch(servicesProvider).jobs);

/// Full FFmpeg logs (C6), by job.
final jobLogsProvider = Provider<JobLogs>((ref) => ref.watch(servicesProvider).jobLogs);

/// Shows a file in Explorer (the progress window's Open folder).
final fileRevealProvider = Provider<FileReveal>((ref) => ref.watch(servicesProvider).fileReveal);

/// The render's live status file (C5), for the progress window.
final liveStatusReaderProvider = Provider<LiveRenderStatusReader>((ref) => ref.watch(servicesProvider).liveStatus);

/// The popup's request and result files (C4).
final editSessionServiceProvider = Provider<EditSessionService>((ref) => ref.watch(servicesProvider).editSessions);

/// Starts the desktop app on a preset ("Open in Vegas Encoder", UI_SPEC §4)
/// or on a job in History (the progress window's "Show in History", §12).
/// Kept separate from WindowsServices so a monitor can launch the desktop
/// without loading the core or library. Widget tests explicitly inject a fake.
final desktopAppLauncherProvider = Provider<DesktopAppLauncher?>(
  (ref) => Platform.environment.containsKey('FLUTTER_TEST') ? null : WindowsDesktopAppLauncher(),
);

/// The installations discovery knows about, kept current.
final discoveredInstallationsProvider = StreamProvider<List<FFmpegInstallation>>(
  (ref) => ref.watch(ffmpegDiscoveryProvider).watch(),
);

/// The job index (C6 `jobs.jsonl`), kept current.
final jobsProvider = StreamProvider<List<JobIndexEntry>>((ref) => ref.watch(jobRepositoryProvider).watch());

/// One job's full record; null if the record is gone.
final jobRecordProvider = FutureProvider.family<JobRecord?, String>(
  (ref, id) => ref.watch(jobRepositoryProvider).get(id),
);

/// The profile catalog: encoders, their controls, containers and the
/// codec-to-container table, all as the core reports them.
final profilesProvider = Provider<ProfileCatalog>((ref) => ref.watch(veCoreProvider).profiles());

/// Every preset in the library, kept current.
final presetsProvider = StreamProvider<List<Preset>>((ref) => ref.watch(presetLibraryProvider).watch());

/// C7 machine settings, kept current.
final machineSettingsProvider = StreamProvider<MachineSettings>(
  (ref) => ref.watch(machineSettingsRepositoryProvider).watch(),
);

/// What an installation can do, from the capability cache the probe writes.
/// On the desktop an installation that was never checked is probed once (the
/// probe caches its own result); the popup only reads the cache. Null while
/// that is unknown, so checks fall back to the core's defaults. Callers take
/// a recipe's view with `toCoreCapabilities(recipe: …)` (C3), which keeps
/// Basic compiles small.
final capabilitiesProvider = FutureProvider.family<FFmpegCapabilities?, String>((ref, installationId) async {
  FFmpegInstallation? find(MachineSettings s) => s.installations.where((i) => i.id == installationId).firstOrNull;
  // Only this installation's identity matters; other settings writes (the
  // remembered length, window bounds) don't re-read the cache.
  final key = await ref.watch(machineSettingsProvider.selectAsync((s) => find(s)?.identity.key));
  if (key == null) return null;
  final cached = await ref.watch(capabilityCacheProvider).read(key);
  if (cached != null || ref.watch(launchModeProvider) is! DesktopLaunch) return cached;
  final installation = find(await ref.read(machineSettingsProvider.future));
  if (installation == null) return null;
  FFmpegCapabilities? found;
  await for (final progress in ref.watch(ffmpegProbeProvider).probe(installation)) {
    if (progress.capabilities != null) found = progress.capabilities;
  }
  return found;
});

/// [capabilities] as the core takes them for [recipe] (C3's reusable view):
/// Basic keeps every encoder's name and availability and the full options of
/// the recipe's own encoders; Advanced keeps everything.
CoreCapabilities? capabilitiesFor(FFmpegCapabilities? capabilities, Recipe recipe, {String label = ''}) =>
    capabilities?.toCoreCapabilities(label: label, recipe: recipe);
