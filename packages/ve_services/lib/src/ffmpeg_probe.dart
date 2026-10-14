import 'dart:async';
import 'dart:isolate';
import 'package:ve_core/ve_core.dart';
import 'api.dart';
import 'models.dart';
import 'file_repositories.dart';
import 'ffmpeg_discovery.dart';
import 'ffmpeg_identity.dart';
import 'ffmpeg_parser.dart';
import 'hardware_services.dart';
import 'process_runner.dart';
import 'operations.dart';

Future<JsonMap> _parseHelp(String text, String kind) => Isolate.run(
  () => WindowsFFmpegHelpParser()
      .parseEncoderHelp(text)
      .copyWith(kind: kind)
      .toJson(),
);
Future<JsonMap> _parseLists(
  String encoders,
  String muxers,
  String full,
) => Isolate.run(() {
  final parser = WindowsFFmpegHelpParser();
  final start = full.indexOf('AVCodecContext AVOptions:');
  if (start < 0)
    throw const ServiceException(
      'HELP-PARSE',
      'FFmpeg generic codec options are missing.',
    );
  var generic = full.substring(start + 'AVCodecContext AVOptions:'.length);
  final end = RegExp(r'^\S.*AVOptions:', multiLine: true).firstMatch(generic);
  if (end != null) generic = generic.substring(0, end.start);
  return {
    'encoders': parser.parseEncoders(encoders),
    'muxers': parser.parseMuxers(muxers),
    'genericOptions': parser.parseOptions(generic).map((v) => v.data).toList(),
  };
});

