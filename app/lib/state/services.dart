import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

// The app's only ways into the core (C2) and the system (C3). Each defaults to
// the platform fake until the real core (B2) and services (B3) land; tests
// override them. Nothing in the app implements compile, validate, lint,
// completion, estimates or diffs itself (TECH_ARCHITECTURE T1).

final veCoreProvider = Provider<VeCore>((ref) => FakeVeCore());

final presetLibraryProvider = Provider<PresetLibrary>((ref) {
  final library = FakePresetLibrary();
  ref.onDispose(library.dispose);
  return library;
});

/// The machine settings store (C7). `main` reads it before the first frame
/// (the remembered window bounds) and hands the same instance to the app.
MachineSettingsRepository createMachineSettingsRepository() => FakeMachineSettingsRepository();

final machineSettingsRepositoryProvider = Provider<MachineSettingsRepository>((ref) {
  final repository = createMachineSettingsRepository();
  if (repository is FakeMachineSettingsRepository) ref.onDispose(repository.dispose);
  return repository;
});

final ffmpegProbeProvider = Provider<FFmpegProbe>((ref) => FakeFFmpegProbe());

final capabilityCacheProvider = Provider<CapabilityCache>((ref) => FakeCapabilityCache());

/// Finds FFmpeg installations (PATH, winget, Scoop, Chocolatey, added by hand).
final ffmpegDiscoveryProvider = Provider<FFmpegDiscovery>((ref) {
  final discovery = FakeFFmpegDiscovery();
  ref.onDispose(discovery.dispose);
  return discovery;
});

/// Test encodes for hardware encoders on this PC.
final hardwareTestsProvider = Provider<HardwareTests>((ref) => FakeHardwareTests());

/// Render records (C6), for History.
final jobRepositoryProvider = Provider<JobRepository>((ref) {
  final jobs = FakeJobRepository();
  ref.onDispose(jobs.dispose);
  return jobs;
});

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

/// What an installation can do, for the core's capability-specific checks.
/// Reads the cache; an installation that was never checked is probed once.
/// Null while that is unknown, so checks fall back to the core's defaults.
final capabilitiesProvider = FutureProvider.family<CoreCapabilities?, String>((ref, installationId) async {
  final settings = await ref.watch(machineSettingsProvider.future);
  final installation = settings.installations.where((i) => i.id == installationId).firstOrNull;
  if (installation == null) return null;
  final cache = ref.watch(capabilityCacheProvider);
  var capabilities = await cache.read(installation.identity.key);
  if (capabilities == null) {
    await for (final progress in ref.watch(ffmpegProbeProvider).probe(installation)) {
      if (progress.capabilities != null) capabilities = progress.capabilities;
    }
    if (capabilities != null) await cache.write(capabilities);
  }
  return capabilities?.toCoreCapabilities(label: installation.label);
});
