import 'dart:async';
import 'package:ve_core/ve_core.dart';
import 'api.dart';
import 'models.dart';
import 'file_repositories.dart';
import 'ffmpeg_discovery.dart';
import 'ffmpeg_identity.dart';
import 'ffmpeg_parser.dart';
import 'process_runner.dart';
import 'operations.dart';
import 'windows_gpu.dart';

bool isHardwareEncoder(String name) => RegExp(
  r'_(?:nvenc|qsv|amf|mf|vaapi|v4l2m2m|videotoolbox|vulkan|d3d12va|rkmpp|mediacodec|omx)$',
).hasMatch(name);

bool _fresh(
  Object? data,
  String fingerprint,
  String identityKey,
  DateTime now,
) {
  if (data is! Map ||
      data['gpuFingerprint'] != fingerprint ||
      data['identityKey'] != identityKey)
    return false;
  final tested = DateTime.tryParse(data['testedAt'] as String? ?? '');
  return tested != null &&
      !tested.isAfter(now) &&
      now.difference(tested) < const Duration(days: 30);
}

class GpuAwareCapabilityCache implements CapabilityCache {
  GpuAwareCapabilityCache({
    required this.backend,
    required this.gpu,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final FileCapabilityCache backend;
  final GpuIdentity gpu;
  final DateTime Function() now;
  @override
  Future<FFmpegCapabilities?> read(String key) async {
    final value = await backend.read(key);
    if (value == null || value.hardware.isEmpty) return value;
    GpuSnapshot? snapshot;
    try {
      snapshot = await gpu.read();
    } on ServiceException {
      /* results remain unknown */
    }
    final hardware = <String, Object?>{};
    final encoders = value.encoders;
    for (final entry in value.hardware.entries) {
      final current =
          snapshot != null &&
          snapshot.cacheable &&
          _fresh(entry.value, snapshot.fingerprint, key, now().toUtc());
      final availability = current
          ? entry.value
          : EncoderAvailability(
              state: 'unknown',
              reason: 'Hardware test expired or GPU/driver changed.',
            ).data;
      hardware[entry.key] = availability;
      if (encoders[entry.key] is Map)
        encoders[entry.key] = {
          ...jsonMap(encoders[entry.key]),
          'availability': availability,
        };
    }
    return value.copyWith(
      encoders: encoders,
      hardware: hardware,
      gpuFingerprint: snapshot?.fingerprint ?? '',
    );
  }

  @override
  Future<void> write(FFmpegCapabilities value) => backend.write(value);
  @override
  Future<void> invalidate(String key) => backend.invalidate(key);
}

class WindowsHardwareTests implements HardwareTests {
  WindowsHardwareTests({
    required this.runner,
    required this.cache,
    required this.discovery,
    required this.gpu,
    WindowsFFmpegHelpParser? parser,
    DateTime Function()? now,
  }) : parser = parser ?? WindowsFFmpegHelpParser(),
       now = now ?? DateTime.now;
  final ProcessExecutor runner;
  final FileCapabilityCache cache;
  final WindowsFFmpegDiscovery discovery;
  final GpuIdentity gpu;
  final WindowsFFmpegHelpParser parser;
  final DateTime Function() now;
  final _operations = OperationRegistry();
  @override
  Future<void> cancel(String id) => _operations.cancel(id);
  @override
  Stream<HardwareTestResult> test(
    FFmpegInstallation installation, {
    List<String>? encoders,
    bool force = false,
  }) {
    late StreamController<HardwareTestResult> stream;
    ServiceOperation? operation;
    stream = StreamController(
      onListen: () {
        final op = operation = _operations.begin(installation.id);
        unawaited(() async {
          try {
            await requireCurrentInstallation(
              installation,
              parser.version,
              op.token,
            );
            await for (final result in qualify(
              installation,
              op.token,
              encoders: encoders,
              force: force,
            )) {
              if (!stream.isClosed) stream.add(result);
            }
          } catch (e, stack) {
            if (!stream.isClosed) stream.addError(e, stack);
          } finally {
            _operations.finish(installation.id, op);
            unawaited(stream.close());
          }
        }());
      },
      onCancel: () async {
        final op = operation;
        if (op != null) {
          op.token.cancel();
          await op.done.future;
        }
      },
    );
    return stream.stream;
  }

  Stream<HardwareTestResult> qualify(
    FFmpegInstallation installation,
    CancellationToken token, {
    List<String>? encoders,
    bool force = false,
  }) async* {
    final capabilities = await cache.read(installation.identity.key);
    if (capabilities == null)
      throw const ServiceException(
        'PROBE-REQUIRED',
        'Probe this installation before testing hardware.',
      );
    final snapshot = await gpu.read();
    token.check();
    final selected =
        encoders ??
        capabilities.encoders.entries
            .where(
              (e) =>
                  isHardwareEncoder(e.key) &&
                  jsonMap(e.value)['kind'] == 'video',
            )
            .map((e) => e.key)
            .toList();
    for (final encoder in selected) {
      if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(encoder) ||
          !isHardwareEncoder(encoder))
        throw const ServiceException(
          'HARDWARE-ENCODER',
          'Select a listed hardware encoder.',
        );
      token.check();
      if (capabilities.encoders[encoder] is Map &&
          jsonMap(capabilities.encoders[encoder])['kind'] != 'video')
        throw const ServiceException(
          'HARDWARE-ENCODER',
          'Hardware smoke tests apply to video encoders.',
        );
      final old = capabilities.hardware[encoder];
      if (!force &&
          snapshot.cacheable &&
          _fresh(
            old,
            snapshot.fingerprint,
            installation.identity.key,
            now().toUtc(),
          )) {
        final cachedResult = HardwareTestResult.fromJson(jsonMap(old));
        await cache.update(installation.identity.key, (current) {
          if (current == null)
            throw const ServiceException(
              'PROBE-REQUIRED',
              'Cache was removed during testing.',
            );
          final entries = current.encoders;
          entries[encoder] = {
            ...jsonMap(entries[encoder]),
            'availability': old,
          };
          return current.copyWith(encoders: entries);
        });
        await discovery.updateRecord(
          installation.id,
          installation.identity.key,
          (record) => record.copyWith(
            availability: {...record.availability, encoder: old},
          ),
        );
        yield cachedResult;
        continue;
      }
      HardwareTestResult result;
      final entry = capabilities.encoders[encoder];
      if (entry is! Map) {
        result = HardwareTestResult(
          encoder: encoder,
          state: 'missing',
          reason: 'Encoder is not listed by this FFmpeg.',
          testedAt: now().toUtc().toIso8601String(),
          identityKey: installation.identity.key,
          gpuFingerprint: snapshot.fingerprint,
        );
      } else {
        var detail = jsonMap(entry);
        if (!detail.containsKey('pixelFormats')) {
          final help = await runner.run(installation.path, [
            '-hide_banner',
            '-h',
            'encoder=$encoder',
          ], cancellation: token);
          help.requireSuccess('Hardware encoder help');
          detail = {
            ...detail,
            ...parser.parseEncoderHelp(help.stdout + help.stderr).data,
          };
        }
        final formats = (detail['pixelFormats'] as List? ?? []).cast<String>();
        final surface = formats.contains('vulkan')
            ? 'vulkan'
            : formats.contains('d3d12')
            ? 'd3d12'
            : null;
        final device = surface == 'd3d12' ? 'd3d12va' : surface;
        final extra = encoder.endsWith('_mf')
            ? <String>['-hw_encoding', '1']
            : <String>[];
        final eight = await _encode(
          installation,
          encoder,
          formats.contains('nv12') || surface != null ? 'nv12' : 'yuv420p',
          token,
          surface: surface,
          device: device,
          extra: extra,
        );
        ProcessOutput? ten;
        final tenFormat = formats.contains('p010le')
            ? 'p010le'
            : formats.contains('yuv420p10le')
            ? 'yuv420p10le'
            : null;
        if (eight.exitCode == 0 &&
            !eight.timedOut &&
            !eight.outputLimit &&
            tenFormat != null)
          ten = await _encode(
            installation,
            encoder,
            tenFormat,
            token,
            surface: surface,
            device: device,
            extra: extra,
          );
        final ok = eight.exitCode == 0 && !eight.timedOut && !eight.outputLimit;
        final tenOk =
            ten != null &&
            ten.exitCode == 0 &&
            !ten.timedOut &&
            !ten.outputLimit;
        final stderr = [
          eight.stderr,
          if (ten != null && !tenOk) '10-bit: ${ten.stderr}',
        ].where((s) => s.isNotEmpty).join('\n');
        result = HardwareTestResult(
          encoder: encoder,
          state: ok ? 'ok' : 'failed',
          tenBit: tenOk,
          reason: ok
              ? (tenFormat != null && !tenOk
                    ? '8-bit test passed; 10-bit test failed.'
                    : 'One-frame test passed on this GPU/driver.')
              : _reason(eight),
          failureClass: ok ? null : _failure(eight),
          stderr: stderr.length > 16384
              ? stderr.substring(stderr.length - 16384)
              : stderr,
          testedAt: now().toUtc().toIso8601String(),
          identityKey: installation.identity.key,
          gpuFingerprint: snapshot.fingerprint,
          extensions: {
            'eightBitExitCode': eight.exitCode,
            'tenBitExitCode': ten?.exitCode,
            'tenBitFailureClass': ten != null && !tenOk ? _failure(ten) : null,
            'size': [320, 192],
            'frames': 1,
            'hardwareSurface': surface,
            'hardwareOnly':
                !encoder.endsWith('_mf') || extra.contains('-hw_encoding'),
          },
        );
      }
      token.check();
      await cache.update(installation.identity.key, (current) {
        if (current == null)
          throw const ServiceException(
            'PROBE-REQUIRED',
            'Capability cache was removed during testing.',
          );
        final hardware = current.hardware;
        hardware[encoder] = {
          ...result.data,
          'detail': result.stderr,
          'note': result.reason,
        };
        final entries = current.encoders;
        if (entries[encoder] is Map)
          entries[encoder] = {
            ...jsonMap(entries[encoder]),
            'availability': hardware[encoder],
          };
        return current.copyWith(
          hardware: hardware,
          encoders: entries,
          gpuFingerprint: snapshot.fingerprint,
        );
      });
      await discovery.updateRecord(
        installation.id,
        installation.identity.key,
        (record) => record.copyWith(
          availability: {
            ...record.availability,
            encoder: EncoderAvailability(
              state: result.state,
              reason: result.reason,
              detail: result.stderr,
              note: result.tenBit
                  ? '10-bit test passed.'
                  : '10-bit has not passed.',
              extensions: {
                'testedAt': result.testedAt,
                'gpuFingerprint': snapshot.fingerprint,
                'tenBit': result.tenBit,
              },
            ).data,
          },
        ),
      );
      yield result;
    }
  }

  Future<ProcessOutput> _encode(
    FFmpegInstallation installation,
    String encoder,
    String format,
    CancellationToken token, {
    String? surface,
    String? device,
    List<String> extra = const [],
  }) async {
    final result = await runner.run(
      installation.path,
      [
        '-hide_banner',
        '-nostdin',
        '-loglevel',
        'error',
        if (device != null) ...[
          '-init_hw_device',
          '$device=ve_probe:0',
          '-filter_hw_device',
          've_probe',
        ],
        '-f',
        'lavfi',
        '-i',
        'color=c=black:s=320x192:r=30:d=0.1,format=$format',
        if (surface != null) ...['-vf', 'hwupload'],
        '-frames:v',
        '1',
        '-pix_fmt',
        '+${surface ?? format}',
        '-c:v',
        encoder,
        ...extra,
        '-f',
        'null',
        '-',
      ],
      cancellation: token,
      timeout: const Duration(seconds: 10),
    );
    token.check();
    return result;
  }

  String _reason(ProcessOutput result) {
    if (result.timedOut) return 'Hardware test timed out; child killed.';
    if (result.outputLimit)
      return 'Hardware test exceeded its diagnostic limit.';
    return result.stderr
            .split('\n')
            .where((s) => s.trim().isNotEmpty)
            .firstOrNull ??
        'FFmpeg exited ${result.exitCode}.';
  }

  String _failure(ProcessOutput result) {
    if (result.timedOut) return 'timeout';
    final text = result.stderr.toLowerCase();
    if (RegExp(
      r'cannot load|could not load|dll.*(?:failed|not found)|library.*not found',
    ).hasMatch(text))
      return 'runtime-missing';
    if (RegExp(
      r'no device|no capable|no nvenc capable|mfx session|failed to initialise|failed to initialize|no.*gpu|amf.*failed',
    ).hasMatch(text))
      return 'no-device';
    if (RegExp(
      r'unsupported.*(?:pixel|format)|frame size.*(?:range|invalid)|does not support.*format',
    ).hasMatch(text))
      return 'unsupported-format';
    return 'unknown';
  }
}
