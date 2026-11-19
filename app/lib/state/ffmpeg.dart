import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import 'services.dart';
import 'settings.dart';

enum EncoderKind { video, audio }

/// Which encoders the capability list shows (UI_SPEC §5).
enum CapabilityFilter { all, problems, hardware }

/// The FFmpeg screen's own state. Installations come from discovery
/// ([discoveredInstallationsProvider]); the default from machine settings.
@immutable
class FFmpegState {
  const FFmpegState({
    this.selectedId,
    this.kind = EncoderKind.video,
    this.filter = CapabilityFilter.all,
    this.query = '',
    this.selectedEncoder,
    this.probes = const {},
    this.probeFailures = const {},
    this.probed = const {},
    this.testing = const {},
    this.testResults = const {},
    this.scanning = false,
  });

  /// The installation shown below the cards; null is the default one.
  final String? selectedId;
  final EncoderKind kind;
  final CapabilityFilter filter;
  final String query;

  /// The encoder whose details show at the right; null is the list's first.
  final String? selectedEncoder;

  /// The latest progress of each probe still running, by installation.
  final Map<String, ProbeProgress> probes;

  /// Why a probe this session failed or was cancelled, by installation.
  final Map<String, String> probeFailures;

  /// What each probe this session found, by installation.
  final Map<String, FFmpegCapabilities> probed;

  /// Hardware encoders being test-encoded now, by installation.
  final Map<String, Set<String>> testing;

  /// Test results from this session, by installation, then encoder.
  final Map<String, Map<String, HardwareTestResult>> testResults;

  /// Scan again is running.
  final bool scanning;

  FFmpegState copyWith({
    Object? selectedId = _keep,
    EncoderKind? kind,
    CapabilityFilter? filter,
    String? query,
    Object? selectedEncoder = _keep,
    Map<String, ProbeProgress>? probes,
    Map<String, String>? probeFailures,
    Map<String, FFmpegCapabilities>? probed,
    Map<String, Set<String>>? testing,
    Map<String, Map<String, HardwareTestResult>>? testResults,
    bool? scanning,
  }) => FFmpegState(
    selectedId: identical(selectedId, _keep) ? this.selectedId : selectedId as String?,
    kind: kind ?? this.kind,
    filter: filter ?? this.filter,
    query: query ?? this.query,
    selectedEncoder: identical(selectedEncoder, _keep) ? this.selectedEncoder : selectedEncoder as String?,
    probes: probes ?? this.probes,
    probeFailures: probeFailures ?? this.probeFailures,
    probed: probed ?? this.probed,
    testing: testing ?? this.testing,
    testResults: testResults ?? this.testResults,
    scanning: scanning ?? this.scanning,
  );

  bool isTesting(String installationId, String encoder) => testing[installationId]?.contains(encoder) ?? false;
}

const Object _keep = Object();

final ffmpegControllerProvider = NotifierProvider<FFmpegController, FFmpegState>(FFmpegController.new);

/// Scan again, Add FFmpeg…, Remove, Set as default, probes and hardware tests.
/// Discovery finds installations and records them in machine settings (C7)
/// itself; probes and hardware tests keep their own results (cache and C7).
/// The app writes only the default. Nothing here works out what an encoder
/// can do: probes and tests are the services' results.
class FFmpegController extends Notifier<FFmpegState> {
  @override
  FFmpegState build() {
    final probes = ref.watch(ffmpegProbeProvider);
    final tests = ref.watch(hardwareTestsProvider);
    ref.onDispose(() {
      // Stop work this screen started; results would have nowhere to go.
      for (final id in _checks.keys) {
        probes.cancel(id);
      }
      for (final id in _testing) {
        tests.cancel(id);
      }
    });
    return const FFmpegState();
  }

  // Running work by installation, for cancelling on dispose (ref and state
  // can't be used while disposing). One check per installation at a time:
  // asking again returns the running one.
  final Map<String, Future<void>> _checks = {};
  final Set<String> _testing = {};

