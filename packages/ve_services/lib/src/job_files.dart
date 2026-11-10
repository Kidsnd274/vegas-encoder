import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ve_core/ve_core.dart';
import 'api.dart';
import 'models.dart';
import 'storage.dart';
import 'storage_validation.dart';

class FileJobRepository implements JobRepository, JobLogs, JobIndexHealth {
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
  int skippedIndexLines = 0;

  /// How often [list] read the index file (C5: an unchanged index is not reread).
  int indexReads = 0;

  // C5: the index as last read. Unchanged size and time return the identical
  // list; a larger file parses only the bytes after [end]; anything else
  // reparses the whole file.
  ({int size, DateTime modified, int end})? _indexStamp;
  final Map<String, JobIndexEntry> _indexEntries = {};
  List<JobIndexEntry>? _indexList;
  int _indexSkipped = 0;
  String? _indexPrint;

  /// The first and last 64 bytes before [end], to tell an append from a rewrite.
  Future<String?> _fingerprint(int end) async {
    try {
      final file = await File(_index).open();
      try {
        final head = await file.read(end < 64 ? end : 64);
        await file.setPosition(end < 64 ? 0 : end - 64);
        final tail = await file.read(end < 64 ? end : 64);
        return '${base64.encode(head)}|${base64.encode(tail)}';
      } finally {
        await file.close();
      }
    } on FileSystemException {
      return null;
    }
  }

  Future<bool> _sameFingerprint(int end) async {
    final now = await _fingerprint(end);
    return now != null && now == _indexPrint;
  }

  @override
  Future<List<JobIndexEntry>> list() async {
    final stat = await File(_index).stat();
    if (stat.type == FileSystemEntityType.notFound) {
      _indexStamp = null;
      skippedIndexLines = 0;
      return _recover();
    }
    final last = _indexStamp;
    if (last != null && _indexList != null && last.size == stat.size && last.modified == stat.modified) {
      skippedIndexLines = _indexSkipped;
      return _indexList!;
    }
    // A rewrite to a larger file is not an append: the bytes already read must match.
    final append =
        last != null && _indexList != null && stat.size > last.size && await _sameFingerprint(last.end);
    if (!append) {
      _indexEntries.clear();
      _indexSkipped = 0;
    }
    indexReads++;
    final read = await _completeLines(_index, append ? last.end : 0);
    for (final raw in read.lines) {
      // A CRLF edit leaves "\r"; trim it rather than calling the line malformed.
      final line = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
      if (line.trim().isEmpty) continue;
      try {
        final entry = decodeIndex(decodeJson(line));
        _indexEntries[entry.id.toLowerCase()] = entry;
      } on ServiceException {
        _indexSkipped++; // Contract 3.3: counted, never fatal.
      }
    }
    _indexStamp = (size: stat.size, modified: stat.modified, end: read.end);
    _indexPrint = await _fingerprint(read.end);
    _indexList = _sort(_indexEntries.values.toList());
    skippedIndexLines = _indexSkipped;
    return _indexList!;
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
    durationSec: record.durationSec ?? record.media?.durationSec,
    elapsedSec: record.elapsedSec,
    realtime: record.realtime,
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
  @override
  Future<void> rebuildIndex() => withFileLock('$_index.lock', () async {
    _indexStamp = null; // The replacement is reread in full.
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
      _indexStamp = null;
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

/// The complete lines from byte [from] on, and the byte just past the last
/// one. A truncated last line is ignored (and read again once complete).
/// Buffers never exceed the per-line limit, even if a writer forgets newlines.
Future<({List<String> lines, int end})> _completeLines(String path, int from) async {
  final lines = <String>[];
  final pending = BytesBuilder(copy: false);
  var offset = from, end = from;
  try {
    await for (final chunk in File(path).openRead(from)) {
      var start = 0;
      while (true) {
        final newline = chunk.indexOf(10, start);
        if (newline < 0) break;
        pending.add(chunk.sublist(start, newline));
        lines.add(utf8.decode(pending.takeBytes()));
        end = offset + newline + 1;
        start = newline + 1;
      }
      if (start < chunk.length) pending.add(chunk.sublist(start));
      if (pending.length > jsonFileLimit)
        throw const ServiceException(
          'FILE-LIMIT',
          'Job index line exceeds 1 MiB.',
        );
      offset += chunk.length;
    }
    return (lines: lines, end: end);
  } on FileSystemException catch (e) {
    throw ServiceException('FILE-READ', 'Cannot read jobs index: ${e.message}');
  } on FormatException {
    throw const ServiceException(
      'INVALID-DATA',
      'Job index is not valid UTF-8.',
    );
  }
}
