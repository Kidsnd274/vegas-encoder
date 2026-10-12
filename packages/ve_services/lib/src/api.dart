import 'package:ve_core/ve_core.dart';
import 'models.dart';

class ServiceException implements Exception {
  const ServiceException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'ServiceException($code): $message';
}

/// No service probes as a side effect of list/read/watch. App explicitly calls
/// scan/probe/test, and the DLL never calls these services while rendering.
abstract interface class FFmpegDiscovery {
  Future<List<FFmpegInstallation>> list();
  Stream<List<FFmpegInstallation>> watch();
  Future<List<FFmpegInstallation>> scan();
  Future<FFmpegInstallation> add(String executablePath);
  Future<void> remove(String installationId);
}

abstract interface class FFmpegProbe {
  Stream<ProbeProgress> probe(FFmpegInstallation installation);
  Future<EncoderDetails> encoderDetails(
    FFmpegInstallation installation,
    String encoder,
  );
  Future<void> cancel(String installationId);
}

abstract interface class FFmpegHelpParser {
  int get version;
  EncoderDetails parseEncoderHelp(String text);
  JsonMap parseEncoders(String text);
  JsonMap parseMuxers(String text);
}

abstract interface class HardwareTests {
  Stream<HardwareTestResult> test(
    FFmpegInstallation installation, {
    List<String>? encoders,
    bool force = false,
  });
  Future<void> cancel(String installationId);
}

abstract interface class CapabilityCache {
  Future<FFmpegCapabilities?> read(String identityKey);
  Future<void> write(FFmpegCapabilities capabilities);
  Future<void> invalidate(String identityKey);
}

abstract interface class PresetLibrary {
  Future<List<Preset>> list();
  Stream<List<Preset>> watch();
  Future<Preset?> get(String id, {int? revision});

  /// expectedRevision null creates; otherwise compare-and-swap. Built-ins are
  /// read-only. A duplicate is a new ID with origin "builtin/<id>".
  Future<Preset> save(Preset preset, {int? expectedRevision});
  Future<void> delete(String id, {required int expectedRevision});
  Future<Preset> importPreset(String jsonText, {required String newId});
  Future<String> exportPreset(String id);
}

abstract interface class MachineSettingsRepository {
  Future<MachineSettings> read();
  Stream<MachineSettings> watch();
  Future<MachineSettings> save(
    MachineSettings settings, {
    required int expectedRevision,
  });
}

abstract interface class JobRepository {
  Future<List<JobIndexEntry>> list();
  Stream<List<JobIndexEntry>> watch();
  Future<JobRecord?> get(String id);
}

abstract interface class LiveRenderStatusReader {
  Future<LiveRenderStatus?> read(String file);

  /// Missing startup file yields null. Malformed replacement retains the last
  /// valid snapshot; stale snapshots never imply success/cancel/failure.
  Stream<LiveRenderStatus?> watch(String file);
}

abstract interface class EditSessionService {
  Future<EditSessionRequest> readRequest(String directory);

  /// One final result, atomic replace. Apply requires recipe; cancel carries no
  /// recipe or origin (omitted or null).
  Future<void> writeResult(String directory, EditSessionResult result);
}