  // capabilitiesProvider instances waiting on a check, which read the result
  // themselves: invalidating one mid-load would leave its future unfinished.
  final Map<String, int> _awaited = {};

  /// [probe] for `capabilitiesProvider`, which reads the result itself.
  Future<void> probeFor(FFmpegInstallation installation) async {
    final id = installation.id;
    _awaited[id] = (_awaited[id] ?? 0) + 1;
    try {
      await probe(installation);
    } finally {
      if ((_awaited[id] = _awaited[id]! - 1) == 0) _awaited.remove(id);
    }
  }

  FFmpegDiscovery get _discovery => ref.read(ffmpegDiscoveryProvider);

  void select(String id) {
    _selections++;
    state = state.copyWith(selectedId: id, selectedEncoder: null);
  }

  /// Counts selections, so [add] never overrides a card chosen while it ran (C1).
  int _selections = 0;
  void setKind(EncoderKind kind) => state = state.copyWith(kind: kind, selectedEncoder: null);
  void setFilter(CapabilityFilter filter) => state = state.copyWith(filter: filter);
  void setQuery(String query) => state = state.copyWith(query: query);
  void selectEncoder(String id) => state = state.copyWith(selectedEncoder: id);

  /// Looks for installations again (discovery records them) and checks each
  /// one that has no cached capabilities. Returns what was found; [onFound]
  /// hears it before the checks start (the setup wizard moves on then).
  Future<List<FFmpegInstallation>> scan({ValueChanged<List<FFmpegInstallation>>? onFound}) async {
    state = state.copyWith(scanning: true);
    try {
      final found = await _discovery.scan();
      if (!ref.mounted) return found;
      onFound?.call(found);
      final cache = ref.read(capabilityCacheProvider);
      for (final installation in found) {
        if (!ref.mounted) break;
        if (await cache.read(installation.identity.key) == null) await probe(installation);
      }
      return found;
    } finally {
      if (ref.mounted) state = state.copyWith(scanning: false);
    }
  }

  /// Adds the FFmpeg at [executablePath] (from the Open dialog; discovery
  /// records it), checks it and shows it. Discovery's failure (not FFmpeg, no
  /// ffprobe beside it…) reaches the caller as a [ServiceException].
  Future<FFmpegInstallation> add(String executablePath) async {
    final before = _selections;
    final installation = await _discovery.add(executablePath);
    if (!ref.mounted) return installation;
    // Show the new card only if the user hasn't picked another meanwhile.
    if (_selections == before) select(installation.id);
    await probe(installation);
    return installation;
  }

  /// Forgets an installation, first stopping its check and hardware tests.
  /// The files stay where they are. The default can't be removed: renders
  /// would have no FFmpeg (choose another first).
  Future<void> remove(String id) async {
    final settings = await ref.read(machineSettingsRepositoryProvider).read();
    if (settings.defaultFFmpegId == id) {
      throw const ServiceException('DEFAULT-IN-USE', 'Choose another default FFmpeg before removing this one.');
    }
    await ref.read(ffmpegProbeProvider).cancel(id);
    await ref.read(hardwareTestsProvider).cancel(id);
    await _discovery.remove(id);
    // A check still ending writes nothing for an installation that is gone.
    _checks.remove(id);
    if (!ref.mounted) return;
    Map<String, V> without<V>(Map<String, V> m) => Map.of(m)..remove(id);
    state = state.copyWith(
      selectedId: state.selectedId == id ? null : state.selectedId,
      selectedEncoder: state.selectedId == id ? null : state.selectedEncoder,
      probes: without(state.probes),
      probeFailures: without(state.probeFailures),
      probed: without(state.probed),
      testing: without(state.testing),
      testResults: without(state.testResults),
    );
  }

