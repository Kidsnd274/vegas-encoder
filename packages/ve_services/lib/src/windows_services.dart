import 'package:ve_core/ve_core.dart';
import 'api.dart';
import 'storage.dart';
import 'file_repositories.dart';
import 'job_files.dart';
import 'ffmpeg_discovery.dart';
import 'ffmpeg_probe.dart';
import 'ffmpeg_parser.dart';
import 'hardware_services.dart';
import 'preset_tests.dart';
import 'preset_transfer.dart';
import 'process_runner.dart';
import 'windows_gpu.dart';

/// One composition root for the app's C3 providers. It does not scan, probe,
/// create directories or launch processes when constructed.
class WindowsServices {
  factory WindowsServices({
    VeCore? core,
    ServicePaths? paths,
    ProcessExecutor? executor,
    GpuIdentity? gpuIdentity,
    FFmpegCandidateFinder? candidateFinder,
  }) {
    final productCore = core ?? NativeVeCore();
    final roots = paths ?? ServicePaths.windows();
    final runner = executor ?? WindowsProcessExecutor();
    final gpu = gpuIdentity ?? WindowsGpuIdentity();
    final settings = FileMachineSettingsRepository(paths: roots);
    final rawCache = FileCapabilityCache(
      paths: roots,
      parserVersion: WindowsFFmpegHelpParser().version,
    );
    final cache = GpuAwareCapabilityCache(backend: rawCache, gpu: gpu);
    final discovery = WindowsFFmpegDiscovery(
      settings: settings,
      runner: runner,
      finder: candidateFinder,
      capabilities: cache,
    );
    final hardware = WindowsHardwareTests(
      runner: runner,
      cache: rawCache,
      discovery: discovery,
      gpu: gpu,
    );
    final library = FilePresetLibrary(core: productCore, paths: roots);
    return WindowsServices._(
      productCore,
      settings,
      rawCache,
      cache,
      discovery,
      hardware,
      WindowsFFmpegProbe(
        core: productCore,
        runner: runner,
        cache: rawCache,
        discovery: discovery,
        hardware: hardware,
      ),
      WindowsPresetTests(
        core: productCore,
        runner: runner,
        cache: cache,
        paths: roots,
      ),
      library,
      FileJobRepository(core: productCore, paths: roots),
    );
  }
  WindowsServices._(
    this._core,
    this.machineSettings,
    this.rawCache,
    this.capabilityCache,
    this.discovery,
    this.hardwareTests,
    this.probe,
    this.presetTests,
    this.library,
    this.jobs,
  );
  final FileMachineSettingsRepository machineSettings;
  final VeCore _core;
  EditSessionService get editSessions {
    final core = _core;
    if (core is! NativeVeCore)
      throw const ServiceException(
        'CORE-CONTRACT',
        'Native core is required for real edit sessions.',
      );
    return FileEditSessionService(core: core);
  }

  final FileCapabilityCache rawCache;
  final CapabilityCache capabilityCache;
  final WindowsFFmpegDiscovery discovery;
  final WindowsHardwareTests hardwareTests;
  final WindowsFFmpegProbe probe;
  final WindowsPresetTests presetTests;
  final FilePresetLibrary library;
  final FileJobRepository jobs;
  LiveRenderStatusReader get liveStatus => FileLiveRenderStatusReader();
  PresetTransfer get presetTransfer => PresetTransfer(library);
  FileReveal get fileReveal => WindowsFileReveal();
}
