import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'package:ve_core/ve_core.dart';
import 'api.dart';
import 'models.dart';
import 'storage.dart';
import 'storage_validation.dart';
import 'builtin_presets.dart';
import 'windows_gpu.dart' show readLibraryDirectoryMetadata;

String _utcNow() => DateTime.now().toUtc().toIso8601String();
const _conflict = ServiceException(
  'REVISION-CONFLICT',
  'Updated elsewhere: reload or save as new.',
);

class FileMachineSettingsRepository implements MachineSettingsRepository {
  FileMachineSettingsRepository({ServicePaths? paths})
    : paths = paths ?? ServicePaths.windows();
  final ServicePaths paths;
  @override
  Future<MachineSettings> read() async {
    final data = await readJson(paths.machine);
    return data == null ? MachineSettings() : decodeMachine(data);
  }

  @override
  Stream<MachineSettings> watch() => watchSnapshots(read);
  @override
  Future<MachineSettings> save(
    MachineSettings settings, {
    required int expectedRevision,
  }) => withFileLock('${paths.machine}.lock', () async {
    final current = await read();
    if (current.revision != expectedRevision) throw _conflict;
    final saved = decodeMachine(
      settings.copyWith(revision: current.revision + 1).toJson(),
    );
    await atomicWrite(paths.machine, jsonEncode(saved.data));
    return saved;
  });
}

// One bounded native directory query avoids per-file Dart stats. Oversized
// directories use legacy metadata scanning in a short-lived isolate; no core
// object, open file or application state crosses that fallback boundary.
typedef _PresetStamp = ({String path, int size, int modified, int created});
typedef _LibraryMetadata = ({
  List<_PresetStamp> files,
  _PresetStamp preferences,
});
_PresetStamp _presetStamp(String path) {
  final stat = File(path).statSync();
  return (
    path: path,
    size: stat.size,
    modified: stat.modified.microsecondsSinceEpoch,
    created: stat.changed.microsecondsSinceEpoch,
  );
}

Future<_LibraryMetadata> _libraryMetadata(
  String directory,
  String preferences,
  String? nativeJson,
) async {
  if (nativeJson != null) {
    final native = jsonMap(jsonDecode(nativeJson));
    _PresetStamp stamp(JsonMap data) => (
      path: joinPath(directory, data['name'] as String),
      size: data['size'] as int,
      modified: data['modified'] as int,
      created: data['created'] as int,
    );
    final files = jsonMaps(native['files']).map(stamp).toList();
    files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return (
      files: files,
      preferences: native['preferences'] == null
          ? (path: preferences, size: -1, modified: 0, created: 0)
          : stamp(jsonMap(native['preferences'])),
    );
  }
  return Isolate.run(() {
    final root = Directory(directory);
    final files = <_PresetStamp>[];
    try {
      for (final entity in root.listSync(followLinks: false)) {
        if (entity is File && entity.path.endsWith('.vepreset'))
          files.add(_presetStamp(entity.path));
      }
      files.sort(
        (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
      );
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode != 2 && e.osError?.errorCode != 3) rethrow;
    }
    return (files: files, preferences: _presetStamp(preferences));
  });
}

