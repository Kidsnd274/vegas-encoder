import 'dart:convert';
import 'dart:ffi';
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
