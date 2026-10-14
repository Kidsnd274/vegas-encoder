import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:ve_core/ve_core.dart';
import 'api.dart';

const jsonFileLimit = 1024 * 1024;

/// Injectable roots keep tests and support tools away from the user's data.
class ServicePaths {
  ServicePaths({required String roaming, required String local})
    : roaming = Directory(roaming).absolute.path,
      local = Directory(local).absolute.path;
  factory ServicePaths.windows() {
    if (!Platform.isWindows) {
      throw const ServiceException(
        'UNSUPPORTED-PLATFORM',
        'Windows is required.',
      );
    }
    final roaming = Platform.environment['APPDATA'];
    final local = Platform.environment['LOCALAPPDATA'];
    if (roaming == null || local == null) {
      throw const ServiceException(
        'DATA-ROOT',
        'Windows user data roots are unavailable.',
      );
    }
    return ServicePaths(
      roaming: joinPath(roaming, 'VegasEncoder'),
      local: joinPath(local, 'VegasEncoder'),
    );
  }
  final String roaming;
  final String local;
  String get machine => joinPath(roaming, 'machine.json');
  String get library => joinPath(roaming, 'library');
  String get preferences => joinPath(library, 'preferences.json');
  String get cache => joinPath(local, 'cache');
  String get jobs => joinPath(local, 'jobs');
}

String joinPath(String parent, String child) =>
    '$parent${Platform.pathSeparator}$child';

String canonicalJson(Object? value) {
  Object? ordered(Object? node) {
    if (node is Map) {
      final keys = node.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: ordered(node[key])};
    }
    if (node is List) return node.map(ordered).toList();
    return node;
  }

  return jsonEncode(ordered(value));
}

String safeId(String id) {
  // Windows is case-insensitive; names ending in a dot and DOS devices alias
  // other paths even with an extension. Never use an unchecked ID as a path.
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(id) ||
      id.endsWith('.') ||
      RegExp(
        r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
        caseSensitive: false,
      ).hasMatch(id)) {
    throw const ServiceException(
      'INVALID-ID',
      'Use a non-reserved preset or job ID.',
    );
  }
  return id;
}

Never invalid(String message) =>
    throw ServiceException('INVALID-DATA', message);

/// Storage syntax checks only. Recipe/session rules remain in the native core.
JsonMap decodeJson(String text) {
  try {
    return _decodeJson(text);
  } on ServiceException {
    rethrow;
  } catch (e) {
    throw ServiceException('INVALID-DATA', 'Invalid JSON: $e');
  }
}

JsonMap _decodeJson(String text) {
  if (utf8.encode(text).length > jsonFileLimit) {
    throw const ServiceException('FILE-LIMIT', 'JSON exceeds 1 MiB.');
  }
  // Dart's decoder overwrites duplicate keys and rounds oversized integers.
  // Preflight tokens before decoding, including escaped duplicate key names.
  final scopes = <Set<String>?>[];
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '{' || c == '[') {
      scopes.add(c == '{' ? <String>{} : null);
      if (scopes.length > 64) invalid('JSON nesting exceeds 64 levels.');
    } else if (c == '}' || c == ']') {
      if (scopes.isEmpty) invalid('Unbalanced JSON.');
      scopes.removeLast();
    } else if (c == '"') {
      final start = i++;
      for (; i < text.length && text[i] != '"'; i++) {
        if (text[i] == '\\') i++;
      }
      if (i >= text.length) invalid('Unterminated JSON string.');
      var next = i + 1;
      while (next < text.length && ' \r\n\t'.contains(text[next])) {
        next++;
      }
      if (next < text.length &&
          text[next] == ':' &&
          scopes.isNotEmpty &&
          scopes.last != null) {
        final key = jsonDecode(text.substring(start, i + 1)) as String;
        if (!scopes.last!.add(key)) invalid('Duplicate JSON key: $key.');
      }
    } else if (c == '-' || (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57)) {
      final start = i;
      while (i + 1 < text.length &&
          RegExp(r'[0-9eE+.-]').hasMatch(text[i + 1])) {
        i++;
      }
      final token = text.substring(start, i + 1);
      if (RegExp(r'^-?\d+$').hasMatch(token)) {
        final integer = BigInt.parse(token);
        if (integer < BigInt.parse('-9223372036854775808') ||
            integer > BigInt.parse('9223372036854775807')) {
          invalid('JSON integer exceeds signed 64-bit bounds.');
        }
      }
    }
  }
  try {
    final result = jsonMap(jsonDecode(text));
    checkJsonTree(result);
    return result;
  } on ServiceException {
    rethrow;
  } catch (e) {
    throw ServiceException('INVALID-DATA', 'Invalid JSON: $e');
  }
}

