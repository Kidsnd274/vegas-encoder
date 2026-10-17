// Exercises the real service's failure boundary with read-only PE fixtures and
// a fake executor. No executable is launched, and the user's profile is unused.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:ve_services/src/ffmpeg_identity.dart';

void main() {
  late Directory boundary;
  late Directory root;
  late FFmpegInstallation installation;
  late Recipe recipe;
  late ServicePaths paths;
  late FakeProcessExecutor runner;

  setUpAll(() async {
    boundary = Directory('../build/test-results').absolute;
    await boundary.create(recursive: true);
    root = await boundary.createTemp('preset-errors-');
    paths = ServicePaths(roaming: '${root.path}/roaming', local: '${root.path}/local');
    final bytes = Uint8List(256)
      ..[0] = 0x4d
      ..[1] = 0x5a
      ..[60] = 64
      ..[64] = 0x50
      ..[65] = 0x45
      ..[68] = 0x64
      ..[69] = 0x86;
    final executable = File('${root.path}/ffmpeg.exe');
    final probe = File('${root.path}/ffprobe.exe');
    await executable.writeAsBytes(bytes);
    await probe.writeAsBytes(bytes);
    installation = FFmpegInstallation(
      id: 'error-fixture',
      label: 'Read-only identity fixture',
      path: executable.path,
      ffprobePath: probe.path,
      source: 'manual',
      version: 'fixture',
      identity: await binaryIdentity(executable.path, WindowsFFmpegHelpParser().version),
      extensions: {
        'ffprobeIdentity': {'sha256': await IsolatedHash.file(probe.path)},
      },
    );
    recipe = (await FakePresetLibrary().list()).first.recipe;
  });

  tearDownAll(() async {
    final target = (await root.resolveSymbolicLinks()).toLowerCase();
    final parent = (await boundary.resolveSymbolicLinks()).toLowerCase();
    if (!target.startsWith('$parent${Platform.pathSeparator}')) throw StateError('Unsafe test cleanup path.');
    await root.delete(recursive: true);
  });

  setUp(() => runner = FakeProcessExecutor((_, _, _) async => throw StateError('No child should launch.')));

  Future<PresetTestProgress> result({CapabilityCache? cache, VeCore? core}) async {
    final service = WindowsPresetTests(
      core: core ?? FakeVeCore(),
      runner: runner,
      cache: cache ?? FakeCapabilityCache(),
      paths: paths,
    );
    final progress = await service.test(recipe, installation).toList();
    expect(runner.calls, isEmpty);
    expect(progress.last.phase, 'failed');
    expect(progress.last.message, isNot(contains('Exception(')));
    return progress.last;
  }

  test('service refusal is a plain message plus code', () async {
    final failed = await result();
    expect(failed.message, 'Probe this installation before testing a preset.');
    expect(failed.code, 'PROBE-REQUIRED');
  });

  test('core failure retains its own code and plain message', () async {
    final failed = await result(
      core: _FailedCore(),
      cache: FakeCapabilityCache(
        capabilities: [
          FFmpegCapabilities(
            installationId: installation.id,
            identityKey: installation.identity.key,
            version: installation.version,
            probedAt: '2026-10-17T00:00:00Z',
          ),
        ],
      ),
    );
    expect(failed.message, 'The product core is unavailable.');
    expect(failed.code, 'NATIVE-LOAD');
  });

  test('I/O failure uses plain text and legacy progress may omit the additive code', () async {
    final failed = await result(cache: _UnreadableCache());
    expect(failed.message, 'Capability cache is unreadable.');
    expect(failed.code, 'PRESET-TEST-IO');
    expect(PresetTestProgress.fromJson({'testId': 'old', 'phase': 'failed', 'message': 'Old record.'}).code, isNull);
    final future = PresetTestProgress.fromJson({
      ...failed.toJson(),
      'future': {'retained': true},
    });
    expect(future.toJson()['future'], {'retained': true});
    expect(future.code, failed.code);
  });
}

class _FailedCore extends FakeVeCore {
  @override
  ProfileCatalog profiles() => throw const CoreException('NATIVE-LOAD', 'The product core is unavailable.');
}

class _UnreadableCache extends FakeCapabilityCache {
  @override
  Future<FFmpegCapabilities?> read(String identityKey) async =>
      throw const FileSystemException('Capability cache is unreadable.');
}
