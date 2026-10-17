import 'dart:async';
import 'dart:convert';
import 'package:ve_core/ve_core.dart';
import 'api.dart';
import 'models.dart';
import 'storage_validation.dart' show validatePopupSize, validateLiveVideoFacts;
import 'service_fixture_data.dart';

/// Each listen gets the latest value then later updates. Subscribe before the
/// initial snapshot, so a same-turn mutation cannot be lost. No timers or files.
class _Store<T> {
  _Store(this.value);
  T value;
  final _changes = StreamController<T>.broadcast();
  Stream<T> watch() => Stream<T>.multi((controller) {
    final subscription = _changes.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.add(value);
    controller.onCancel = subscription.cancel;
  });
  void set(T next) {
    value = next;
    _changes.add(next);
  }

  Future<void> dispose() => _changes.close();
}

const _fixtureTime = '2026-10-12T01:12:00Z';
List<FFmpegInstallation> _installations() => jsonMaps(
  b0Fixtures()['installations'],
).map(FFmpegInstallation.fromJson).toList();
FFmpegCapabilities _capabilities(FFmpegInstallation installation) {
  final details = jsonMap(b0Fixtures()['details']);
  return FFmpegCapabilities(
    installationId: installation.id,
    identityKey: installation.identity.key,
    version: installation.version,
    probedAt: installation.probedAt ?? _fixtureTime,
    gpuFingerprint: 'b0-fixture-rtx4070',
    encoders: {
      for (final entry in installation.availability.entries)
        entry.key: {
          ...jsonMap(
            details[entry.key] ?? {'name': entry.key, 'kind': 'video'},
          ),
          'availability': entry.value,
        },
    },
    muxers: {
      for (final c in jsonMaps(jsonMap(b0Fixtures()['profiles'])['containers']))
        c['muxer'] as String: c,
    },
    hardware: {
      for (final entry in installation.availability.entries)
        if (RegExp(r'_(nvenc|qsv|amf)$').hasMatch(entry.key))
          entry.key: entry.value,
    },
  );
}

class FakeFFmpegDiscovery implements FFmpegDiscovery {
  FakeFFmpegDiscovery({
    List<FFmpegInstallation>? installations,
    List<FFmpegInstallation>? scanResults,
    Map<String, FFmpegInstallation> additions = const {},
  }) : _store = _Store(List.unmodifiable(installations ?? _installations())),
       _scanResults = scanResults == null
           ? null
           : List.unmodifiable(scanResults),
       _additions = Map.unmodifiable(additions);
  final _Store<List<FFmpegInstallation>> _store;
  final List<FFmpegInstallation>? _scanResults;
  final Map<String, FFmpegInstallation> _additions;
  @override
  Future<List<FFmpegInstallation>> list() async => _store.value;
  @override
  Stream<List<FFmpegInstallation>> watch() => _store.watch();
  @override
  Future<List<FFmpegInstallation>> scan() async {
    if (_scanResults != null) _store.set(_scanResults);
    return _store.value;
  }

  @override
  Future<FFmpegInstallation> add(String executablePath) async {
    final installation = _additions[executablePath];
    if (installation == null)
      throw const ServiceException(
        'B0-FIXTURE-MISSING',
        'Inject this executable as an addition fixture.',
      );
    if (!_store.value.any((v) => v.id == installation.id))
      _store.set(List.unmodifiable([..._store.value, installation]));
    return installation;
  }

  @override
  Future<void> remove(String installationId) async => _store.set(
    List.unmodifiable(_store.value.where((v) => v.id != installationId)),
  );
  Future<void> dispose() => _store.dispose();
}

