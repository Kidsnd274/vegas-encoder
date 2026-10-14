import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:ve_core/ve_core.dart';
import 'api.dart';
import 'models.dart';
import 'storage.dart';
import 'ffmpeg_identity.dart';
import 'ffmpeg_parser.dart';
import 'process_runner.dart';

class FFmpegCandidate {
  const FFmpegCandidate(this.path, this.source);
  final String path;
  final String source;
}

abstract interface class FFmpegCandidateFinder {
  Future<List<FFmpegCandidate>> find();
}

class WindowsFFmpegCandidateFinder implements FFmpegCandidateFinder {
  WindowsFFmpegCandidateFinder({
    Map<String, String>? environment,
    List<String>? iniPaths,
  }) : environment = Map.unmodifiable({
         for (final entry in (environment ?? Platform.environment).entries)
           entry.key.toUpperCase(): entry.value,
       }),
       iniPaths = List.unmodifiable(
         iniPaths ??
             [
               joinPath(
                 File(Platform.resolvedExecutable).parent.path,
                 'vegas-encoder.ini',
               ),
             ],
       );
  final Map<String, String> environment;
  final List<String> iniPaths;
  @override
  Future<List<FFmpegCandidate>> find() async {
    final candidates = <FFmpegCandidate>[];
    void add(String path, String source) {
      if (absoluteWindowsPath(path))
        candidates.add(FFmpegCandidate(path, source));
    }

    for (final path in iniPaths) {
      final bytes = await readBytes(path, limit: 65536);
      if (bytes == null) continue;
      final match = RegExp(
        r'^\s*FFmpegPath\s*=\s*(.*?)\s*$',
        caseSensitive: false,
        multiLine: true,
      ).firstMatch(utf8.decode(bytes));
      if (match != null) add(match[1]!.replaceAll(RegExp(r'^"|"$'), ''), 'ini');
    }
    for (final entry in (environment['PATH'] ?? '').split(';')) {
      final directory = entry.trim().replaceAll(RegExp(r'^"|"$'), '');
      if (directory.isNotEmpty) add(joinPath(directory, 'ffmpeg.exe'), 'path');
    }
    final local = environment['LOCALAPPDATA'];
    if (local != null) {
      add(joinPath(local, r'Microsoft\WinGet\Links\ffmpeg.exe'), 'winget');
      await _packages(
        joinPath(local, r'Microsoft\WinGet\Packages'),
        RegExp(r'^(?:Gyan\.FFmpeg|BtbN)', caseSensitive: false),
        'winget',
        candidates,
      );
    }
    final scoop =
        environment['SCOOP'] ??
        (environment['USERPROFILE'] == null
            ? null
            : joinPath(environment['USERPROFILE']!, 'scoop'));
    if (scoop != null) {
      add(joinPath(scoop, r'apps\ffmpeg\current\bin\ffmpeg.exe'), 'scoop');
      add(joinPath(scoop, r'shims\ffmpeg.exe'), 'scoop');
    }
    final chocolatey =
        environment['CHOCOLATEYINSTALL'] ??
        (environment['PROGRAMDATA'] == null
            ? null
            : joinPath(environment['PROGRAMDATA']!, 'chocolatey'));
    if (chocolatey != null)
      await _packages(
        joinPath(chocolatey, 'lib'),
        RegExp(r'^ffmpeg', caseSensitive: false),
        'chocolatey',
        candidates,
      );
    return List.unmodifiable(candidates);
  }

  Future<void> _packages(
    String root,
    RegExp names,
    String source,
    List<FFmpegCandidate> output,
  ) async {
    final directory = Directory(root);
    if (!await directory.exists()) return;
    var count = 0;
    Future<void> descend(Directory dir, int depth) async {
      if (depth > 6) return;
      await for (final entry in dir.list(followLinks: false)) {
        if (++count > 4000)
          throw const ServiceException(
            'DISCOVERY-LIMIT',
            'FFmpeg package search exceeded its bounds.',
          );
        if (entry is Directory)
          await descend(entry, depth + 1);
        else if (entry.uri.pathSegments.last.toLowerCase() == 'ffmpeg.exe')
          output.add(FFmpegCandidate(entry.path, source));
      }
    }

    await for (final entry in directory.list(followLinks: false)) {
      if (++count > 4000)
        throw const ServiceException(
          'DISCOVERY-LIMIT',
          'FFmpeg package search exceeded its bounds.',
        );
      if (entry is Directory &&
          names.hasMatch(
            entry.uri.pathSegments.where((s) => s.isNotEmpty).last,
          ))
        await descend(entry, 0);
    }
  }
}

class FakeFFmpegCandidateFinder implements FFmpegCandidateFinder {
  FakeFFmpegCandidateFinder(this.candidates);
  List<FFmpegCandidate> candidates;
  @override
  Future<List<FFmpegCandidate>> find() async => List.unmodifiable(candidates);
}