void checkJsonTree(Object? value, [int depth = 0]) {
  if (depth > 64) invalid('JSON nesting exceeds 64 levels.');
  if (value is num && !value.isFinite) invalid('Non-finite JSON number.');
  if (value is Map) {
    for (final item in value.values) {
      checkJsonTree(item, depth + 1);
    }
  } else if (value is List) {
    for (final item in value) {
      checkJsonTree(item, depth + 1);
    }
  }
}

Future<List<int>?> readBytes(String path, {int limit = jsonFileLimit}) async {
  RandomAccessFile? handle;
  try {
    handle = await File(path).open();
    if (await handle.length() > limit) {
      throw ServiceException('FILE-LIMIT', 'File exceeds $limit bytes: $path');
    }
    // Read at most limit+1 even if a non-cooperating writer grows the file.
    final bytes = await handle.read(limit + 1);
    if (bytes.length > limit)
      throw const ServiceException(
        'FILE-LIMIT',
        'File grew past its size limit.',
      );
    return bytes;
  } on FileSystemException catch (e) {
    if (e.osError?.errorCode == 2 || e.osError?.errorCode == 3) return null;
    throw ServiceException('FILE-READ', 'Cannot read $path: ${e.message}');
  } finally {
    await handle?.close();
  }
}

Future<JsonMap?> readJson(String path) async {
  final bytes = await readBytes(path);
  if (bytes == null) return null;
  try {
    return decodeJson(utf8.decode(bytes));
  } on ServiceException {
    rethrow;
  } catch (e) {
    throw ServiceException('INVALID-DATA', 'Invalid UTF-8 JSON in $path: $e');
  }
}

final _random = Random.secure();
String _nonce() =>
    '${pid}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';

