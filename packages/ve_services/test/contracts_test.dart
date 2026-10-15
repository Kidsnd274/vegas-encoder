import 'dart:async';
import 'dart:convert';
import 'package:ve_services/ve_services.dart';

int checks = 0;
void check(bool condition, String message) {
  checks++;
  if (!condition) throw StateError(message);
}

Future<void> rejects(Future<void> Function() action, String code) async {
  try {
    await action();
  } on ServiceException catch (e) {
    check(e.code == code, 'wrong service error ${e.code}');
    return;
  }
  throw StateError('Expected $code');
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

Future<void> main() async {
  final discovery = FakeFFmpegDiscovery();
  final installations = await discovery.list();
  check(
    installations.length == 3 && installations.every((i) => i.isFixture),
    'mock installations',
  );
  check(
    EncoderAvailability.fromJson(
          jsonMap(installations.first.availability['hevc_qsv']),
        ).state ==
        'failed',
    'QSV failure',
  );
  final seen = <int>[];
  final s1 = discovery.watch().listen((v) => seen.add(v.length));
  await discovery.remove(installations.last.id);
  await tick();
  check(seen.join(',') == '3,2', 'watch initial and same-turn update');
  check(
    (await discovery.watch().first).length == 2,
    'late listener replays latest',
  );
  await s1.cancel();
  await rejects(() async {
    await discovery.add('unknown.exe');
  }, 'B0-FIXTURE-MISSING');

  final probe = FakeFFmpegProbe();
  final progress = await probe.probe(installations.first).toList();
  check(
    progress.length == 3 && progress.last.phase == 'done',
    'probe progress',
  );
  final capabilities = progress.last.capabilities!;
  check(
    capabilities.toCoreCapabilities().installationId == installations.first.id,
    'core capability view',
  );
  check(
    capabilities
                .copyWith(libavformatMajor: 63)
                .toCoreCapabilities()
                .libavformatMajor ==
            63 &&
        capabilities
                .copyWith(libavformatMajor: 63)
                .copyWith(libavformatMajor: null)
                .toCoreCapabilities()
                .libavformatMajor ==
            null,
    'probed library major is preserved and can explicitly return to unknown',
  );
  check(
    (await probe.encoderDetails(
      installations.first,
      'hevc_nvenc',
    )).options.isNotEmpty,
    'encoder option fixtures',
  );
  final cancelled = <ProbeProgress>[];
  await for (final p in probe.probe(installations.first)) {
    cancelled.add(p);
    await probe.cancel(installations.first.id);
  }
  check(cancelled.length == 1, 'probe cancellation stops later events');
  final cache = FakeCapabilityCache();
  check(await cache.read(capabilities.identityKey) == null, 'cache miss');
  await cache.write(capabilities);
  check(await cache.read(capabilities.identityKey) != null, 'cache hit');
  await cache.invalidate(capabilities.identityKey);
  check(
    await cache.read(capabilities.identityKey) == null,
    'cache invalidation',
  );
  final parser = FakeFFmpegHelpParser(
    encoderHelp: {
      'help': await probe.encoderDetails(installations.first, 'aac'),
    },
    encoders: {
      'list': {
        'aac': {'kind': 'audio'},
      },
    },
  );
  check(parser.parseEncoderHelp('help').name == 'aac', 'parser fixture');
  final parsed = parser.parseEncoders('list');
  parsed.clear();
  check(parser.parseEncoders('list').isNotEmpty, 'parser result isolated');
  final hardware = FakeHardwareTests();
  final hw = await hardware.test(installations.first).toList();
  check(
    hw.any((v) => v.encoder == 'hevc_nvenc' && v.state == 'ok' && v.tenBit),
    'NVENC sample ready',
  );
  check(hw.any((v) => v.failureClass == 'no-device'), 'hardware failure class');
  final cancelledHardware = <HardwareTestResult>[];
  await for (final h in hardware.test(installations.first)) {
    cancelledHardware.add(h);
    await hardware.cancel(installations.first.id);
  }
  check(cancelledHardware.length == 1, 'hardware cancellation');

  final library = FakePresetLibrary();
  final builtin = (await library.list()).first;
  await rejects(() async {
    await library.save(builtin, expectedRevision: builtin.revision);
  }, 'READ-ONLY');
  final user = await library.importPreset(
    await library.exportPreset(builtin.recipe.id),
    newId: 'user-copy',
  );
  check(
    user.revision == 1 &&
        !user.builtin &&
        user.origin == 'builtin/${builtin.recipe.id}',
    'duplicate origin and revision',
  );
  final saves = await Future.wait([
    library
        .save(
          user.copyWith(recipe: user.recipe.copyWith(name: 'First')),
          expectedRevision: 1,
        )
        .then((_) => 'saved')
        .catchError((Object e) => (e as ServiceException).code),
    library
        .save(
          user.copyWith(recipe: user.recipe.copyWith(name: 'Second')),
          expectedRevision: 1,
        )
        .then((_) => 'saved')
        .catchError((Object e) => (e as ServiceException).code),
  ]);
  check(
    saves.where((v) => v == 'saved').length == 1 &&
        saves.contains('REVISION-CONFLICT'),
    'concurrent revision conflict',
  );
  check(
    (await library.get(user.recipe.id, revision: 1))!.recipe.name ==
        user.recipe.name,
    'revision retained',
  );
  var latest = (await library.get(user.recipe.id))!;
  for (var n = 0; n < 22; n++) {
    latest = await library.save(latest, expectedRevision: latest.revision);
  }
  check(
    await library.get(user.recipe.id, revision: 1) == null,
    'history bounded to 20',
  );
  check(
    await library.get(user.recipe.id, revision: latest.revision - 20) != null,
    'last 20 revisions available',
  );
  await rejects(
    () => library.delete(user.recipe.id, expectedRevision: 1),
    'REVISION-CONFLICT',
  );
  await library.delete(user.recipe.id, expectedRevision: latest.revision);
  check(await library.get(user.recipe.id) == null, 'delete current');

  final machine = FakeMachineSettingsRepository();
  final original = await machine.read();
  check(
    !original.keepOnTop && !MachineSettings().keepOnTop,
    'monitor starts unpinned',
  );
  check(
    original.uiState!.desktopWindowBounds!.x == -1280 &&
        original.uiState!.lastSizeLengthText == '10:00',
    'UI-state fixture uses virtual desktop',
  );
  final saved = await machine.save(
    original.copyWith(progressWindow: false),
    expectedRevision: original.revision,
  );
  check(!saved.progressWindow && saved.revision == 1, 'machine save');
  await rejects(() async {
    await machine.save(original, expectedRevision: 0);
  }, 'REVISION-CONFLICT');
  await rejects(() async {
    await machine.save(
      saved.copyWith(defaultFFmpegId: 'missing'),
      expectedRevision: 1,
    );
  }, 'DEFAULT-NOT-FOUND');
  final uiJson = original.uiState!.toJson();
  uiJson['future'] = {
    'nested': [1],
  };
  (uiJson['desktopWindowBounds'] as Map)['future'] = {'scale': 1.25};
  final uiState = AppUiState.fromJson(uiJson);
  (uiJson['future'] as Map).clear();
  final uiSnapshots = <MachineSettings>[];
  final uiSub = machine.watch().listen(uiSnapshots.add);
  final uiSaved = await machine.save(
    saved.copyWith(
      uiState: uiState.copyWith(
        desktopWindowBounds: uiState.desktopWindowBounds!.copyWith(x: -1920),
        popupWindowSize: PopupWindowSize.fromJson({
          'width': 1100,
          'height': 760,
          'future': {'dpi': 144},
        }),
        desktopMaximized: true,
        lastSizeLengthText: '1:',
      ),
    ),
    expectedRevision: saved.revision,
  );
  await tick();
  check(
    uiSaved.revision == 2 &&
        !uiSaved.progressWindow &&
        uiSaved.defaultFFmpegId == original.defaultFFmpegId &&
        !uiSaved.keepOnTop,
    'UI write preserves render preferences',
  );
  check(
    uiSnapshots.last.uiState!.lastSizeLengthText == '1:' &&
        uiSnapshots.last.uiState!.desktopMaximized,
    'UI watch preserves incomplete text and maximize',
  );
  check(
    (uiSaved.uiState!.toJson()['future'] as Map).isNotEmpty &&
        (uiSaved.uiState!.desktopWindowBounds!.toJson()['future']
                as Map)['scale'] ==
            1.25,
    'UI state and bounds preserve unknown nested keys',
  );
  final uiCopy = uiSaved.toJson();
  ((uiCopy['uiState'] as Map)['desktopWindowBounds'] as Map)['x'] = 0;
  check(
    uiSaved.uiState!.desktopWindowBounds!.x == -1920,
    'UI serialization returns independent copy',
  );
  await rejects(() async {
    await machine.save(saved, expectedRevision: 1);
  }, 'REVISION-CONFLICT');
  check(
    (await machine.read()).uiState!.lastSizeLengthText == '1:',
    'conflicting write preserves UI state',
  );
  check(
    uiState.copyWith(lastSizeLengthText: '').lastSizeLengthText == '',
    'empty input retained',
  );
  check(
    uiState
                .copyWith(desktopWindowBounds: null, lastSizeLengthText: null)
                .desktopWindowBounds ==
            null &&
        uiState.copyWith(lastSizeLengthText: null).lastSizeLengthText == null &&
        uiSaved.copyWith(uiState: null).uiState == null,
    'explicit null clears UI fields',
  );
  final oldMachine = MachineSettings.fromJson({'machine': 1});
  check(
    oldMachine.uiState == null && !oldMachine.toJson().containsKey('uiState'),
    'older machine file needs no migration',
  );
  check(
    !AppUiState.fromJson({}).desktopMaximized,
    'missing UI maximize defaults false',
  );
  check(
    uiSaved.uiState!.popupWindowSize!.width == 1100 &&
        (uiSaved.uiState!.popupWindowSize!.data['future'] as Map)['dpi'] == 144,
    'popup size fake save/watch and unknown fields',
  );
  check(
    uiSaved.uiState!.copyWith(popupWindowSize: null).popupWindowSize == null &&
        AppUiState.fromJson({}).popupWindowSize == null,
    'popup size null clears and absent stays absent',
  );
  for (final invalid in [0, -1, 32769]) {
    await rejects(() async {
      await machine.save(
        uiSaved.copyWith(
          uiState: uiSaved.uiState!.copyWith(
            popupWindowSize: PopupWindowSize(width: invalid, height: 760),
          ),
        ),
        expectedRevision: uiSaved.revision,
      );
    }, 'INVALID-DATA');
  }
  check(
    (await machine.read()).revision == uiSaved.revision,
    'invalid popup size preserves settings',
  );
  await uiSub.cancel();

  final live = FakeLiveRenderStatusReader();
  final samples = FakeLiveRenderStatusReader.samples();
  check(
    samples.first.outputBitDepth == null &&
        samples.first.pixelFormatConversionReducesPrecision == null &&
        samples
            .skip(1)
            .every(
              (s) =>
                  s.outputBitDepth == 8 &&
                  s.pixelFormatConversionReducesPrecision == true,
            ),
    'live fixtures distinguish precompile unknown from P010 to eight-bit output',
  );
  check(
    samples.every((s) => s.hostHwnd == '123456'),
    'host handle in every live phase',
  );
  final oldLiveJson = samples.first.toJson()
    ..remove('hostHwnd')
    ..remove('outputBitDepth')
    ..remove('pixelFormatConversionReducesPrecision');
  final oldLive = LiveRenderStatus.fromJson(oldLiveJson);
  check(
    oldLive.hostHwnd == null && !oldLive.toJson().containsKey('hostHwnd'),
    'older live files leave handle unavailable',
  );
  check(
    oldLive.outputBitDepth == null &&
        oldLive.pixelFormatConversionReducesPrecision == null &&
        !oldLive.toJson().containsKey('outputBitDepth') &&
        !oldLive.toJson().containsKey('pixelFormatConversionReducesPrecision'),
    'older live files preserve absent video facts without migration',
  );
  final videoJson =
      samples[1]
          .copyWith(
            outputBitDepth: 10,
            pixelFormatConversionReducesPrecision: false,
          )
          .toJson()
        ..['futureVideo'] = {
          'nested': [1],
        };
  final videoFacts = LiveRenderStatus.fromJson(videoJson);
  (videoJson['futureVideo'] as Map).clear();
  check(
    videoFacts.outputBitDepth == 10 &&
        videoFacts.pixelFormatConversionReducesPrecision == false &&
        (videoFacts.toJson()['futureVideo'] as Map)['nested'][0] == 1 &&
        videoFacts.copyWith(message: 'Later phase').outputBitDepth == 10,
    'video facts and unknown fields survive immutable model copies',
  );
  final unknownVideoFacts = videoFacts.copyWith(
    outputBitDepth: null,
    pixelFormatConversionReducesPrecision: null,
  );
  check(
    unknownVideoFacts.outputBitDepth == null &&
        unknownVideoFacts.pixelFormatConversionReducesPrecision == null &&
        unknownVideoFacts.toJson().containsKey('outputBitDepth'),
    'explicit null clears both video facts',
  );
  final seededVideo = FakeLiveRenderStatusReader(initial: {'seed': videoFacts});
  check(
    (await seededVideo.read('seed'))!.pixelFormatConversionReducesPrecision ==
        false,
    'fake accepts supplied video facts without deriving them',
  );
  await seededVideo.dispose();
  await rejects(() async {
    FakeLiveRenderStatusReader(
      initial: {'invalid': videoFacts.copyWith(outputBitDepth: 0)},
    );
  }, 'INVALID-DATA');
  check(
    samples.first.copyWith(hostHwnd: null).hostHwnd == null,
    'handle can be cleared',
  );
  const maxHandle = '18446744073709551615';
  check(
    LiveRenderStatus.fromJson(
          samples.first.copyWith(hostHwnd: maxHandle).toJson(),
        ).hostHwnd ==
        maxHandle,
    'HWND decimal string round-trips without numeric precision loss',
  );
  check(
    samples.map((s) => s.state).toSet().length == RenderState.values.length,
    'all seven render states',
  );
  check(await live.read('live') == null, 'missing live file');
  final snapshots = <LiveRenderStatus?>[];
  final liveSub = live.watch('live').listen(snapshots.add);
  live.publish('live', samples[0]);
  live.publish('live', samples[1]);
  await tick();
  check(
    snapshots.length == 3 && snapshots.first == null,
    'live replay and updates',
  );
  check(
    (await live.read('live'))!.hostHwnd == '123456' &&
        snapshots.last!.hostHwnd == '123456',
    'host placement fact survives reader and watch',
  );
  check(
    snapshots.last!.outputBitDepth == 8 &&
        snapshots.last!.pixelFormatConversionReducesPrecision == true,
    'fake watch transports known video facts',
  );
  for (final invalid in [
    for (final depth in [0, -1, 8.0, '8', true])
      samples[1].copyWith(sequence: 3, outputBitDepth: depth),
    for (final reduces in [0, 'false'])
      samples[1].copyWith(
        sequence: 3,
        pixelFormatConversionReducesPrecision: reduces,
      ),
  ]) {
    await rejects(() async {
      live.publish('live', invalid);
    }, 'INVALID-DATA');
  }
  check(
    (await live.read('live'))!.sequence == 2,
    'invalid fake video facts preserve the previous status',
  );
  await rejects(() async {
    live.publish('live', samples[0]);
  }, 'LIVE-SEQUENCE');
  await liveSub.cancel();

  final jobs = FakeJobRepository();
  final index = await jobs.list();
  check(
    index.length == 5 &&
        index.map((i) => i.status).toSet().containsAll([
          'succeeded',
          'cancelled',
          'failed',
        ]),
    'history states',
  );
  check(
    (await jobs.get(index.first.id))!.ffmpeg.isFixture,
    'job identity is illustrative',
  );
  final sessions = FakeEditSessionService();
  final request = await sessions.readRequest('b0-session');
  check(
    request.ownerHwnd == '123456' && request.baseRecipe != null,
    'popup context',
  );
  await rejects(
    () => sessions.writeResult(
      'b0-session',
      EditSessionResult(sessionId: 'wrong', action: 'cancel'),
    ),
    'SESSION-MISMATCH',
  );
  await rejects(
    () => sessions.writeResult(
      'b0-session',
      EditSessionResult(sessionId: request.sessionId, action: 'apply'),
    ),
    'SESSION-RESULT',
  );
  await sessions.writeResult(
    'b0-session',
    EditSessionResult(
      sessionId: request.sessionId,
      action: 'apply',
      recipe: request.recipe,
      origin: request.origin,
    ),
  );
  check(
    sessions.resultFor('b0-session')!.recipe!.name == request.recipe.name,
    'apply snapshot',
  );
  await rejects(
    () => sessions.writeResult(
      'b0-session',
      EditSessionResult(sessionId: request.sessionId, action: 'cancel'),
    ),
    'SESSION-CLOSED',
  );
  final cancel = FakeEditSessionService();
  await cancel.writeResult(
    'b0-session',
    EditSessionResult.fromJson(
      jsonMap(
        jsonDecode(
          '{"protocol":1,"sessionId":"b0-edit-session","action":"cancel"}',
        ),
      ),
    ),
  );
  check(
    cancel.resultFor('b0-session')!.recipe == null,
    'cancel carries no draft',
  );
  await discovery.dispose();
  await library.dispose();
  await machine.dispose();
  await live.dispose();
  await jobs.dispose();
  print('ve_services: $checks contract checks passed (in-memory fakes only).');
}
