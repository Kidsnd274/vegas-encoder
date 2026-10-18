import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ve_services/ve_services.dart';
import 'package:ve_services/src/storage.dart';
import 'package:ve_services/src/ffmpeg_identity.dart';

int checks = 0;
void check(bool ok, String message) {
  checks++;
  if (!ok) throw StateError(message);
}

Future<void> rejects(Future<Object?> Function() action, String code) async {
  try {
    await action();
  } on ServiceException catch (e) {
    check(e.code == code, '$code, got $e');
    return;
  }
  throw StateError('Expected $code');
}

Future<void> waitFor(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline))
      throw StateError('Test condition timed out.');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == '--child') {
    await child(args.skip(1).toList());
    return;
  }
  if (!Platform.isWindows ||
      ['dart.exe', 'dartvm.exe'].contains(
        File(Platform.resolvedExecutable).uri.pathSegments.last.toLowerCase(),
      )) {
    throw StateError(
      'Use scripts/etc/Test-B3Services.ps1 (Windows AOT with native assets).',
    );
  }
  final parser = WindowsFFmpegHelpParser();
  final catalog = jsonMap(
    jsonDecode(
      await File('../../schema/ffmpeg/windows-builds.v1.json').readAsString(),
    ),
  );
  final builds = jsonMaps(catalog['measurements']);
  String fixture(String name) => '../../schema/fixtures/ffmpeg/$name';
  for (var i = 0; i < 3; i++) {
    final name = ['old', 'gyan', 'btbn'][i];
    final version = parser.parseVersion(
      await File(fixture('b3-$name-version.txt')).readAsString(),
    );
    check(version['version'] == builds[i]['version'], '$name banner identity');
    check(
      canonicalJson(version['libraries']) ==
          canonicalJson(builds[i]['libraries']),
      '$name loaded library identity',
    );
    final encoders = parser.parseEncoders(
      await File(fixture('b3-$name-encoders.txt')).readAsString(),
    );
    check(
      encoders.length == (builds[i]['encoderList'] as List).length,
      '$name encoder count includes subtitles',
    );
    for (final encoder in jsonMaps(builds[i]['encoderList'])) {
      final actual = jsonMap(encoders[encoder['name']]);
      check(
        actual['flags'] == encoder['flags'] &&
            actual['description'] ==
                (encoder['description'] as String).replaceAll('\r', ''),
        '$name ${encoder['name']} flags/description',
      );
    }
    final muxers = parser.parseMuxers(
      await File(fixture('b3-$name-muxers.txt')).readAsString(),
    );
    check(muxers.length == [178, 190, 189][i], '$name muxer count');
    final options = parser.parseOptions(
      await File(fixture('b3-$name-generic.txt')).readAsString(),
    );
    final expected = jsonMaps(builds[i]['genericOptions']);
    check(options.length == expected.length, '$name generic option count');
    for (var n = 0; n < options.length; n++) {
      for (final key in [
        'name',
        'aliases',
        'type',
        'flags',
        'description',
        'min',
        'max',
        'defaultValue',
        'constants',
      ]) {
        check(
          canonicalJson(options[n].data[key]) ==
              canonicalJson(expected[n][key]),
          '$name ${options[n].name} $key',
        );
      }
    }
  }
  for (final pair in [
    ('old-hevc_nvenc.txt', 0, 'hevc_nvenc'),
    ('old-h264_amf.txt', 0, 'h264_amf'),
    ('current-hevc_nvenc.txt', 1, 'hevc_nvenc'),
    ('current-dnxhd.txt', 1, 'dnxhd'),
  ]) {
    final parsed = parser.parseEncoderHelp(
      await File(fixture(pair.$1)).readAsString(),
    );
    final expected = jsonMap(jsonMap(builds[pair.$2]['encoders'])[pair.$3]);
    for (final key in [
      'name',
      'kind',
      'pixelFormats',
      'sampleFormats',
      'sampleRates',
    ]) {
      check(
        canonicalJson(parsed.data[key]) == canonicalJson(expected[key]),
        '${pair.$1} $key',
      );
    }
    check(
      parsed.options.length == (expected['options'] as List).length,
      '${pair.$1} merged count',
    );
    for (var n = 0; n < parsed.options.length; n++) {
      final e = jsonMaps(expected['options'])[n];
      for (final key in [
        'name',
        'aliases',
        'type',
        'flags',
        'description',
        'min',
        'max',
        'defaultValue',
        'constants',
      ]) {
        check(
          canonicalJson(parsed.options[n].data[key]) == canonicalJson(e[key]),
          '${pair.$1} option $n $key',
        );
      }
    }
  }
  await rejects(
    () async => parser.parseEncoderHelp(
      await File(fixture('old-ve_b1_nonexistent.txt')).readAsString(),
    ),
    'ENCODER-NOT-FOUND',
  );
  await rejects(() async => parser.parseEncoders('invalid'), 'HELP-PARSE');
  await rejects(
    () async => parser.parseVersion('ffmpeg version ambiguous'),
    'VERSION-PARSE',
  );
  final compileCore = NativeVeCore();
  final buildRoot = Directory('../../build/test-results').absolute;
  await buildRoot.create(recursive: true);
  final root = await buildRoot.createTemp('b3-services-');
  final subscriptions = <StreamSubscription<Object?>>[];
  try {
    final paths = ServicePaths(
      roaming: joinPath(root.path, 'roaming'),
      local: joinPath(root.path, 'local'),
    );
    final bin = Directory(joinPath(root.path, 'fixture-bin'));
    await bin.create();
    // Minimal PE-header fixtures are read/hashes only. FakeProcessExecutor is the
    // only executor used for these paths; they are not runnable payloads.
    final bytes = Uint8List(256)
      ..[0] = 0x4d
      ..[1] = 0x5a
      ..[60] = 64
      ..[64] = 0x50
      ..[65] = 0x45
      ..[68] = 0x64
      ..[69] = 0x86;
    final ffmpeg = File(joinPath(bin.path, 'ffmpeg.exe'));
    await ffmpeg.writeAsBytes(bytes);
    final ffprobe = File(joinPath(bin.path, 'ffprobe.exe'));
    await ffprobe.writeAsBytes(bytes);
    final dll = File(joinPath(bin.path, 'avcodec-59.dll'));
    await dll.writeAsString('shared fixture v1');
    final ini = File(joinPath(root.path, 'vegas-encoder.ini'));
    await ini.writeAsString('[Encoder]\nFFmpegPath="${ffmpeg.path}"\n');
    final finder = WindowsFFmpegCandidateFinder(
      environment: {'Path': bin.path, 'ChocolateyInstall': root.path},
      iniPaths: [ini.path],
    );
    final candidates = await finder.find();
    check(
      candidates.any((c) => c.source == 'path' && c.path == ffmpeg.path),
      'Windows environment names remain case-insensitive after copying',
    );
    check(
      candidates.any((c) => c.source == 'ini' && c.path == ffmpeg.path),
      'bounded legacy INI discovery finds the real executable path',
    );
    final versionText = await File(
      fixture('b3-old-version.txt'),
    ).readAsString();
    final encoderText = await File(
      fixture('b3-old-encoders.txt'),
    ).readAsString();
    final muxerText = await File(fixture('b3-old-muxers.txt')).readAsString();
    final genericText = await File(
      fixture('b3-old-generic.txt'),
    ).readAsString();
    final metadata = parser.parseVersion(versionText);
    final gpu = FakeGpuIdentity(
      GpuSnapshot(fingerprint: 'gpu-driver-1', cacheable: true),
    );
    var tenFails = true;
    var failHelp = false;
    var blockProbeLists = false;
    var changeProbeDuringCheck = false;
    final fake = FakeProcessExecutor((executable, arguments, token) async {
      token.check();
      if (arguments.contains('-version'))
        return ProcessOutput(exitCode: 0, stdout: versionText);
      if (arguments.contains('-show_versions')) {
        if (changeProbeDuringCheck) await ffprobe.writeAsBytes([...bytes, 7]);
        return ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'program_version': {
              'version': metadata['version'],
              'configuration': metadata['configuration'],
            },
            'library_versions': [
              for (final l in jsonMap(metadata['libraries']).entries)
                {
                  'name': l.key,
                  'major': int.parse((l.value as String).split('.')[0]),
                  'minor': int.parse((l.value as String).split('.')[1]),
                  'micro': int.parse((l.value as String).split('.')[2]),
                },
            ],
          }),
        );
      }
      if (blockProbeLists && arguments.contains('-encoders')) {
        await token.whenCancelled;
        token.check();
      }
      if (arguments.contains('-encoders'))
        return ProcessOutput(exitCode: 0, stdout: encoderText);
      if (arguments.contains('-muxers'))
        return ProcessOutput(exitCode: 0, stdout: muxerText);
      if (arguments.contains('full'))
        return ProcessOutput(
          exitCode: 0,
          stdout: 'AVCodecContext AVOptions:$genericText',
        );
      final help = arguments.where((a) => a.startsWith('encoder=')).firstOrNull;
      if (help != null) {
        if (failHelp)
          return const ProcessOutput(
            exitCode: 0,
            stdout: 'Codec is not recognized.',
          );
        final name = help.substring(8);
        final kind =
            name.startsWith('pcm') ||
                [
                  'aac',
                  'ac3',
                  'eac3',
                  'libopus',
                  'libmp3lame',
                  'libfdk_aac',
                  'flac',
                  'alac',
                ].contains(name)
            ? 'audio'
            : 'video';
        return ProcessOutput(
          exitCode: 0,
          stdout:
              'Encoder $name [fixture]:\n    Supported ${kind == 'audio' ? 'sample formats: fltp' : 'pixel formats: yuv420p nv12 p010le'}\n',
        );
      }
      if (arguments.contains('-c:v') &&
          arguments.contains('-frames:v') &&
          arguments[arguments.indexOf('-frames:v') + 1] == '1') {
        final encoder = arguments[arguments.indexOf('-c:v') + 1];
        if (!encoder.endsWith('_nvenc'))
          return const ProcessOutput(
            exitCode: 1,
            stderr: 'No device available.',
          );
        if (tenFails && arguments.contains('+p010le'))
          return const ProcessOutput(
            exitCode: 1,
            stderr: 'Unsupported pixel format.',
          );
        return const ProcessOutput(exitCode: 0);
      }
      throw StateError('Unhandled fake process $arguments');
    });
    final services = WindowsServices(
      core: compileCore,
      paths: paths,
      executor: fake,
      gpuIdentity: gpu,
      candidateFinder: FakeFFmpegCandidateFinder([
        FFmpegCandidate(ffmpeg.path, 'path'),
        FFmpegCandidate(ffmpeg.path, 'manual'),
      ]),
    );
    check(
      fake.calls.isEmpty && !Directory(paths.roaming).existsSync(),
      'constructing services has no system side effects',
    );
    check(
      (await services.discovery.list()).isEmpty && fake.calls.isEmpty,
      'list does not scan or execute',
    );
    final found = await services.discovery.scan();
    check(found.length == 1, 'scan deduplicates canonical paths');
    final installation = found.single;
    check(
      installation.identity.libraries.containsKey('avcodec-59.dll') &&
          installation.health == 'unchanged',
      'shared identity and health',
    );
    check(
      (await services.machineSettings.read()).installations.single.id ==
          installation.id,
      'discovery owns persistent C7 registrations',
    );
    final processesBeforeList = fake.calls.length;
    await services.discovery.list();
    check(
      fake.calls.length == processesBeforeList,
      'health is read-only without FFmpeg calls',
    );
    final settings = await services.machineSettings.read();
    await services.machineSettings.save(
      settings.copyWith(defaultFFmpegId: installation.id, theme: 'dark'),
      expectedRevision: settings.revision,
    );
    await rejects(
      () => services.discovery.remove(installation.id),
      'DEFAULT-IN-USE',
    );
    final progress = await services.probe.probe(installation).toList();
    check(
      progress.last.phase == 'done',
      'probe completed: ${progress.last.message}',
    );
    check(
      progress.any((p) => p.phase == 'identity') &&
          progress.any((p) => p.phase == 'details') &&
          progress.any((p) => p.phase == 'hardware'),
      'probe phases stream',
    );
    final capabilities = progress.last.capabilities!;
    check(
      capabilities.libavformatMajor == 59 &&
          capabilities.encoders.length == 214,
      'build version/list facts',
    );
    final recorded =
        (await services.machineSettings.read()).installations.single;
    check(
      recorded.probedAt != null &&
          recorded.probeMs != null &&
          recorded.counts['muxers'] == 176,
      'probe updates installation record',
    );
    check(
      (await services.machineSettings.read()).theme == 'dark',
      'probe preserves unrelated C7 fields',
    );
    await Future.wait([
      services.rawCache.update(
        recorded.identity.key,
        (current) => current!.copyWith(
          extensions: {...current.extensions, 'mergeA': true},
        ),
      ),
      services.rawCache.update(
        recorded.identity.key,
        (current) => current!.copyWith(
          extensions: {...current.extensions, 'mergeB': true},
        ),
      ),
    ]);
    final merged = (await services.rawCache.read(recorded.identity.key))!;
    check(
      merged.extensions['mergeA'] == true &&
          merged.extensions['mergeB'] == true,
      'concurrent lazy-help/hardware cache updates retain both facts',
    );
    blockProbeLists = true;
    final cancelledProbe = await services.probe.probe(recorded).map((event) {
      if (event.phase == 'lists') unawaited(services.probe.cancel(recorded.id));
      return event;
    }).toList();
    await services.probe.cancel(recorded.id);
    blockProbeLists = false;
    check(
      cancelledProbe.last.phase == 'cancelled',
      'probe cancellation waits for its active workers and emits no success',
    );
    final originalProbeModified = await ffprobe.lastModified();
    changeProbeDuringCheck = true;
    await rejects(() => services.discovery.add(ffmpeg.path), 'FFPROBE-CHANGED');
    changeProbeDuringCheck = false;
    await ffprobe.writeAsBytes(bytes);
    await ffprobe.setLastModified(originalProbeModified);
    final hevc = jsonMap(capabilities.hardware['hevc_nvenc']);
    check(
      hevc['state'] == 'ok' && hevc['tenBit'] == false,
      'failed 10-bit test does not block successful 8-bit encoder',
    );
    check(
      jsonMap(capabilities.hardware['hevc_qsv'])['state'] == 'failed',
      'missing hardware reported by actual test exit',
    );
    final beforeCachedHardware = fake.calls.length;
    final cachedResults = await services.hardwareTests
        .test(recorded, encoders: ['hevc_nvenc'])
        .toList();
    check(
      cachedResults.single.state == 'ok' &&
          fake.calls.length == beforeCachedHardware,
      'matching GPU/driver test reused without re-execution',
    );
    tenFails = false;
    final retested = await services.hardwareTests
        .test(recorded, encoders: ['hevc_nvenc'], force: true)
        .toList();
    check(
      retested.single.tenBit && fake.calls.length > beforeCachedHardware,
      'forced retest refreshes 10-bit outcome',
    );
    gpu.snapshot = GpuSnapshot(fingerprint: 'gpu-driver-2', cacheable: true);
    final invalidated = (await services.capabilityCache.read(
      recorded.identity.key,
    ))!;
    check(
      jsonMap(invalidated.hardware['hevc_nvenc'])['state'] == 'unknown' &&
          jsonMap(
                jsonMap(invalidated.encoders['hevc_nvenc'])['availability'],
              )['state'] ==
              'unknown',
      'GPU change invalidates both cache views',
    );
    final freshHardware = await services.hardwareTests
        .test(recorded, encoders: ['hevc_nvenc'])
        .toList();
    check(
      freshHardware.single.gpuFingerprint == 'gpu-driver-2',
      'changed fingerprint triggers retest',
    );
    final raw = (await services.rawCache.read(recorded.identity.key))!;
    final expiry = raw.hardware;
    expiry['hevc_nvenc'] = {
      ...jsonMap(expiry['hevc_nvenc']),
      'testedAt': DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 31))
          .toIso8601String(),
    };
    await services.rawCache.write(raw.copyWith(hardware: expiry));
    check(
      jsonMap(
            (await services.capabilityCache.read(
              recorded.identity.key,
            ))!.hardware['hevc_nvenc'],
          )['state'] ==
          'unknown',
      'hardware TTL expiry stays unknown',
    );
    final details = await services.probe.encoderDetails(recorded, 'libx264');
    check(details.name == 'libx264', 'cached curated details');
    final lazy = await services.probe.encoderDetails(recorded, 'libvorbis');
    check(
      lazy.name == 'libvorbis' &&
          (await services.rawCache.read(
            recorded.identity.key,
          ))!.encoders.containsKey('libvorbis'),
      'uncurated help loaded and persisted on demand',
    );
    final oldKey = installation.identity.key;
    await dll.writeAsString('shared fixture v2');
    check(
      (await services.discovery.list()).single.health == 'changed',
      'library change detected without executing FFmpeg',
    );
    final newIdentity = await binaryIdentity(ffmpeg.path, parser.version);
    check(
      newIdentity.key != oldKey &&
          newIdentity.sha256 == installation.identity.sha256,
      'library-only change invalidates executable cache key',
    );
    await rejects(
      () => services.probe.encoderDetails(recorded, 'libx264'),
      'FFMPEG-CHANGED',
    );
    final refreshed = await services.discovery.add(ffmpeg.path);
    check(
      refreshed.id == recorded.id && refreshed.probedAt == null,
      'same-path identity refresh preserves default ID and drops stale facts',
    );
    check(
      (await services.machineSettings.read()).defaultFFmpegId == recorded.id,
      'identity refresh preserves selection',
    );
    failHelp = true;
    final failedProbe = await services.probe.probe(refreshed).toList();
    check(
      failedProbe.last.phase == 'failed',
      'unknown-name exit zero is a probe failure, not success/cancellation',
    );
    await ffprobe.delete();
    check(
      (await services.discovery.list()).single.health == 'ffprobe-missing',
      'missing companion health',
    );
    await rejects(() => services.discovery.add(ffmpeg.path), 'FFPROBE-MISSING');
    await ffprobe.writeAsBytes(bytes);
    await ffmpeg.delete();
    final missing = await services.discovery.scan();
    check(
      missing.single.health == 'missing' &&
          (await services.machineSettings.read()).defaultFFmpegId ==
              installation.id,
      'scan preserves vanished default with explicit health',
    );

    await processTests();
    final nativeGpu = await WindowsGpuIdentity().read();
    final nativeAgain = await WindowsGpuIdentity().read();
    check(
      nativeGpu.fingerprint == nativeAgain.fingerprint &&
          nativeGpu.fingerprint.length == 64,
      'real DXGI fingerprint stable across ownership scopes',
    );
    check(
      nativeGpu.adapters.every(
        (a) => a['name'] is String && a.containsKey('driver'),
      ),
      'real DXGI adapter/driver fields',
    );
    print(
      'GPU identity: ${nativeGpu.adapters.map((a) => '${a['name']} / ${a['driver']}').join('; ')}; cacheable=${nativeGpu.cacheable}',
    );
    check(
      verifyOutput(
            {
              'streams': [
                {
                  'codec_type': 'video',
                  'codec_name': 'h264',
                  'nb_read_frames': '60',
                },
              ],
            },
            [ExpectedStream(kind: 'video', codec: 'h264')],
          ).state ==
          'passed',
      'output verification matches core expectations',
    );
    check(
      verifyOutput(
            {
              'streams': [
                {'codec_type': 'data', 'codec_name': 'bin_data'},
              ],
            },
            [ExpectedStream(kind: 'video', codec: 'h264')],
          ).state ==
          'failed',
      'data stream cannot pass as video',
    );
    check(
      verifyOutput(
            {
              'streams': [
                {
                  'codec_type': 'video',
                  'codec_name': 'hevc',
                  'nb_read_frames': '60',
                },
              ],
            },
            [ExpectedStream(kind: 'video', codec: 'h264')],
          ).state ==
          'failed',
      'wrong codec refused',
    );
    check(
      verifyOutput(
            {
              'streams': [
                {
                  'codec_type': 'video',
                  'codec_name': 'h264',
                  'nb_read_frames': '0',
                },
              ],
            },
            [ExpectedStream(kind: 'video', codec: 'h264')],
          ).state ==
          'failed',
      'empty video refused',
    );
    final fakeTests = FakePresetTests();
    final fixturePreset = (await services.library.list()).first.recipe;
    check(
      (await fakeTests.test(fixturePreset, installation).toList())
          .last
          .isFixture,
      'preset-test fake executes no process',
    );
    print(
      'B3 SERVICES PASSED: $checks checks; B1 capture parser fixtures, fake FFmpeg processes, real Windows process/timeout/pool and DXGI helper. No VEGAS.',
    );
  } finally {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    final resolved = await root.resolveSymbolicLinks();
    final boundary = await buildRoot.resolveSymbolicLinks();
    if (!resolved.toLowerCase().startsWith(
      '${boundary.toLowerCase()}${Platform.pathSeparator}',
    ))
      throw StateError('Unsafe cleanup target.');
    await root.delete(recursive: true);
  }
}