class FakeFFmpegProbe implements FFmpegProbe {
  FakeFFmpegProbe({
    Map<String, List<ProbeProgress>> progress = const {},
    Map<String, EncoderDetails>? details,
  }) : _progress = progress.map(
         (k, v) => MapEntry(k, List<ProbeProgress>.unmodifiable(v)),
       ),
       _details =
           details ??
           jsonMap(
             b0Fixtures()['details'],
           ).map((k, v) => MapEntry(k, EncoderDetails.fromJson(jsonMap(v))));
  final Map<String, List<ProbeProgress>> _progress;
  final Map<String, EncoderDetails> _details;
  final Map<String, int> _generation = {};
  @override
  Stream<ProbeProgress> probe(FFmpegInstallation installation) async* {
    final generation = (_generation[installation.id] ?? 0) + 1;
    _generation[installation.id] = generation;
    final events =
        _progress[installation.id] ??
        [
          ProbeProgress(
            installationId: installation.id,
            phase: 'identity',
            completed: 1,
            total: 3,
            message: 'Fixture identity loaded',
          ),
          ProbeProgress(
            installationId: installation.id,
            phase: 'lists',
            completed: 2,
            total: 3,
            message: 'Fixture encoder and muxer lists loaded',
          ),
          ProbeProgress(
            installationId: installation.id,
            phase: 'done',
            completed: 3,
            total: 3,
            capabilities: _capabilities(installation),
          ),
        ];
    for (final event in events) {
      await Future<void>.value();
      if (_generation[installation.id] != generation) return;
      yield event;
    }
  }

  @override
  Future<EncoderDetails> encoderDetails(
    FFmpegInstallation installation,
    String encoder,
  ) async {
    final details = _details[encoder];
    if (details == null)
      throw const ServiceException(
        'B0-FIXTURE-MISSING',
        'No encoder help fixture.',
      );
    return details;
  }

  @override
  Future<void> cancel(String installationId) async {
    _generation[installationId] = (_generation[installationId] ?? 0) + 1;
  }
}

class FakeFFmpegHelpParser implements FFmpegHelpParser {
  FakeFFmpegHelpParser({
    this.version = 1,
    Map<String, EncoderDetails> encoderHelp = const {},
    Map<String, JsonMap> encoders = const {},
    Map<String, JsonMap> muxers = const {},
  }) : _help = Map.unmodifiable(encoderHelp),
       _encoders = Map.unmodifiable(encoders),
       _muxers = Map.unmodifiable(muxers);
  @override
  final int version;
  final Map<String, EncoderDetails> _help;
  final Map<String, JsonMap> _encoders, _muxers;
  @override
  EncoderDetails parseEncoderHelp(String text) =>
      _help[text] ??
      (throw const ServiceException(
        'B0-FIXTURE-MISSING',
        'Inject help text and parsed output.',
      ));
  @override
  JsonMap parseEncoders(String text) => jsonMap(
    jsonDecode(
      jsonEncode(
        _encoders[text] ??
            (throw const ServiceException(
              'B0-FIXTURE-MISSING',
              'No encoder-list fixture.',
            )),
      ),
    ),
  );
  @override
  JsonMap parseMuxers(String text) => jsonMap(
    jsonDecode(
      jsonEncode(
        _muxers[text] ??
            (throw const ServiceException(
              'B0-FIXTURE-MISSING',
              'No muxer-list fixture.',
            )),
      ),
    ),
  );
}

class FakeHardwareTests implements HardwareTests {
  FakeHardwareTests({Map<String, List<HardwareTestResult>> results = const {}})
    : _results = results.map(
        (k, v) => MapEntry(k, List<HardwareTestResult>.unmodifiable(v)),
      );
  final Map<String, List<HardwareTestResult>> _results;
  final Map<String, int> _generation = {};
  @override
  Stream<HardwareTestResult> test(
    FFmpegInstallation installation, {
    List<String>? encoders,
    bool force = false,
  }) async* {
    final generation = (_generation[installation.id] ?? 0) + 1;
    _generation[installation.id] = generation;
    final results =
        _results[installation.id] ??
        installation.availability.entries
            .where((e) => RegExp(r'_(nvenc|qsv|amf)$').hasMatch(e.key))
            .map((e) {
              final availability = EncoderAvailability.fromJson(
                jsonMap(e.value),
              );
              return HardwareTestResult(
                encoder: e.key,
                state: availability.state,
                tenBit:
                    ['hevc_nvenc', 'av1_nvenc'].contains(e.key) &&
                    availability.state == 'ok',
                failureClass: availability.state == 'failed'
                    ? (e.key.endsWith('qsv') ? 'no-device' : 'runtime-missing')
                    : null,
                reason: availability.reason,
                stderr: availability.detail,
                testedAt: _fixtureTime,
                identityKey: installation.identity.key,
                gpuFingerprint: 'b0-fixture-rtx4070',
              );
            });
    for (final result in results) {
      await Future<void>.value();
      if (_generation[installation.id] != generation) return;
      if (encoders == null || encoders.contains(result.encoder)) yield result;
    }
  }