class FilePresetLibrary
    implements PresetLibrary, PresetPreferences, PresetLocations {
  FilePresetLibrary({
    required VeCore core,
    ServicePaths? paths,
    List<Preset>? builtins,
    String Function()? now,
  }) : _core = core,
       paths = paths ?? ServicePaths.windows(),
       _now = now ?? _utcNow,
       _builtins = List.unmodifiable(builtins ?? builtinPresets());
  final VeCore _core;
  final ServicePaths paths;
  final String Function() _now;
  final List<Preset> _builtins;
  String _file(String id) => joinPath(paths.library, '${safeId(id)}.vepreset');
  String _history(String id, int revision) => joinPath(
    joinPath(joinPath(paths.library, '.history'), safeId(id)),
    '$revision.vepreset',
  );
  late final _builtinsById = {
    for (final p in _builtins) p.recipe.id.toLowerCase(): p,
  };
  Preset? _builtin(String id) => _builtinsById[id.toLowerCase()];
  late final _listedBuiltins = _builtins
      .map(_requirements)
      .toList(growable: false);
  Map<String, ({_PresetStamp stamp, Preset preset})> _listedFiles = {};
  _PresetStamp? _listedPreferencesStamp;
  JsonMap? _listedPreferences;
  List<Preset>? _listedSnapshot;
  Future<List<Preset>>? _listing;
  int _listEpoch = 0;
  int _listedEpoch = -1;
  String? _listedMetadataJson;
  void _invalidateList(String? id) {
    _listEpoch++;
    if (id == null) {
      _listedPreferencesStamp = null;
    } else {
      _listedFiles.remove(_file(id).toLowerCase());
    }
  }

  Future<JsonMap> _preferences() async {
    final data = await readJson(paths.preferences);
    if (data == null) return {'preferences': 1, 'presets': <String, Object?>{}};
    major(data, 'preferences');
    for (final value in objectField(data, 'presets').values) {
      if (value is! Map) invalid('Preset preferences must be objects.');
      for (final key in ['favorite', 'pinned']) {
        boolField(jsonMap(value), key);
      }
    }
    return data;
  }

  Preset _requirements(Preset preset) {
    final normalized = _core.normalize(preset.recipe.toJson());
    return preset.copyWith(
      requires: preset.requires.copyWith(
        encoders: normalized.requiredEncoders ?? <String>[],
        known: normalized.requiredEncoders != null,
      ),
    );
  }

  Future<Preset?> _current(String id) async {
    final builtin = _builtin(id);
    if (builtin != null) {
      final preferences = objectField(await _preferences(), 'presets');
      final overlay = jsonMap(
        preferences[builtin.recipe.id.toLowerCase()] ?? <String, Object?>{},
      );
      return _requirements(
        builtin.copyWith(
          favorite: overlay['favorite'] ?? builtin.favorite,
          pinned: overlay['pinned'] ?? builtin.pinned,
        ),
      );
    }
    final data = await readJson(_file(id));
    if (data == null) return null;
    final preset = decodePreset(data, _core);
    if (preset.recipe.id.toLowerCase() != id.toLowerCase() || preset.builtin)
      invalid('Preset file identity mismatch.');
    return _requirements(preset);
  }

  @override
  Future<Preset?> get(String id, {int? revision}) async {
    safeId(id);
    if (revision != null && revision < 1) invalid('Revision must be positive.');
    final current = await _current(id);
    if (revision == null || current?.revision == revision) return current;
    if (_builtin(id) != null) return null;
    final data = await readJson(_history(id, revision));
    if (data == null) return null;
    final result = decodePreset(data, _core);
    if (result.recipe.id.toLowerCase() != id.toLowerCase() ||
        result.revision != revision ||
        result.builtin)
      invalid('History identity mismatch.');
    return _requirements(result);
  }

  @override
  Future<List<Preset>> list() => _listing ??= _readList().whenComplete(() {
    _listing = null;
  });

  Future<List<Preset>> _readList() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final epoch = _listEpoch;
      final metadataJson = readLibraryDirectoryMetadata(paths.library);
      if (metadataJson != null &&
          _listedMetadataJson == metadataJson &&
          _listedEpoch == epoch &&
          _listedSnapshot != null)
        return _listedSnapshot!;
      // Keep no successful fingerprint after observing a change that may fail
      // validation. A later repair must pass through the normal read path.
      _listedMetadataJson = null;
      final metadata = await _libraryMetadata(
        paths.library,
        paths.preferences,
        metadataJson,
      );
      final entries = <String, ({_PresetStamp stamp, Preset preset})>{};
      final result = <Preset>[];
      JsonMap preferences;
      if (_listedPreferencesStamp == metadata.preferences &&
          _listedPreferences != null) {
        preferences = _listedPreferences!;
      } else {
        _listedPreferencesStamp =
            null; // A failed read must not become a cache hit on repair.
        preferences = await _preferences();
      }
      final overlays = objectField(preferences, 'presets');
      for (var i = 0; i < _listedBuiltins.length; i++) {
        final base = _listedBuiltins[i];
        final overlay = jsonMap(
          overlays[base.recipe.id.toLowerCase()] ?? <String, Object?>{},
        );
        final favorite = overlay['favorite'] ?? base.favorite;
        final pinned = overlay['pinned'] ?? base.pinned;
        final prior = _listedSnapshot == null ? null : _listedSnapshot![i];
        result.add(
          prior != null && prior.favorite == favorite && prior.pinned == pinned
              ? prior
              : base.copyWith(favorite: favorite, pinned: pinned),
        );
      }
      for (final stamp in metadata.files) {
        final key = stamp.path.toLowerCase();
        final cached = _listedFiles[key];
        if (cached != null && cached.stamp == stamp) {
          entries[key] = cached;
          result.add(cached.preset);
          continue;
        }
        final name = File(stamp.path).uri.pathSegments.last;
        final id = name.substring(0, name.length - '.vepreset'.length);
        safeId(id);
        if (_builtin(id) != null)
          invalid('User file shadows a built-in preset.');
        // Do not reuse an old successful entry after observing a malformed edit,
        // even if a later repair restores its original size/timestamps.
        _listedFiles.remove(key);
        final data = await readJson(stamp.path);
        if (data == null) continue; // Removed between enumeration and open.
        final decoded = decodePreset(data, _core);
        if (decoded.recipe.id.toLowerCase() != id.toLowerCase() ||
            decoded.builtin)
          invalid('Preset file identity mismatch.');
        final preset = _requirements(decoded);
        entries[key] = (stamp: stamp, preset: preset);
        result.add(preset);
      }
      if (epoch != _listEpoch)
        continue; // An own write won while reads awaited.
      final old = _listedSnapshot;
      final same =
          old != null &&
          old.length == result.length &&
          Iterable<int>.generate(
            result.length,
          ).every((i) => identical(old[i], result[i]));
      _listedFiles =
          entries; // Prune removed files; retain one revision per file.
      _listedPreferencesStamp = metadata.preferences;
      _listedPreferences = preferences;
      _listedMetadataJson = metadataJson;
      _listedEpoch = epoch;
      return _listedSnapshot = same ? old : List<Preset>.unmodifiable(result);
    }
    throw const ServiceException(
      'STORE-BUSY',
      'Library changed repeatedly while being read.',
    );
  }

  @override
  Stream<List<Preset>> watch() => watchSnapshots(list);
  @override
  Future<Preset> save(Preset preset, {int? expectedRevision}) =>
      withFileLock(joinPath(paths.library, '.write.lock'), () async {
        final checked = decodePreset(preset.toJson(), _core);
        if (checked.builtin || _builtin(checked.recipe.id) != null) {
          throw const ServiceException(
            'READ-ONLY',
            'Duplicate a built-in before changing its recipe.',
          );
        }
        final existing = await _current(checked.recipe.id);
        if (existing == null &&
            await Directory(
              joinPath(joinPath(paths.library, '.history'), checked.recipe.id),
            ).exists()) {
          throw const ServiceException(
            'REVISION-CONFLICT',
            'This ID has retained history. Save with a new ID.',
          );
        }
        if (existing == null
            ? expectedRevision != null
            : existing.revision != expectedRevision)
          throw _conflict;
        final errors = _core
            .validate(checked.recipe)
            .where((i) => i.level == IssueLevel.error)
            .toList();
        if (errors.isNotEmpty)
          throw ServiceException(
            'RECIPE-INVALID',
            errors.map((i) => i.message).join(' '),
          );
        final saved = _requirements(
          checked.copyWith(
            revision: (existing?.revision ?? 0) + 1,
            updatedAt: _now(),
          ),
        );
        final serialized = jsonEncode(saved.data);
        // Validate output size before creating a history entry.
        decodeJson(serialized);
        if (existing != null)
          await atomicWrite(
            _history(existing.recipe.id, existing.revision),
            jsonEncode(existing.data),
          );
        await atomicWrite(_file(saved.recipe.id), serialized);
        _invalidateList(saved.recipe.id);
        await _prune(saved.recipe.id);
        return saved;
      });
  Future<void> _prune(String id) async {
    // Best effort after commit: maintenance failure must not report a committed
    // save as failed. Retry leftovers on the next save/preferences update.
    try {
      final directory = Directory(
        joinPath(joinPath(paths.library, '.history'), safeId(id)),
      );
      if (!await directory.exists()) return;
      final versions = <(int, File)>[];
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final match = RegExp(
          r'^(\d+)\.vepreset$',
        ).firstMatch(entity.uri.pathSegments.last);
        final revision = match == null ? null : int.tryParse(match[1]!);
        if (revision != null) versions.add((revision, entity));
      }
      versions.sort((a, b) => a.$1.compareTo(b.$1));
      for (final entry in versions.take(
        versions.length > 20 ? versions.length - 20 : 0,
      )) {
        try {
          await entry.$2.delete();
        } on FileSystemException {
          /* retry next time */
        }
      }
    } on FileSystemException {
      /* committed value remains valid */
    }
  }

  @override
  Future<void> delete(
    String id, {
    required int expectedRevision,
  }) => withFileLock(joinPath(paths.library, '.write.lock'), () async {
    if (_builtin(id) != null)
      throw const ServiceException('READ-ONLY', 'Built-ins cannot be deleted.');
    final current = await _current(id);
    if (current == null)
      throw const ServiceException('NOT-FOUND', 'Preset not found.');
    if (current.revision != expectedRevision) throw _conflict;
    // Preserve prior versions for recovery; current removal is one operation.
    await atomicWrite(_history(id, current.revision), jsonEncode(current.data));
    await File(_file(id)).delete();
    _invalidateList(id);
  });
  @override
  Future<Preset> setPreferences(
    String id, {
    bool? favorite,
    bool? pinned,
  }) => withFileLock(joinPath(paths.library, '.write.lock'), () async {
    final current = await _current(id);
    if (current == null)
      throw const ServiceException('NOT-FOUND', 'Preset not found.');
    if (!current.builtin) {
      // Preference writes change only the latest metadata, never a stale UI draft.
      final saved = current.copyWith(
        favorite: favorite ?? current.favorite,
        pinned: pinned ?? current.pinned,
        revision: current.revision + 1,
        updatedAt: _now(),
      );
      decodeJson(jsonEncode(saved.data));
      await atomicWrite(
        _history(id, current.revision),
        jsonEncode(current.data),
      );
      await atomicWrite(_file(id), jsonEncode(saved.data));
      _invalidateList(id);
      await _prune(id);
      return saved;
    }
    final data = await _preferences();
    final entries = objectField(data, 'presets');
    final key = current.recipe.id.toLowerCase();
    entries[key] = <String, Object?>{
      ...jsonMap(entries[key] ?? <String, Object?>{}),
      'favorite': favorite ?? current.favorite,
      'pinned': pinned ?? current.pinned,
    };
    data['presets'] = entries;
    await atomicWrite(paths.preferences, jsonEncode(data));
    _invalidateList(null);
    return (await _current(id))!;
  });
  @override
  Future<Preset> importPreset(String jsonText, {required String newId}) async {
    final imported = decodePreset(decodeJson(jsonText), _core);
    return save(
      imported.copyWith(
        recipe: imported.recipe.copyWith(id: safeId(newId)),
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
    return jsonEncode(preset.data);
  }

  @override
  Future<String?> location(String id) async {
    final preset = await get(id);
    return preset == null || preset.builtin ? null : _file(preset.recipe.id);
  }
}

class FileCapabilityCache implements CapabilityCache {
  FileCapabilityCache({ServicePaths? paths, this.parserVersion = 1})
    : paths = paths ?? ServicePaths.windows();
  final ServicePaths paths;
  final int parserVersion;
  String _file(String key) => joinPath(paths.cache, '${safeId(key)}.json');
  @override
  Future<FFmpegCapabilities?> read(String identityKey) async {
    final data = await readJson(_file(identityKey));
    if (data == null) return null;
    major(data, 'cache');
    final value = decodeCapabilities(objectField(data, 'capabilities'));
    if (value.identityKey != identityKey) invalid('Cache identity mismatch.');
    return value.parser == parserVersion ? value : null;
  }

  @override
  Future<void> write(FFmpegCapabilities capabilities) =>
      withFileLock('${_file(capabilities.identityKey)}.lock', () async {
        final value = decodeCapabilities(capabilities.toJson());
        if (value.parser != parserVersion)
          throw const ServiceException(
            'CACHE-PARSER',
            'Capability parser version does not match.',
          );
        final previous = await readJson(_file(value.identityKey));
        if (previous != null) major(previous, 'cache');
        await atomicWrite(
          _file(value.identityKey),
          jsonEncode({...?previous, 'cache': 1, 'capabilities': value.data}),
        );
      });
  @override
  Future<void> invalidate(String identityKey) =>
      withFileLock('${_file(identityKey)}.lock', () async {
        final file = File(_file(identityKey));
        if (await file.exists()) await file.delete();
      });

  /// Serialized read/modify/write for lazy help and hardware updates. They cannot
  /// overwrite each other's cache fields while the app is receiving progress.
  Future<FFmpegCapabilities> update(
    String identityKey,
    FFmpegCapabilities Function(FFmpegCapabilities? current) change,
  ) => withFileLock('${_file(identityKey)}.lock', () async {
    final previous = await readJson(_file(identityKey));
    if (previous != null) major(previous, 'cache');
    final current = previous == null
        ? null
        : decodeCapabilities(objectField(previous, 'capabilities'));
    if (current != null && current.identityKey != identityKey)
      invalid('Cache identity mismatch.');
    final next = decodeCapabilities(
      change(current?.parser == parserVersion ? current : null).toJson(),
    );
    if (next.identityKey != identityKey || next.parser != parserVersion)
      throw const ServiceException(
        'CACHE-PARSER',
        'Cache update has a different identity/parser.',
      );
    await atomicWrite(
      _file(identityKey),
      jsonEncode({...?previous, 'cache': 1, 'capabilities': next.data}),
    );
    return next;
  });
}

class FileLiveRenderStatusReader implements LiveRenderStatusReader {
  FileLiveRenderStatusReader({
    this.interval = const Duration(milliseconds: 250),
  });
  final Duration interval;
  @override
  Future<LiveRenderStatus?> read(String file) async {
    final data = await readJson(file);
    return data == null ? null : decodeLive(data);
  }

  @override
  Stream<LiveRenderStatus?> watch(String file) {
    LiveRenderStatus? last;
    return watchSnapshots(() async {
      try {
        final next = await read(file);
        if (next != null &&
            (last == null ||
                (next.jobId == last!.jobId && next.sequence > last!.sequence)))
          last = next;
      } on ServiceException {
        /* last good value remains; missing/stale isn't terminal */
      }
      return last;
    }, interval: interval);
  }
}

class FileEditSessionService implements EditSessionService {
  FileEditSessionService({required NativeVeCore core}) : _core = core;
  final NativeVeCore _core;
  void _issues(JsonMap response, String code) {
    final errors = jsonMaps(
      response['issues'],
    ).map(Issue.fromJson).where((i) => i.level == IssueLevel.error).toList();
    if (errors.isNotEmpty)
      throw ServiceException(code, errors.map((i) => i.message).join(' '));
  }

  @override
  Future<EditSessionRequest> readRequest(String directory) async {
    final data = await readJson(joinPath(directory, 'request.json'));
    if (data == null)
      throw const ServiceException(
        'SESSION-NOT-FOUND',
        'Edit-session request is missing.',
      );
    _issues(_core.validateSessionRequest(data), 'SESSION-REQUEST');
    return EditSessionRequest.fromJson(data);
  }

  @override
  Future<void> writeResult(String directory, EditSessionResult result) =>
      withFileLock(joinPath(directory, '.result.lock'), () async {
        final request = await readRequest(directory);
        if (result.protocol != request.protocol ||
            result.sessionId != request.sessionId) {
          throw const ServiceException(
            'SESSION-MISMATCH',
            'Result belongs to another edit session.',
          );
        }
        final path = joinPath(directory, 'result.json');
        if (await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          throw const ServiceException(
            'SESSION-CLOSED',
            'A final result already exists.',
          );
        }
        _issues(_core.validateSessionResult(result.toJson()), 'SESSION-RESULT');
        if (result.recipe != null) {
          final errors = _core
              .validate(result.recipe!, media: request.context.media)
              .where((i) => i.level == IssueLevel.error)
              .toList();
          if (errors.isNotEmpty)
            throw ServiceException(
              'RECIPE-INVALID',
              errors.map((i) => i.message).join(' '),
            );
        }
        await atomicWrite(path, jsonEncode(result.data));
      });
}
