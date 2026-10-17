import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:ve_core/ve_core.dart';
import 'api.dart';

@Native<Int32 Function(Pointer<Uint8>, Uint32)>(symbol: 've_gpu_snapshot')
external int _snapshot(Pointer<Uint8> buffer, int capacity);

class GpuSnapshot extends JsonModel {
  GpuSnapshot({
    required String fingerprint,
    required bool cacheable,
    List<JsonMap> adapters = const [],
  }) : super({
         'fingerprint': fingerprint,
         'cacheable': cacheable,
         'adapters': adapters,
       });
  GpuSnapshot.fromJson(super.json);
  String get fingerprint => data['fingerprint'] as String;
  bool get cacheable => data['cacheable'] as bool;
  List<JsonMap> get adapters => List.unmodifiable(jsonMaps(data['adapters']));
}

abstract interface class GpuIdentity {
  Future<GpuSnapshot> read();
}

class WindowsGpuIdentity implements GpuIdentity {
  @override
  Future<GpuSnapshot> read() => Isolate.run(_readGpu);
}

GpuSnapshot _readGpu() {
  final buffer = calloc<Uint8>(65536);
  try {
    final length = _snapshot(buffer, 65536);
    if (length < 0 || length > 65536)
      throw const ServiceException(
        'GPU-IDENTITY',
        'Cannot read Windows GPU/driver identity.',
      );
    final data = jsonMap(jsonDecode(utf8.decode(buffer.asTypedList(length))));
    final adapters = jsonMaps(data['adapters']);
    adapters.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    return GpuSnapshot(
      fingerprint: sha256.convert(utf8.encode(jsonEncode(adapters))).toString(),
      cacheable: data['cacheable'] == true,
      adapters: adapters,
    );
  } finally {
    calloc.free(buffer);
  }
}

class FakeGpuIdentity implements GpuIdentity {
  FakeGpuIdentity(this.snapshot);
  GpuSnapshot snapshot;
  @override
  Future<GpuSnapshot> read() async => snapshot;
}

// Same machine-services asset; this scans directory metadata only, not GPU state.
@Native<Int32 Function(Pointer<Uint16>, Uint32, Pointer<Uint8>, Uint32)>(
  symbol: 've_library_metadata',
)
external int _libraryMetadata(
  Pointer<Uint16> directory,
  int length,
  Pointer<Uint8> buffer,
  int capacity,
);

@Native<Int32 Function(Pointer<Uint8>, Uint32, Pointer<Uint8>, Uint32)>(
  symbol: 've_vegas_installations',
)
external int _vegasInstallations(
  Pointer<Uint8> options,
  int length,
  Pointer<Uint8> buffer,
  int capacity,
);

/// System inspection stays off the UI isolate, independent of the product core.
Future<String> readVegasInstallationJson(String options) => Isolate.run(() {
  final bytes = utf8.encode(options);
  if (bytes.length > 65536)
    throw const ServiceException(
      'VEGAS-STATUS-LIMIT',
      'Too many candidate directory paths to inspect.',
    );
  final input = calloc<Uint8>(bytes.length);
  final output = calloc<Uint8>(1048576);
  try {
    input.asTypedList(bytes.length).setAll(0, bytes);
    final length = _vegasInstallations(input, bytes.length, output, 1048576);
    if (length < 0 || length > 1048576)
      throw ServiceException(
        'VEGAS-STATUS',
        'Cannot inspect VEGAS installations (native status $length).',
      );
    return utf8.decode(output.asTypedList(length));
  } finally {
    calloc.free(input);
    calloc.free(output);
  }
});

/// Null means the bounded fast path cannot represent this directory; use legacy
/// enumeration in a worker. Other failures must not hide a bad library.
String? readLibraryDirectoryMetadata(String directory) {
  final normalized = Directory(
    directory,
  ).absolute.uri.normalizePath().toFilePath();
  final path = normalized.toNativeUtf16(allocator: calloc);
  Pointer<Uint8> buffer = nullptr;
  try {
    buffer = calloc<Uint8>(1048576);
    final length = _libraryMetadata(
      path.cast<Uint16>(),
      normalized.length,
      buffer,
      1048576,
    );
    if (length == -2) return null;
    if (length < 0 || length > 1048576)
      throw ServiceException(
        'FILE-READ',
        'Cannot enumerate preset library ($length): $directory',
      );
    return utf8.decode(buffer.asTypedList(length));
  } finally {
    if (buffer != nullptr) calloc.free(buffer);
    calloc.free(path);
  }
}