  @override
  Future<void> cancel(String installationId) async {
    _generation[installationId] = (_generation[installationId] ?? 0) + 1;
  }
}

class FakeCapabilityCache implements CapabilityCache {
  FakeCapabilityCache({List<FFmpegCapabilities> capabilities = const []})
    : _values = {for (final c in capabilities) c.identityKey: c};
  final Map<String, FFmpegCapabilities> _values;
  @override
  Future<FFmpegCapabilities?> read(String identityKey) async =>
      _values[identityKey];
  @override
  Future<void> write(FFmpegCapabilities capabilities) async {
    _values[capabilities.identityKey] = capabilities;
  }

  @override
  Future<void> invalidate(String identityKey) async {
    _values.remove(identityKey);
  }
}

class FakePresetLibrary
    implements PresetLibrary, PresetPreferences, PresetLocations {
  FakePresetLibrary({List<Preset>? presets, String Function()? now})
    : _store = _Store(
        List.unmodifiable(
          presets ??
              jsonMaps(
                b0Fixtures()['fixtures'],
              ).map((f) => Preset.fromJson(jsonMap(f['preset']))),
        ),
      ),
      _now = now ?? (() => _fixtureTime);
  final _Store<List<Preset>> _store;
  final String Function() _now;
  final Map<String, List<Preset>> _history = {};
  @override
  Future<List<Preset>> list() async => _store.value;
  @override
  Stream<List<Preset>> watch() => _store.watch();
  @override
  Future<Preset?> get(String id, {int? revision}) async {
    for (final preset in [
      ..._store.value,
      if (revision != null) ...?_history[id],
    ]) {
      if (preset.recipe.id == id &&
          (revision == null || preset.revision == revision))
        return preset;
    }
    return null;
  }

  @override
  Future<Preset> save(Preset preset, {int? expectedRevision}) async {
    // No await between compare and replace: concurrent fake writes are atomic.
    final existing = _store.value
        .where((v) => v.recipe.id == preset.recipe.id)
        .firstOrNull;
    if (existing?.builtin == true || preset.builtin)
      throw const ServiceException(
        'READ-ONLY',
        'Duplicate a built-in preset before saving.',
      );
    if (existing == null
        ? expectedRevision != null
        : existing.revision != expectedRevision)
      throw const ServiceException(
        'REVISION-CONFLICT',
        'Updated elsewhere: reload or save as new.',
      );
    if (existing != null) {
      final history = _history.putIfAbsent(preset.recipe.id, () => []);
      history.add(existing);
      if (history.length > 20) history.removeAt(0);
    }
    final saved = preset.copyWith(
      revision: (existing?.revision ?? 0) + 1,
      updatedAt: _now(),
    );
    _store.set(
      List.unmodifiable([
        ..._store.value.where((v) => v.recipe.id != saved.recipe.id),
        saved,
      ]),
    );
    return saved;
  }

  @override
  Future<void> delete(String id, {required int expectedRevision}) async {
    final existing = _store.value.where((v) => v.recipe.id == id).firstOrNull;
    if (existing == null)
      throw const ServiceException('NOT-FOUND', 'Preset not found.');
    if (existing.builtin)
      throw const ServiceException(
        'READ-ONLY',
        'Built-in presets cannot be deleted.',
      );
    if (existing.revision != expectedRevision)
      throw const ServiceException(
        'REVISION-CONFLICT',
        'Updated elsewhere: reload first.',
      );
    _store.set(List.unmodifiable(_store.value.where((v) => v.recipe.id != id)));
  }

  @override
  Future<Preset> importPreset(String jsonText, {required String newId}) async {
    final imported = Preset.fromJson(jsonMap(jsonDecode(jsonText)));
    return save(
      imported.copyWith(
        recipe: imported.recipe.copyWith(id: newId),
        builtin: false,
        origin: imported.builtin
            ? 'builtin/${imported.recipe.id}'
            : imported.origin,
      ),
    );
  }

  @override
  Future<String> exportPreset(String id) async {
    final preset = await get(id);
    if (preset == null)
      throw const ServiceException('NOT-FOUND', 'Preset not found.');
    return jsonEncode(preset.toJson());
  }

  @override
  Future<String?> location(String id) async {
    final preset = await get(id);
    return preset == null || preset.builtin
        ? null
        : 'fixture-library/$id.vepreset';
  }

  @override
  Future<Preset> setPreferences(
    String id, {
    bool? favorite,
    bool? pinned,
  }) async {
    final current = _store.value.where((p) => p.recipe.id == id).firstOrNull;
    if (current == null)
      throw const ServiceException('NOT-FOUND', 'Preset not found.');
    if (!current.builtin) {
      return save(
        current.copyWith(
          favorite: favorite ?? current.favorite,
          pinned: pinned ?? current.pinned,
        ),
        expectedRevision: current.revision,
      );
    }
    final saved = current.copyWith(
      favorite: favorite ?? current.favorite,
      pinned: pinned ?? current.pinned,
    );
    _store.set(
      List.unmodifiable(_store.value.map((p) => p.recipe.id == id ? saved : p)),
    );
    return saved;
  }

  Future<void> dispose() => _store.dispose();
}