  /// Makes [installation] the FFmpeg every render uses (C7 defaultFFmpegId).
  /// Discovery has already recorded the installation itself.
  Future<void> setDefault(FFmpegInstallation installation) async {
    await ref.read(machineSettingsWriterProvider).update((s) => s.copyWith(defaultFFmpegId: installation.id));
  }

  /// Reads what [installation] can do, showing progress as it streams in.
  /// The probe caches its own result; the editor's checks then read it.
  /// While a check of [installation] runs, this returns that one instead of
  /// starting another (two would hash and test-encode the same files twice).
  Future<void> probe(FFmpegInstallation installation) {
    final id = installation.id;
    if (_checks[id] case final running?) return running;
    final done = Completer<void>();
    final check = done.future;
    _checks[id] = check;
    () async {
      try {
        await _check(installation, current: () => identical(_checks[id], check));
        done.complete();
      } catch (e, stack) {
        done.completeError(e, stack);
      } finally {
        if (identical(_checks[id], check)) _checks.remove(id);
      }
    }();
    return check;
  }

  /// One check; [current] turns false once the installation is removed.
  Future<void> _check(FFmpegInstallation installation, {required bool Function() current}) async {
    final id = installation.id;
    state = state.copyWith(
      probes: {
        ...state.probes,
        id: ProbeProgress(installationId: id, phase: 'identity', completed: 0, total: 0),
      },
      probeFailures: Map.of(state.probeFailures)..remove(id),
    );
    FFmpegCapabilities? found;
    String? failure;
    try {
      await for (final progress in ref.read(ffmpegProbeProvider).probe(installation)) {
        if (!ref.mounted || !current()) return;
        if (progress.capabilities != null) found = progress.capabilities;
        if (progress.phase == 'failed' || progress.phase == 'cancelled') {
          failure = progress.message.isEmpty ? 'The check stopped (${progress.phase}).' : progress.message;
        }
        state = state.copyWith(probes: {...state.probes, id: progress});
      }
    } on ServiceException catch (e) {
      failure = e.message;
    }
    if (!ref.mounted || !current()) return;
    if (found != null && !_awaited.containsKey(id)) ref.invalidate(capabilitiesProvider(id));
    state = state.copyWith(
      probes: Map.of(state.probes)..remove(id),
      probed: found == null ? null : {...state.probed, id: found},
      probeFailures: failure == null ? null : {...state.probeFailures, id: failure},
    );
  }

  /// Test-encodes [encoders] on this PC (all of [hardwareEncoders] when
  /// null), even if they were tested before. Results stream into the list.
  /// Refused while [installation] is being checked: the check tests them.
  Future<void> testHardware(
    FFmpegInstallation installation, {
    required Iterable<String> hardwareEncoders,
    List<String>? encoders,
  }) async {
    final id = installation.id;
    if (_checks.containsKey(id)) {
      throw ServiceException('CHECK-RUNNING', 'Wait until the check of ${installation.label} finishes.');
    }
    final names = {...encoders ?? hardwareEncoders};
    state = state.copyWith(
      testing: {
        ...state.testing,
        id: {...?state.testing[id], ...names},
      },
    );
    _testing.add(id);
    try {
      await for (final result in ref.read(hardwareTestsProvider).test(installation, encoders: encoders, force: true)) {
        if (!ref.mounted) return;
        state = state.copyWith(
          testResults: {
            ...state.testResults,
            id: {...?state.testResults[id], result.encoder: result},
          },
          testing: {
            ...state.testing,
            id: {...?state.testing[id]}..remove(result.encoder),
          },
        );
      }
    } finally {
      _testing.remove(id);
      if (ref.mounted) {
        final left = {...?state.testing[id]}..removeAll(names);
        state = state.copyWith(testing: {...state.testing, id: left}..removeWhere((_, v) => v.isEmpty));
        // The tests keep their results; the editor's checks read them again.
        ref.invalidate(capabilitiesProvider(id));
      }
    }
  }
}