Future<void> processTests() async {
  final runner = WindowsProcessExecutor();
  final executable = Platform.resolvedExecutable;
  final echoed = await runner.run(executable, [
    '--child',
    'echo',
    'spaces and ü',
    'literal & | % !',
  ], timeout: const Duration(seconds: 5));
  check(
    echoed.exitCode == 0 &&
        (jsonDecode(echoed.stdout) as List).join(';') ==
            'spaces and ü;literal & | % !',
    'Windows argv quoting, Unicode and shell characters remain literal',
  );
  final streamedOut = StringBuffer();
  final streamedError = StringBuffer();
  final unicode = await runner.run(
    executable,
    ['--child', 'utf8'],
    onStdout: streamedOut.write,
    onStderr: streamedError.write,
  );
  check(
    unicode.stdout == '出力🧪' &&
        streamedOut.toString() == unicode.stdout &&
        unicode.stderr == '出力🧪' &&
        streamedError.toString() == unicode.stderr,
    'streamed UTF-8 keeps characters split between process byte chunks',
  );
  final timer = Stopwatch()..start();
  final timeout = await runner.run(executable, [
    '--child',
    'wait',
  ], timeout: const Duration(milliseconds: 150));
  check(
    timeout.timedOut &&
        timer.elapsedMilliseconds < 2000 &&
        runner.pool.active == 0,
    'hard timeout kills/reaps child and releases slot',
  );
  final token = CancellationToken();
  final pending = runner.run(executable, [
    '--child',
    'wait',
  ], cancellation: token);
  await waitFor(() => runner.pool.active == 1);
  token.cancel();
  check(
    (await pending).cancelled && runner.pool.active == 0,
    'cancel at start/wait reaps child',
  );
  final flooded = await runner.run(
    executable,
    ['--child', 'flood'],
    stdoutLimit: 2048,
    outputLimit: 4096,
  );
  check(
    flooded.outputLimit &&
        flooded.stdout.length <= 2048 &&
        runner.pool.active == 0,
    'output bounds kill and reap',
  );
  final blocking = [for (var i = 0; i < 4; i++) CancellationToken()];
  final calls = [
    for (final t in blocking)
      runner.run(executable, ['--child', 'wait'], cancellation: t),
  ];
  await waitFor(() => runner.pool.active == 4);
  final queuedToken = CancellationToken();
  final queued = runner.run(executable, [
    '--child',
    'echo',
    'must not start',
  ], cancellation: queuedToken);
  queuedToken.cancel();
  await rejects(() => queued, 'CANCELLED');
  check(
    runner.pool.active == 4,
    'cancelled queued work cannot consume fifth slot',
  );
  for (final t in blocking) {
    t.cancel();
  }
  await Future.wait(calls);
  check(runner.pool.active == 0, 'all concurrent owned children released');
}

Future<void> child(List<String> args) async {
  if (args.first == 'utf8') {
    for (final byte in utf8.encode('出力🧪')) {
      stdout.add([byte]);
      stderr.add([byte]);
      await stdout.flush();
      await stderr.flush();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return;
  }
  if (args.first == 'echo') {
    stdout.write(jsonEncode(args.skip(1).toList()));
    return;
  }
  if (args.first == 'flood') {
    while (true) {
      stdout.write('x' * 1024);
      await stdout.flush();
    }
  }
  await Future<void>.delayed(const Duration(seconds: 30));
}