Future<void> atomicWrite(String path, String text) async {
  final bytes = utf8.encode(text);
  if (bytes.length > jsonFileLimit)
    throw const ServiceException('FILE-LIMIT', 'File exceeds 1 MiB.');
  final temporary = File('$path.${_nonce()}.tmp');
  try {
    await File(path).parent.create(recursive: true);
    await temporary.create(exclusive: true);
    await temporary.writeAsBytes(bytes, flush: true);
    // Windows Dart uses MoveFileExW(REPLACE_EXISTING | WRITE_THROUGH).
    // Adjacent file means one volume; never delete the old value first.
    final deadline = DateTime.now().add(const Duration(milliseconds: 500));
    while (true) {
      try {
        await temporary.rename(path);
        break;
      } on FileSystemException catch (e) {
        // Dart readers transiently hold Windows handles that deny delete-share.
        // Retry sharing/lock collisions only; never delete the prior value.
        if (![32, 33].contains(e.osError?.errorCode) ||
            DateTime.now().isAfter(deadline))
          rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  } on FileSystemException catch (e) {
    throw ServiceException('FILE-WRITE', 'Cannot replace $path: ${e.message}');
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}

/// Separate persistent lock inode survives atomic replacement of the data file.
/// Nonblocking OS byte lock with a deadline works across Windows processes and
/// isolates, and releases automatically when a crashed writer's handle closes.
Future<T> withFileLock<T>(
  String path,
  Future<T> Function() action, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  RandomAccessFile? handle;
  var locked = false;
  final deadline = DateTime.now().add(timeout);
  try {
    await File(path).parent.create(recursive: true);
    handle = await File(path).open(mode: FileMode.append);
    while (!locked) {
      try {
        await handle.lock(FileLock.exclusive, 0, 1);
        locked = true;
      } on FileSystemException catch (e) {
        if (![32, 33].contains(e.osError?.errorCode)) rethrow;
        if (DateTime.now().isAfter(deadline)) {
          throw const ServiceException(
            'STORE-BUSY',
            'Another writer is busy. Try again.',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
    return await action();
  } on FileSystemException catch (e) {
    throw ServiceException(
      'FILE-WRITE',
      'Repository operation failed: ${e.message}',
    );
  } finally {
    try {
      if (locked) await handle?.unlock(0, 1);
    } finally {
      await handle?.close();
    }
  }
}

/// Polling observes atomic renames reliably, including when the root was absent
/// at subscription time. Each listener owns its timer and cancellation lifetime.
/// Failed reads emit an error, retaining the last successfully emitted snapshot.
Stream<T> watchSnapshots<T>(
  Future<T> Function() read, {
  Duration interval = const Duration(milliseconds: 250),
}) => Stream<T>.multi((controller) {
  var cancelled = false;
  var paused = false;
  var running = false;
  Future<void>? inFlight;
  String? previous;
  Future<void> tick() async {
    if (cancelled || paused || running) return;
    running = true;
    final completion = Completer<void>();
    inFlight = completion.future;
    try {
      final snapshot = await read();
      final encoded = jsonEncode(
        snapshot,
        toEncodable: (v) => (v as JsonModel).data,
      );
      if (!cancelled && previous != encoded) {
        previous = encoded;
        controller.add(snapshot);
      }
    } catch (e, stack) {
      if (!cancelled) controller.addError(e, stack);
    } finally {
      running = false;
      completion.complete();
    }
  }

  final timer = Timer.periodic(interval, (_) => tick());
  controller.onPause = () {
    paused = true;
  };
  controller.onResume = () {
    paused = false;
    unawaited(tick());
  };
  controller.onCancel = () async {
    cancelled = true;
    timer.cancel();
    await inFlight;
  };
  unawaited(tick());
});

void major(JsonMap data, String key) {
  validateExtensions(data);
  if (data[key] is! int || data[key] != 1) {
    throw ServiceException(
      'UNSUPPORTED-VERSION',
      'Unsupported $key version; source data is preserved.',
    );
  }
}

void validateExtensions(JsonMap data) {
  if (data.containsKey('extensions') && data['extensions'] is! Map)
    invalid('extensions must be an object.');
}

void stringField(
  JsonMap data,
  String key, {
  bool required = true,
  bool nullable = false,
}) {
  if (!required && !data.containsKey(key)) return;
  final value = data[key];
  if (nullable && value == null) return;
  if (value is! String || value.contains('\u0000'))
    invalid('$key must be text without NUL.');
}

void intField(
  JsonMap data,
  String key, {
  bool required = true,
  int min = 0,
  bool nullable = false,
}) {
  if (!required && !data.containsKey(key)) return;
  if (nullable && data[key] == null) return;
  if (data[key] is! int || (data[key] as int) < min)
    invalid('$key must be an integer >= $min.');
}

void numberField(
  JsonMap data,
  String key, {
  bool required = false,
  bool nullable = false,
  double min = 0,
}) {
  if (!required && !data.containsKey(key)) return;
  final value = data[key];
  if (nullable && value == null) return;
  if (value is! num || !value.isFinite || value < min)
    invalid('$key must be a finite number >= $min.');
}

void boolField(JsonMap data, String key) {
  if (data.containsKey(key) && data[key] is! bool)
    invalid('$key must be boolean.');
}

void timestamp(JsonMap data, String key) {
  stringField(data, key);
  final text = data[key] as String;
  final parsed = DateTime.tryParse(text);
  if (!RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z$').hasMatch(text) ||
      parsed == null ||
      parsed.toUtc().toIso8601String().substring(0, 19) !=
          text.substring(0, 19))
    invalid('$key must be a UTC timestamp.');
}

JsonMap objectField(JsonMap data, String key) {
  if (data[key] is! Map) invalid('$key must be an object.');
  return jsonMap(data[key]);
}

List<Object?> arrayField(JsonMap data, String key) {
  if (data[key] is! List) invalid('$key must be an array.');
  return data[key] as List<Object?>;
}

void strings(JsonMap data, String key) {
  if (arrayField(data, key).any((v) => v is! String))
    invalid('$key must contain strings.');
}