class WindowsFFmpegProbe implements FFmpegProbe {
  WindowsFFmpegProbe({
    required this.core,
    required this.runner,
    required this.cache,
    required this.discovery,
    required this.hardware,
    WindowsFFmpegHelpParser? parser,
  }) : parser = parser ?? WindowsFFmpegHelpParser();
  final VeCore core;
  final ProcessExecutor runner;
  final FileCapabilityCache cache;
  final WindowsFFmpegDiscovery discovery;
  final WindowsHardwareTests hardware;
  final WindowsFFmpegHelpParser parser;
  final _operations = OperationRegistry();
  @override
  Future<void> cancel(String id) => _operations.cancel(id);
  @override
  Stream<ProbeProgress> probe(FFmpegInstallation installation) {
    late StreamController<ProbeProgress> controller;
    ServiceOperation? operation;
    controller = StreamController(
      onListen: () {
        final op = operation = _operations.begin(installation.id);
        unawaited(() async {
          final timer = Stopwatch()..start();
          Object? failure;
          void emit(
            String phase, {
            int completed = 0,
            int total = 0,
            String message = '',
            FFmpegCapabilities? capabilities,
          }) {
            if (!controller.isClosed)
              controller.add(
                ProbeProgress(
                  installationId: installation.id,
                  phase: phase,
                  completed: completed,
                  total: total,
                  message: message,
                  capabilities: capabilities,
                ),
              );
          }

          try {
            emit(
              'identity',
              message: 'Checking FFmpeg and FFprobe identities.',
            );
            final checked = await discovery.refresh(installation, op.token);
            emit(
              'lists',
              message: 'Reading encoder, muxer and generic option lists.',
            );
            final results = await Future.wait([
              runner.run(checked.path, [
                '-hide_banner',
                '-encoders',
              ], cancellation: op.token),
              runner.run(checked.path, [
                '-hide_banner',
                '-muxers',
              ], cancellation: op.token),
              runner.run(
                checked.path,
                ['-hide_banner', '-h', 'full'],
                cancellation: op.token,
                stdoutLimit: 4 * 1024 * 1024,
              ),
            ]);
            for (final result in results) {
              result.requireSuccess('FFmpeg capability lists');
            }
            final parsed = await _parseLists(
              results[0].stdout + results[0].stderr,
              results[1].stdout + results[1].stderr,
              results[2].stdout + results[2].stderr,
            );
            op.token.check();
            final encoders = jsonMap(parsed['encoders']);
            final profiles = core.profiles();
            final curated = <String, String>{
              for (final p in profiles.video) p.id: 'video',
              for (final p in profiles.audio) p.id: 'audio',
            };
            final names = curated.keys.where(encoders.containsKey).toList();
            var completed = 0;
            var cursor = 0;
            Future<void> worker() async {
              try {
                while (cursor < names.length) {
                  op.token.check();
                  final name = names[cursor++];
                  final help = await runner.run(checked.path, [
                    '-hide_banner',
                    '-h',
                    'encoder=$name',
                  ], cancellation: op.token);
                  help.requireSuccess('Encoder help');
                  final detail = await _parseHelp(
                    help.stdout + help.stderr,
                    curated[name]!,
                  );
                  if (detail['name'] != name)
                    throw const ServiceException(
                      'HELP-PARSE',
                      'Encoder help returned a different name.',
                    );
                  encoders[name] = {...jsonMap(encoders[name]), ...detail};
                  emit(
                    'details',
                    completed: ++completed,
                    total: names.length,
                    message: name,
                  );
                }
              } catch (e) {
                if (!op.token.cancelled) failure ??= e;
                op.token.cancel();
                rethrow;
              }
            }

            await Future.wait([for (var i = 0; i < 4; i++) worker()]);
            op.token.check();
            for (final entry in encoders.entries.toList()) {
              encoders[entry.key] = {
                ...jsonMap(entry.value),
                'availability': EncoderAvailability(
                  state:
                      isHardwareEncoder(entry.key) &&
                          jsonMap(entry.value)['kind'] == 'video'
                      ? 'unknown'
                      : 'ok',
                  reason:
                      isHardwareEncoder(entry.key) &&
                          jsonMap(entry.value)['kind'] == 'video'
                      ? 'Listed; awaiting a test on this PC.'
                      : 'Listed by this FFmpeg.',
                ).data,
              };
            }
            final libraries = jsonMap(checked.extensions['libraries']);
            final major = int.parse(
              (libraries['libavformat'] as String).split('.').first,
            );
            final capability = FFmpegCapabilities(
              installationId: checked.id,
              identityKey: checked.identity.key,
              parser: parser.version,
              version: checked.version,
              libavformatMajor: major,
              encoders: encoders,
              muxers: jsonMap(parsed['muxers']),
              probedAt: DateTime.now().toUtc().toIso8601String(),
              extensions: {
                'genericOptions': parsed['genericOptions'],
                'configuration': checked.extensions['configuration'],
                'libraries': libraries,
              },
            );
            await cache.update(
              checked.identity.key,
              (previous) => capability.copyWith(
                hardware: previous?.hardware ?? <String, Object?>{},
                gpuFingerprint: previous?.gpuFingerprint ?? '',
              ),
            );
            emit(
              'hardware',
              message: 'Testing listed hardware encoders on this PC.',
            );
            await for (final result in hardware.qualify(checked, op.token)) {
              emit(
                'hardware',
                completed: ++completed,
                message: '${result.encoder}: ${result.state}',
              );
            }
            op.token.check();
            await requireCurrentInstallation(checked, parser.version, op.token);
            final finalCapabilities = (await cache.read(checked.identity.key))!;
            final availability = <String, Object?>{
              for (final e in finalCapabilities.encoders.entries)
                e.key:
                    jsonMap(e.value)['availability'] ??
                    EncoderAvailability().data,
            };
            for (final name in curated.keys) {
              availability.putIfAbsent(
                name,
                () => EncoderAvailability(
                  state: 'missing',
                  reason: 'Not listed by this FFmpeg.',
                ).data,
              );
            }
            await discovery.updateRecord(
              checked.id,
              checked.identity.key,
              (record) => record.copyWith(
                probedAt: finalCapabilities.probedAt,
                probeMs: timer.elapsedMilliseconds,
                availability: availability,
                counts: {
                  'video': finalCapabilities.encoders.values
                      .where((v) => jsonMap(v)['kind'] == 'video')
                      .length,
                  'audio': finalCapabilities.encoders.values
                      .where((v) => jsonMap(v)['kind'] == 'audio')
                      .length,
                  'muxers': finalCapabilities.muxers.entries
                      .map((e) => jsonMap(e.value)['canonical'] ?? e.key)
                      .toSet()
                      .length,
                },
              ),
            );
            emit(
              'done',
              completed: names.length,
              total: names.length,
              capabilities: finalCapabilities,
            );
          } catch (e) {
            // A complete catalog can be cached for on-demand help, but a failed or
            // cancelled stream never claims a completed probe on the installation.
            emit(
              failure != null
                  ? 'failed'
                  : op.token.cancelled
                  ? 'cancelled'
                  : 'failed',
              message: (failure ?? e).toString(),
            );
          } finally {
            _operations.finish(installation.id, op);
            unawaited(controller.close());
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
    return controller.stream;
  }

  @override
  Future<EncoderDetails> encoderDetails(
    FFmpegInstallation installation,
    String encoder,
  ) async {
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(encoder))
      throw const ServiceException('ENCODER-NAME', 'Invalid encoder name.');
    final operation = _operations.begin(installation.id);
    try {
      final value = await cache.read(installation.identity.key);
      operation.token.check();
      final health = await installationHealth(installation);
      if (health.health != 'unchanged')
        throw const ServiceException(
          'FFMPEG-CHANGED',
          'Installation changed or is incomplete; probe it again.',
        );
      final cached = value?.encoders[encoder];
      if (cached is Map && cached.containsKey('pixelFormats'))
        return EncoderDetails.fromJson(jsonMap(cached));
      if (cached is! Map)
        throw const ServiceException(
          'ENCODER-NOT-FOUND',
          'Encoder is not listed; probe the installation first.',
        );
      await requireCurrentInstallation(
        installation,
        parser.version,
        operation.token,
      );
      final result = await runner.run(installation.path, [
        '-hide_banner',
        '-h',
        'encoder=$encoder',
      ], cancellation: operation.token);
      result.requireSuccess('Encoder help');
      final data = await _parseHelp(
        result.stdout + result.stderr,
        cached['kind'] as String,
      );
      if (data['name'] != encoder)
        throw const ServiceException(
          'HELP-PARSE',
          'Encoder help returned a different name.',
        );
      operation.token.check();
      await cache.update(installation.identity.key, (current) {
        if (current == null)
          throw const ServiceException(
            'PROBE-REQUIRED',
            'Cache was removed while reading encoder details.',
          );
        final encoders = current.encoders;
        encoders[encoder] = {...jsonMap(encoders[encoder]), ...data};
        return current.copyWith(encoders: encoders);
      });
      return EncoderDetails.fromJson(data);
    } finally {
      _operations.finish(installation.id, operation);
    }
  }
}