/// The service owns installation-list writes. All writes re-read C7 and reapply
/// only their own fields on a revision conflict; app preferences remain intact.
Future<MachineSettings> updateMachine(
  MachineSettingsRepository repository,
  MachineSettings Function(MachineSettings current) transform,
) async {
  for (var attempt = 0; attempt < 8; attempt++) {
    final current = await repository.read();
    final next = transform(current);
    if (jsonEncode(current.data) == jsonEncode(next.data)) return current;
    try {
      return await repository.save(next, expectedRevision: current.revision);
    } on ServiceException catch (e) {
      if (e.code != 'REVISION-CONFLICT') rethrow;
    }
  }
  throw const ServiceException(
    'REVISION-CONFLICT',
    'Settings kept changing; retry the operation.',
  );
}

class WindowsFFmpegDiscovery implements FFmpegDiscovery {
  WindowsFFmpegDiscovery({
    required this.settings,
    required this.runner,
    FFmpegCandidateFinder? finder,
    WindowsFFmpegHelpParser? parser,
    this.capabilities,
  }) : finder = finder ?? WindowsFFmpegCandidateFinder(),
       parser = parser ?? WindowsFFmpegHelpParser();
  final MachineSettingsRepository settings;
  final ProcessExecutor runner;
  final FFmpegCandidateFinder finder;
  final WindowsFFmpegHelpParser parser;
  final CapabilityCache? capabilities;
  final List<ServiceException> scanProblems = [];
  @override
  Future<List<FFmpegInstallation>> list() async => List.unmodifiable(
    await Future.wait(
      (await settings.read()).installations.map((installation) async {
        final health = await installationHealth(installation);
        if (health.health != 'unchanged' || capabilities == null) return health;
        final value = await capabilities!.read(installation.identity.key);
        if (value == null)
          return health.copyWith(availability: <String, Object?>{});
        return health.copyWith(
          availability: {
            ...health.availability,
            for (final entry in value.encoders.entries)
              entry.key:
                  jsonMap(entry.value)['availability'] ??
                  EncoderAvailability().data,
          },
        );
      }),
    ),
  );
  @override
  Stream<List<FFmpegInstallation>> watch() =>
      watchSnapshots(list, interval: const Duration(seconds: 1));
  Future<String> _resolve(String path) async {
    // Scoop's launcher must not be executed or hashed as FFmpeg itself.
    final shim = File(
      path,
    ).path.replaceFirst(RegExp(r'\.exe$', caseSensitive: false), '.shim');
    final bytes = await readBytes(shim, limit: 65536);
    if (bytes != null) {
      final match = RegExp(
        r'^\s*path\s*=\s*"?(.+?)"?\s*$',
        multiLine: true,
        caseSensitive: false,
      ).firstMatch(utf8.decode(bytes));
      if (match == null)
        throw const ServiceException(
          'FFMPEG-SHIM',
          'Scoop shim has no absolute executable path.',
        );
      path = match[1]!;
    }
    return canonicalExecutable(path);
  }

  Future<FFmpegInstallation> identify(
    String path, {
    String source = 'manual',
    CancellationToken? cancellation,
  }) async {
    final token = cancellation ?? CancellationToken();
    token.check();
    final resolved = await _resolve(path);
    final identity = await binaryIdentity(resolved, parser.version);
    token.check();
    final version = await runner.run(resolved, [
      '-hide_banner',
      '-version',
    ], cancellation: token);
    version.requireSuccess('FFmpeg identity');
    final metadata = parser.parseVersion(version.stdout + version.stderr);
    final ffprobe = joinPath(File(resolved).parent.path, 'ffprobe.exe');
    if (!await File(ffprobe).exists())
      throw const ServiceException(
        'FFPROBE-MISSING',
        'FFprobe must be beside FFmpeg.',
      );
    await requireX64Pe(ffprobe);
    final probeBefore = await File(ffprobe).stat();
    final probeDigest = await IsolatedHash.file(ffprobe);
    final probe = await runner.run(ffprobe, [
      '-v',
      'error',
      '-show_versions',
      '-of',
      'json',
    ], cancellation: token);
    probe.requireSuccess('FFprobe identity');
    final actual = parser.parseProbeVersion(probe.stdout);
    for (final key in ['version', 'configuration', 'libraries']) {
      if (canonicalJson(actual[key]) != canonicalJson(metadata[key]))
        throw const ServiceException(
          'FFPROBE-MISMATCH',
          'FFprobe version/configuration/libraries do not match FFmpeg.',
        );
    }
    final after = await binaryStats(resolved);
    if (jsonEncode(after) != jsonEncode(identity.extensions['fileStats']))
      throw const ServiceException(
        'FFMPEG-CHANGED',
        'FFmpeg changed during its identity check.',
      );
    final probeStat = await File(ffprobe).stat();
    if (probeBefore.size != probeStat.size ||
        probeBefore.modified != probeStat.modified ||
        probeDigest != await IsolatedHash.file(ffprobe))
      throw const ServiceException(
        'FFPROBE-CHANGED',
        'FFprobe changed during its identity check.',
      );
    token.check();
    return FFmpegInstallation(
      id: 'ffmpeg-${sha256.convert(utf8.encode(resolved.toLowerCase())).toString().substring(0, 32)}',
      label: 'FFmpeg ${metadata['version']}',
      path: resolved,
      ffprobePath: ffprobe,
      source: source,
      version: metadata['version'] as String,
      build: metadata['build'] as String,
      license: metadata['license'] as String,
      identity: identity,
      health: 'unchanged',
      extensions: {
        'configuration': metadata['configuration'],
        'libraries': metadata['libraries'],
        'ffprobeIdentity': {
          'sha256': probeDigest,
          'size': probeStat.size,
          'mtime': probeStat.modified.toUtc().toIso8601String(),
        },
      },
    );
  }