class FakeMachineSettingsRepository implements MachineSettingsRepository {
  FakeMachineSettingsRepository({MachineSettings? settings})
    : _store = _Store(
        settings ??
            MachineSettings.fromJson(
              jsonMap(jsonMap(jsonDecode(b0ServiceFixtureJson))['machine']),
            ),
      );
  final _Store<MachineSettings> _store;
  @override
  Future<MachineSettings> read() async => _store.value;
  @override
  Stream<MachineSettings> watch() => _store.watch();
  @override
  Future<MachineSettings> save(
    MachineSettings settings, {
    required int expectedRevision,
  }) async {
    if (_store.value.revision != expectedRevision)
      throw const ServiceException(
        'REVISION-CONFLICT',
        'Machine settings changed elsewhere.',
      );
    if (settings.defaultFFmpegId != null &&
        !settings.installations.any((v) => v.id == settings.defaultFFmpegId))
      throw const ServiceException(
        'DEFAULT-NOT-FOUND',
        'Default FFmpeg must name a registered installation.',
      );
    if (settings.uiState != null) validatePopupSize(settings.uiState!.data);
    final saved = settings.copyWith(revision: expectedRevision + 1);
    _store.set(saved);
    return saved;
  }

  Future<void> dispose() => _store.dispose();
}

class FakeJobRepository implements JobRepository, JobLogs {
  FakeJobRepository({
    List<JobRecord>? records,
    Map<String, String> logs = const {},
  }) : _store = _Store(
         List.unmodifiable(
           records ??
               jsonMaps(
                 jsonMap(jsonDecode(b0ServiceFixtureJson))['jobs'],
               ).map(JobRecord.fromJson),
         ),
       ),
       _logs = Map.of(logs);
  final _Store<List<JobRecord>> _store;
  final Map<String, String> _logs;
  List<JobIndexEntry> _index(List<JobRecord> records) => List.unmodifiable(
    records.map(
      (r) => JobIndexEntry(
        id: r.id,
        recordFile: '${r.id}.json',
        startedAt: r.startedAt,
        status: r.status,
        templateName: r.templateName,
        outputPath: r.outputPath,
        encoderSummary: r.data['encoderSummary'] as String?,
        project: r.project,
        durationSec: r.durationSec ?? r.media.durationSec,
        elapsedSec: r.elapsedSec,
        realtime: r.realtime,
        sizeBytes: r.sizeBytes,
      ),
    ),
  );
  @override
  Future<List<JobIndexEntry>> list() async => _index(_store.value);
  @override
  Stream<List<JobIndexEntry>> watch() => _store.watch().map(_index);
  @override
  Future<JobRecord?> get(String id) async =>
      _store.value.where((v) => v.id == id).firstOrNull;
  @override
  Stream<String> readLog(String id) async* {
    final log = _logs[id];
    if (log == null)
      throw const ServiceException('NOT-FOUND', 'No fixture log for this job.');
    yield log;
  }

