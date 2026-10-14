import 'dart:convert';
import 'dart:io';
import 'package:ve_core/ve_core.dart';
import 'api.dart';
import 'models.dart';
import 'storage.dart';
import 'storage_validation.dart';
import 'builtin_presets.dart';

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
  Preset? _builtin(String id) => _builtins
      .where((p) => p.recipe.id.toLowerCase() == id.toLowerCase())
      .firstOrNull;
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
  Future<List<Preset>> list() async {
    final result = <Preset>[];
    for (final p in _builtins) {
      result.add((await _current(p.recipe.id))!);
    }
    final directory = Directory(paths.library);
    if (await directory.exists()) {
      final files = await directory
          .list(followLinks: false)
          .where((e) => e is File && e.path.endsWith('.vepreset'))
          .toList();
      files.sort(
        (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
      );
      for (final file in files) {
        final basename = file.uri.pathSegments.last;
        final id = basename.substring(0, basename.length - '.vepreset'.length);
        if (_builtin(id) != null)
          invalid('User file shadows a built-in preset.');
        final value = await _current(id);
        if (value != null) result.add(value);
      }
    }
    return List.unmodifiable(result);
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
