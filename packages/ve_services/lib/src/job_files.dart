import 'dart:convert';
import 'dart:io';
import 'package:ve_core/ve_core.dart';
import 'api.dart';
import 'models.dart';
import 'storage.dart';
import 'storage_validation.dart';

class FileJobRepository implements JobRepository, JobLogs {
  FileJobRepository({required VeCore core, ServicePaths? paths})
    : _core = core,
      paths = paths ?? ServicePaths.windows();
  final VeCore _core;
  final ServicePaths paths;
  String get _index => joinPath(paths.jobs, 'jobs.jsonl');
  String _record(String id) => joinPath(paths.jobs, '${safeId(id)}.json');
  @override
  Future<JobRecord?> get(String id) async {
    final data = await readJson(_record(id));
    if (data == null) return null;
    final result = decodeJob(data, _core);
    if (result.id.toLowerCase() != id.toLowerCase())
      invalid('Job file identity mismatch.');
    return result;
  }

  @override
  Future<List<JobIndexEntry>> list() async {
    if (!await File(_index).exists()) return _recover();
    final entries = <String, JobIndexEntry>{};
    await for (final line in _completeLines(_index)) {
      if (line.isEmpty) continue;
      final entry = decodeIndex(decodeJson(line));
      entries[entry.id.toLowerCase()] = entry;
    }
    return _sort(entries.values.toList());
  }

  List<JobIndexEntry> _sort(List<JobIndexEntry> entries) {
    entries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return List.unmodifiable(entries);
  }

  JobIndexEntry _entry(JobRecord record) => JobIndexEntry(
    id: record.id,
    recordFile: '${record.id}.json',
    startedAt: record.startedAt,
    status: record.status,
    templateName: record.templateName,
    outputPath: record.outputPath,
    encoderSummary: record.encoderSummary,
    project: record.project,
    durationSec: record.durationSec ?? record.media.durationSec,
    elapsedSec: record.elapsedSec,
    sizeBytes: record.sizeBytes,
  );
  Future<List<JobIndexEntry>> _recover() async {
    final directory = Directory(paths.jobs);
    if (!await directory.exists()) return const [];
    final entries = <JobIndexEntry>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File ||
          !entity.path.endsWith('.json') ||
          entity.path.endsWith('.live.json'))
        continue;
      final basename = entity.uri.pathSegments.last;
      final id = basename.substring(0, basename.length - 5);
      final record = await get(id);
      if (record != null) entries.add(_entry(record));
    }
    return _sort(entries);
  }

  @override
  Stream<List<JobIndexEntry>> watch() => watchSnapshots(list);

  /// Explicit recovery only. read/list/watch never modify the index.
  Future<void> rebuildIndex() => withFileLock('$_index.lock', () async {
    final entries = await _recover();
    // The index may exceed 1 MiB; each bounded line is written to an adjacent
    // file incrementally, then atomically replaced. No old index is deleted.
    final temp = File(
      '$_index.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temp.create(exclusive: true);
      final handle = await temp.open(mode: FileMode.writeOnly);
      try {
        for (final entry in entries) {
          final line = jsonEncode(entry.data);
          decodeJson(line);
          await handle.writeString('$line\n');
        }
        await handle.flush();
      } finally {
        await handle.close();
      }
      await temp.rename(_index);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  });

  @override
  Future<String?> logLocation(String id) async {
    final record = await get(id);
    final name = record?.logFile;
    if (name == null) return null;
    // Logs are local basenames. No record-controlled arbitrary file reads.
    if (name != '${record!.id}.ffmpeg.log')
      invalid('Job logFile must be the job FFmpeg log basename.');
    final path = joinPath(paths.jobs, name);
    return await File(path).exists() ? path : null;
  }

  @override
  Stream<String> readLog(String id) async* {
    final path = await logLocation(id);
    if (path == null)
      throw const ServiceException(
        'NOT-FOUND',
        'Full FFmpeg log is unavailable for this job.',
      );
    try {
      yield* File(path).openRead().transform(utf8.decoder);
    } on FileSystemException catch (e) {
      throw ServiceException('FILE-READ', 'Cannot read job log: ${e.message}');
    } on FormatException {
      throw const ServiceException(
        'INVALID-DATA',
        'FFmpeg log is not valid UTF-8.',
      );
    }
  }
}

/// A truncated last line is ignored. A complete malformed line is reported.
/// Buffers never exceed the per-line limit, even if a writer forgets newlines.
Stream<String> _completeLines(String path) async* {
  final pending = <int>[];
  try {
    await for (final chunk in File(path).openRead()) {
      for (final byte in chunk) {
        if (byte == 10) {
          yield utf8.decode(pending);
          pending.clear();
        } else {
          pending.add(byte);
          if (pending.length > jsonFileLimit)
            throw const ServiceException(
              'FILE-LIMIT',
              'Job index line exceeds 1 MiB.',
            );
        }
      }
    }
  } on FileSystemException catch (e) {
    throw ServiceException('FILE-READ', 'Cannot read jobs index: ${e.message}');
  } on FormatException {
    throw const ServiceException(
      'INVALID-DATA',
      'Job index is not valid UTF-8.',
    );
  }
}