  @override
  Future<String?> logLocation(String id) async =>
      _logs.containsKey(id) ? 'fixture/$id.ffmpeg.log' : null;
  void publish(JobRecord record) => _store.set(
    List.unmodifiable([
      record,
      ..._store.value.where((v) => v.id != record.id),
    ]),
  );
  Future<void> dispose() => _store.dispose();
}

class FakeLiveRenderStatusReader implements LiveRenderStatusReader {
  FakeLiveRenderStatusReader({
    Map<String, LiveRenderStatus?> initial = const {},
  }) {
    for (final entry in initial.entries) {
      if (entry.value != null) validateLiveVideoFacts(entry.value!.data);
      _stores[entry.key] = _Store(entry.value);
    }
  }
  final Map<String, _Store<LiveRenderStatus?>> _stores = {};
  static List<LiveRenderStatus> samples() => jsonMaps(
    jsonMap(jsonDecode(b0ServiceFixtureJson))['live'],
  ).map(LiveRenderStatus.fromJson).toList();
  _Store<LiveRenderStatus?> _store(String file) =>
      _stores.putIfAbsent(file, () => _Store(null));
  @override
  Future<LiveRenderStatus?> read(String file) async => _store(file).value;
  @override
  Stream<LiveRenderStatus?> watch(String file) => _store(file).watch();
  void publish(String file, LiveRenderStatus status) {
    final store = _store(file);
    if (store.value != null &&
        (store.value!.jobId != status.jobId ||
            status.sequence <= store.value!.sequence))
      throw const ServiceException(
        'LIVE-SEQUENCE',
        'One job per file, with strictly increasing sequence.',
      );
    validateLiveVideoFacts(status.data);
    store.set(status);
  }

  Future<void> dispose() async {
    for (final store in _stores.values) {
      await store.dispose();
    }
  }
}

class FakeEditSessionService implements EditSessionService {
  FakeEditSessionService({Map<String, EditSessionRequest>? requests})
    : _requests = Map.of(
        requests ??
            {
              'b0-session': EditSessionRequest.fromJson(
                jsonMap(jsonMap(jsonDecode(b0ServiceFixtureJson))['request']),
              ),
            },
      );
  final Map<String, EditSessionRequest> _requests;
  final Map<String, EditSessionResult> _results = {};
  EditSessionResult? resultFor(String directory) => _results[directory];
  @override
  Future<EditSessionRequest> readRequest(String directory) async =>
      _requests[directory] ??
      (throw const ServiceException(
        'SESSION-NOT-FOUND',
        'No request fixture for this directory.',
      ));
  @override
  Future<void> writeResult(String directory, EditSessionResult result) async {
    final request = _requests[directory];
    if (request == null ||
        result.protocol != 1 ||
        result.sessionId != request.sessionId)
      throw const ServiceException(
        'SESSION-MISMATCH',
        'Unsupported protocol or wrong session.',
      );
    if (_results.containsKey(directory))
      throw const ServiceException(
        'SESSION-CLOSED',
        'A final result already exists.',
      );
    if (!['apply', 'cancel'].contains(result.action) ||
        (result.action == 'apply'
            ? result.recipe == null
            : result.recipe != null || result.origin != null))
      throw const ServiceException(
        'SESSION-RESULT',
        'Apply requires recipe; cancel omits recipe and origin.',
      );
    _results[directory] = result;
  }
}