  FFmpegInstallation _combine(
    FFmpegInstallation? current,
    FFmpegInstallation found,
  ) {
    if (current == null) return found;
    final unchanged = current.identity.key == found.identity.key;
    return FFmpegInstallation.fromJson({
      ...current.data,
      ...found.data,
      'label': current.label,
      'source': current.source,
      'extensions': {...current.extensions, ...found.extensions},
      'probedAt': unchanged ? current.probedAt : null,
      'probeMs': unchanged ? current.probeMs : null,
      'counts': unchanged ? current.counts : <String, Object?>{},
      'availability': unchanged ? current.availability : <String, Object?>{},
    });
  }

  Future<FFmpegInstallation> register(FFmpegInstallation found) async {
    final saved = await updateMachine(settings, (current) {
      final prior = current.installations
          .where((i) => i.id == found.id)
          .firstOrNull;
      return current.copyWith(
        installations: [
          for (final i in current.installations)
            if (i.id != found.id) i else _combine(prior, found),
          if (prior == null) found,
        ],
      );
    });
    return saved.installations.firstWhere((i) => i.id == found.id);
  }

  Future<FFmpegInstallation> refresh(
    FFmpegInstallation installation,
    CancellationToken token,
  ) async {
    final fresh = (await identify(
      installation.path,
      source: installation.source,
      cancellation: token,
    )).copyWith(id: installation.id);
    token.check();
    final updated = await updateMachine(settings, (current) {
      token.check();
      final previous = current.installations
          .where((i) => i.id == installation.id)
          .firstOrNull;
      if (previous == null)
        throw const ServiceException(
          'NOT-FOUND',
          'Installation was removed during its identity check.',
        );
      if (previous.path.toLowerCase() != installation.path.toLowerCase())
        throw const ServiceException(
          'FFMPEG-CHANGED',
          'Installation path changed during probing.',
        );
      return current.copyWith(
        installations: current.installations
            .map((i) => i.id == installation.id ? _combine(i, fresh) : i)
            .toList(),
      );
    });
    return updated.installations.firstWhere((i) => i.id == installation.id);
  }

  @override
  Future<FFmpegInstallation> add(String executablePath) async =>
      register(await identify(executablePath));
  @override
  Future<List<FFmpegInstallation>> scan() async {
    scanProblems.clear();
    final candidates = [
      for (final i in (await settings.read()).installations)
        FFmpegCandidate(i.path, i.source),
      ...await finder.find(),
    ];
    final seen = <String>{};
    for (final candidate in candidates) {
      try {
        final resolved = await _resolve(candidate.path);
        if (!seen.add(resolved.toLowerCase())) continue;
        await register(await identify(resolved, source: candidate.source));
      } on ServiceException catch (e) {
        // Missing PATH entries are normal. Other candidate failures are explicit
        // diagnostics, never promoted into a usable installation.
        if (e.code != 'FFMPEG-MISSING') scanProblems.add(e);
      } on FileSystemException catch (e) {
        scanProblems.add(ServiceException('DISCOVERY-READ', e.message));
      }
    }
    return list(); // Keep vanished/manual/default records with current health.
  }

  @override
  Future<void> remove(String installationId) async {
    await updateMachine(settings, (current) {
      if (current.defaultFFmpegId == installationId)
        throw const ServiceException(
          'DEFAULT-IN-USE',
          'Choose another default FFmpeg before removing this one.',
        );
      if (!current.installations.any((i) => i.id == installationId))
        throw const ServiceException('NOT-FOUND', 'Installation not found.');
      return current.copyWith(
        installations: current.installations
            .where((i) => i.id != installationId)
            .toList(),
      );
    });
  }

  Future<void> updateRecord(
    String id,
    String identityKey,
    FFmpegInstallation Function(FFmpegInstallation) change,
  ) async {
    await updateMachine(settings, (current) {
      final record = current.installations.where((i) => i.id == id).firstOrNull;
      if (record == null)
        throw const ServiceException(
          'NOT-FOUND',
          'Installation was removed while probing.',
        );
      if (record.identity.key != identityKey)
        throw const ServiceException(
          'FFMPEG-CHANGED',
          'Installation identity changed during probing.',
        );
      return current.copyWith(
        installations: current.installations
            .map((i) => i.id == id ? change(i) : i)
            .toList(),
      );
    });
  }
}
