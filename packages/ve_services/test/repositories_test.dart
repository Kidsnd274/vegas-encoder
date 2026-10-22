import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ve_services/ve_services.dart';
import 'package:ve_services/src/storage.dart';

int checks = 0;
void check(bool ok, String message) {
  checks++;
  if (!ok) throw StateError(message);
}

Future<void> rejects(Future<Object?> Function() action, String code) async {
  try {
    await action();
  } on ServiceException catch (e) {
    check(e.code == code, 'Expected $code, got $e');
    return;
  }
  throw StateError('Expected $code.');
}

Future<void> waitFor(bool Function() ready, {int seconds = 20}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline))
      throw StateError('Timed out waiting for test barrier.');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<void> removeLive(File file) async {
  final deadline = DateTime.now().add(const Duration(milliseconds: 500));
  while (true) {
    try {
      await file.delete();
      return;
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode != 32 || DateTime.now().isAfter(deadline))
        rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }
}

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == '--worker') {
    await worker(args.skip(1).toList());
    return;
  }
  if (!Platform.isWindows) throw StateError('Windows-only tests.');
  if (['dart.exe', 'dartvm.exe'].contains(
    File(Platform.resolvedExecutable).uri.pathSegments.last.toLowerCase(),
  )) {
    throw StateError(
      'Run scripts/etc/Test-B3Repositories.ps1 to bundle native assets for process tests.',
    );
  }
  final build = Directory('../../build/test-results').absolute;
  await build.create(recursive: true);
  final root = await build.createTemp('b3-repositories-');
  final paths = ServicePaths(
    roaming: joinPath(root.path, 'roaming'),
    local: joinPath(root.path, 'local'),
  );
  final core = NativeVeCore();
  final active = <StreamSubscription<Object?>>[];
  final children = <Process>[];
  try {
    final machineA = FileMachineSettingsRepository(paths: paths);
    final machineB = FileMachineSettingsRepository(paths: paths);
    final fresh = await machineA.read();
    check(
      fresh.revision == 0 &&
          fresh.installations.isEmpty &&
          fresh.defaultFFmpegId == null &&
          fresh.keepOnTop == false,
      'missing machine defaults',
    );
    check(!File(paths.machine).existsSync(), 'read has no write side effect');
    final notifications = <MachineSettings>[];
    final settingsWatch = machineA.watch().listen(
      notifications.add,
      onError: (Object _) {},
    );
    active.add(settingsWatch);
    await waitFor(() => notifications.isNotEmpty);
    final written = await machineB.save(
      fresh.copyWith(
        theme: 'dark',
        uiState: AppUiState(
          lastSizeLengthText: '1:02.5',
          popupWindowSize: PopupWindowSize(width: 1152, height: 864),
        ),
        extensions: {
          'future': {'mode': 9},
        },
      ),
      expectedRevision: 0,
    );
    check(written.revision == 1, 'machine increments revision');
    await waitFor(() => notifications.any((v) => v.revision == 1));
    final restarted = await FileMachineSettingsRepository(paths: paths).read();
    check(
      restarted.theme == 'dark' &&
          restarted.uiState!.lastSizeLengthText == '1:02.5' &&
          restarted.uiState!.popupWindowSize!.height == 864 &&
          jsonMap(restarted.extensions['future'])['mode'] == 9,
      'settings survive repository restart with extensions',
    );
    await rejects(
      () => machineA.save(fresh, expectedRevision: 0),
      'REVISION-CONFLICT',
    );
    final invalidDefault = fresh.copyWith(defaultFFmpegId: 'gone');
    await rejects(
      () => machineA.save(invalidDefault, expectedRevision: 1),
      'DEFAULT-NOT-FOUND',
    );
    check(
      (await machineA.read()).revision == 1,
      'failed save retains revision',
    );
    for (final size in [0, -1, 32769]) {
      await rejects(
        () => machineA.save(
          written.copyWith(
            uiState: written.uiState!.copyWith(
              popupWindowSize: PopupWindowSize(width: 1000, height: size),
            ),
          ),
          expectedRevision: 1,
        ),
        'INVALID-DATA',
      );
    }
    check(
      (await machineA.read()).uiState!.popupWindowSize!.width == 1152,
      'failed popup size write preserves prior persisted size',
    );
    final races = await Future.wait(
      [machineA, machineB].map((repository) async {
        try {
          await repository.save(
            written.copyWith(theme: 'light'),
            expectedRevision: 1,
          );
          return 'saved';
        } on ServiceException catch (e) {
          return e.code;
        }
      }),
    );
    check(
      races.where((v) => v == 'saved').length == 1 &&
          races.contains('REVISION-CONFLICT'),
      'same-process CAS winner is unique',
    );

    final machineBytes = await File(paths.machine).readAsBytes();
    for (final bad in [
      '{"machine":2,"revision":0}',
      '{"machine":1,"revision":0,"revision":2}',
      '{"machine":1,"revision":9223372036854775808}',
      '{"machine":1,"revision":0,"theme":null}',
    ]) {
      await File(paths.machine).writeAsString(bad);
      await rejects(
        () => machineA.read(),
        bad.startsWith('{"machine":2') ? 'UNSUPPORTED-VERSION' : 'INVALID-DATA',
      );
      check(
        await File(paths.machine).readAsString() == bad,
        'bad source is preserved',
      );
    }
    await File(paths.machine).writeAsBytes([0xff, 0xfe]);
    await rejects(() => machineA.read(), 'INVALID-DATA');
    await File(paths.machine).writeAsString('x' * (jsonFileLimit + 1));
    await rejects(() => machineA.read(), 'FILE-LIMIT');
    await File(paths.machine).writeAsBytes(machineBytes);
    await settingsWatch.cancel();
    final before = notifications.length;
    await machineB.save(await machineB.read(), expectedRevision: 2);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    check(notifications.length == before, 'cancelled settings watcher stops');
    check(
      (await machineB.watch().first).revision == 3,
      'late listener receives current value',
    );

    for (final id in [
      '../escape',
      'CON',
      'nul.user',
      'LPT1',
      'bad.',
      'with/slash',
      'a' * 129,
    ]) {
      await rejects(() async => safeId(id), 'INVALID-ID');
    }
    await rejects(
      () async => decodeJson('{"a":1,"\\u0061":2}'),
      'INVALID-DATA',
    );
    await rejects(() async => decodeJson('{"a":1e9999}'), 'INVALID-DATA');
    await rejects(
      () async => decodeJson('{"a":${'[' * 65}0${']' * 65}}'),
      'INVALID-DATA',
    );

    await rejects(() async => decodeJson(r'{"\q":1}'), 'INVALID-DATA');
    check(
      jsonMap(
            decodeJson(
              '{"extensions":{"extensions":"arbitrary metadata"}}',
            )['extensions'],
          )['extensions'] ==
          'arbitrary metadata',
      'unknown extension contents are unrestricted JSON',
    );
    final library = FilePresetLibrary(core: core, paths: paths);
    final initialPresets = await library.list();
    check(
      initialPresets.length == 16 &&
          initialPresets.every((p) => p.builtin && p.revision == 1),
      'packaged product built-ins',
    );
    final builtin = initialPresets.first;
    check(
      builtin.requires.known &&
          builtin.requires.encoders.join(',') == 'libx264,aac',
      'requirements from native normalization',
    );
    await rejects(
      () => library.save(builtin, expectedRevision: builtin.revision),
      'READ-ONLY',
    );
    final starred = await library.setPreferences(
      builtin.recipe.id,
      favorite: true,
      pinned: true,
    );
    check(
      starred.favorite &&
          starred.pinned &&
          starred.revision == builtin.revision &&
          jsonEncode(starred.recipe.data) == jsonEncode(builtin.recipe.data),
      'built-in overlays do not edit origin recipe/revision',
    );
    final afterRestart = (await FilePresetLibrary(
      core: core,
      paths: paths,
    ).get(builtin.recipe.id))!;
    check(
      afterRestart.favorite && afterRestart.pinned,
      'built-in overlay survives restart',
    );
    final transfers = PresetTransfer(library);
    final duplicate = await transfers.duplicate(
      builtin.recipe.id,
      newId: 'mine',
      name: 'Mine',
    );
    check(
      duplicate.origin == 'builtin/${builtin.recipe.id}' &&
          !duplicate.builtin &&
          duplicate.revision == 1,
      'built-in duplicate origin',
    );
    final mineDuplicate = await transfers.duplicate('mine', newId: 'mine-copy');
    check(
      mineDuplicate.origin == 'preset/mine@1',
      'Mine duplicate origin captures revision',
    );
    final unknown = duplicate.toJson();
    unknown['futureTop'] = {
      'a': [1, null, 'x'],
    };
    jsonMap(unknown['recipe']);
    final recipeMap = jsonMap(unknown['recipe']);
    recipeMap['futureRecipe'] = {'test': true};
    final videoMap = jsonMap(recipeMap['video']);
    videoMap['futureVideo'] = 'kept';
    recipeMap['video'] = videoMap;
    unknown['recipe'] = recipeMap;
    final saved = await library.save(
      Preset.fromJson(unknown),
      expectedRevision: 1,
    );
    check(
      saved.revision == 2 &&
          jsonMap(saved.recipe.video.data)['futureVideo'] == 'kept' &&
          saved.data['futureTop'] != null,
      'nested unknown keys survive save',
    );
    check(
      (await library.get('mine', revision: 1))!.recipe.name == 'Mine',
      'old revision retained',
    );
    await rejects(
      () => library.save(saved, expectedRevision: 1),
      'REVISION-CONFLICT',
    );
    await rejects(() => library.save(saved), 'REVISION-CONFLICT');
    await rejects(
      () => library.delete('mine', expectedRevision: 1),
      'REVISION-CONFLICT',
    );
    final presetBytes = await File(
      (await library.location('mine'))!,
    ).readAsBytes();
    final badRecipe = saved.copyWith(
      recipe: saved.recipe.copyWith(
        video: saved.recipe.video.copyWith(depth: 10, profile: 'high'),
      ),
    );
    await rejects(
      () => library.save(badRecipe, expectedRevision: 2),
      'RECIPE-INVALID',
    );
    check(
      base64.encode(
            await File((await library.location('mine'))!).readAsBytes(),
          ) ==
          base64.encode(presetBytes),
      'semantic rejection preserves current preset bytes',
    );

    var latest = saved;
    for (var i = 0; i < 25; i++) {
      latest = await library.save(
        latest.copyWith(recipe: latest.recipe.copyWith(name: 'Revision $i')),
        expectedRevision: latest.revision,
      );
    }
    check(
      await library.get('mine', revision: 6) == null &&
          (await library.get('mine', revision: 7)) != null,
      'only last 20 old revisions retained',
    );
    final history = Directory(
      joinPath(joinPath(paths.library, '.history'), 'mine'),
    );
    check(
      (await history.list().where((e) => e.path.endsWith('.vepreset')).toList())
              .length ==
          20,
      'bounded history files',
    );
    final share = await transfers.shareString('mine');
    final shared = await transfers.importShareString(share, newId: 'shared');
    check(
      shared.recipe.data['futureRecipe'] != null &&
          shared.data['futureTop'] != null,
      'share round trip preserves extensions',
    );
    await rejects(
      () => transfers.importShareString('vepreset:2:x', newId: 'version'),
      'SHARE-VERSION',
    );
    await rejects(
      () => transfers.importShareString('vepreset:1:%bad', newId: 'bad'),
      'SHARE-INVALID',
    );
    final exportPath = joinPath(root.path, 'selected export.vepreset');
    await transfers.exportTo('mine', exportPath);
    check(
      await File(exportPath).readAsString() ==
          await library.exportPreset('mine'),
      'export goes to selected path',
    );
    final importPath = joinPath(root.path, '导入 preset.vepreset');
    final sourceText = await File(exportPath).readAsString();
    await File(importPath).writeAsString(sourceText);
    final importedFile = await transfers.importFrom(
      importPath,
      newId: 'from-file',
    );
    check(
      importedFile.recipe.id == 'from-file' &&
          importedFile.recipe.name == latest.recipe.name &&
          importedFile.revision == 1 &&
          !importedFile.builtin &&
          importedFile.origin == latest.origin &&
          importedFile.recipe.data['futureRecipe'] != null &&
          importedFile.data['futureTop'] != null &&
          importedFile.requires.known,
      'selected Unicode file imports through native validation with a new identity and unknown metadata',
    );
    final importedBytes = await File(
      (await library.location('from-file'))!,
    ).readAsString();
    await rejects(
      () => transfers.importFrom(importPath, newId: 'from-file'),
      'REVISION-CONFLICT',
    );
    check(
      await File((await library.location('from-file'))!).readAsString() ==
              importedBytes &&
          await File(importPath).readAsString() == sourceText,
      'import collision preserves the existing preset and source file',
    );
    await rejects(
      () => transfers.importFrom(
        joinPath(root.path, 'missing.vepreset'),
        newId: 'missing-import',
      ),
      'NOT-FOUND',
    );
    await rejects(
      () => transfers.importFrom(root.path, newId: 'directory-import'),
      'FILE-READ',
    );
    await rejects(
      () => transfers.importFrom(importPath, newId: '../unsafe'),
      'INVALID-ID',
    );
    final invalidSources = <(String, List<int>, String)>[
      ('utf8', [0xff], 'INVALID-DATA'),
      ('malformed', utf8.encode('{bad'), 'INVALID-DATA'),
      ('duplicate', utf8.encode('{"vepreset":1,"vepreset":1}'), 'INVALID-DATA'),
      (
        'future-file',
        utf8.encode(jsonEncode({...latest.toJson(), 'vepreset': 2})),
        'UNSUPPORTED-VERSION',
      ),
      (
        'bad-recipe-file',
        utf8.encode(jsonEncode(badRecipe.data)),
        'RECIPE-INVALID',
      ),
      ('oversize', List.filled(jsonFileLimit + 1, 32), 'FILE-LIMIT'),
    ];
    for (final (id, bytes, code) in invalidSources) {
      await File(importPath).writeAsBytes(bytes);
      await rejects(() => transfers.importFrom(importPath, newId: id), code);
      check(
        await library.get(id) == null &&
            base64Encode(await File(importPath).readAsBytes()) ==
                base64Encode(bytes),
        'failed file import leaves its source intact and creates no preset: $id',
      );
    }
    await File(
      importPath,
    ).writeAsString(await library.exportPreset(builtin.recipe.id));
    final importedBuiltin = await transfers.importFrom(
      importPath,
      newId: 'builtin-file',
    );
    check(
      importedBuiltin.origin == 'builtin/${builtin.recipe.id}' &&
          !importedBuiltin.builtin &&
          importedBuiltin.revision == 1,
      'file import preserves built-in copy origin',
    );
    final advanced = latest.copyWith(
      recipe: latest.recipe.copyWith(
        id: 'advanced',
        command: CommandSettings(
          mode: 'template',
          template: '{inputs} -c:v ffv1 -c:a pcm_f32le -f matroska {output}',
        ),
      ),
    );
    final savedAdvanced = await library.save(advanced);
    check(
      !savedAdvanced.requires.known && savedAdvanced.requires.encoders.isEmpty,
      'Advanced requirements remain unknown',
    );
    final invalidImport = jsonDecode(await library.exportPreset('mine')) as Map;
    invalidImport['vepreset'] = 2;
    await rejects(
      () => library.importPreset(jsonEncode(invalidImport), newId: 'future'),
      'UNSUPPORTED-VERSION',
    );
    check(await library.get('future') == null, 'future import creates no file');
    await library.delete('mine-copy', expectedRevision: 1);
    check(
      await library.get('mine-copy') == null &&
          (await library.get('mine-copy', revision: 1)) != null,
      'delete preserves last version for recovery',
    );

    await rejects(() => library.save(mineDuplicate), 'REVISION-CONFLICT');
    for (var i = 0; i < 23; i++) {
      await library.setPreferences('shared', favorite: i.isEven);
    }
    check(
      (await Directory(
                joinPath(joinPath(paths.library, '.history'), 'shared'),
              ).list().where((f) => f.path.endsWith('.vepreset')).toList())
              .length ==
          20,
      'metadata changes also bound revision history',
    );
    check(
      await library.location(builtin.recipe.id) == null,
      'built-in has no user file to reveal',
    );
    final cache = FileCapabilityCache(paths: paths);
    final cap = FFmpegCapabilities(
      installationId: 'local',
      identityKey: 'identity-1',
      version: 'test',
      probedAt: '2026-10-14T00:00:00Z',
      encoders: {
        'libx264': {
          'kind': 'video',
          'pixelFormats': ['yuv420p'],
          'future': 3,
        },
      },
      muxers: {
        'mp4': {'flags': 'E'},
      },
      libavformatMajor: 63,
    );
    check(
      await cache.read(cap.identityKey) == null,
      'missing capability cache',
    );
    await cache.write(cap);
    final cached = (await FileCapabilityCache(
      paths: paths,
    ).read(cap.identityKey))!;
    check(
      cached.libavformatMajor == 63 &&
          jsonMap(cached.encoders['libx264'])['future'] == 3,
      'capabilities survive disk with build/unknown facts',
    );
    check(
      await FileCapabilityCache(
            paths: paths,
            parserVersion: 2,
          ).read(cap.identityKey) ==
          null,
      'parser mismatch is a cache miss',
    );
    await rejects(
      () => FileCapabilityCache(paths: paths, parserVersion: 2).write(cap),
      'CACHE-PARSER',
    );
    await cache.invalidate(cap.identityKey);
    check(
      await cache.read(cap.identityKey) == null,
      'explicit cache invalidation',
    );

    final cachePath = joinPath(paths.cache, '${cap.identityKey}.json');
    await atomicWrite(cachePath, '{"cache":2,"capabilities":{}}');
    await rejects(() => cache.write(cap), 'UNSUPPORTED-VERSION');
    check(
      await File(cachePath).readAsString() == '{"cache":2,"capabilities":{}}',
      'newer cache bytes are preserved on write',
    );
    await cache.invalidate(cap.identityKey);
    final liveFile = joinPath(root.path, 'job.live.json');
    final liveReader = FileLiveRenderStatusReader(
      interval: const Duration(milliseconds: 20),
    );
    final live = <LiveRenderStatus?>[];
    final liveWatch = liveReader.watch(liveFile).listen(live.add);
    active.add(liveWatch);
    await waitFor(() => live.isNotEmpty);
    check(live.first == null, 'missing startup live file is null');
    final starting = FakeLiveRenderStatusReader.samples().first;
    final legacy = starting.toJson()
      ..remove('outputBitDepth')
      ..remove('pixelFormatConversionReducesPrecision');
    await atomicWrite(liveFile, jsonEncode(legacy));
    await waitFor(() => live.last?.sequence == 1);
    final good = live.last;
    check(
      good!.outputBitDepth == null &&
          good.pixelFormatConversionReducesPrecision == null &&
          !good.toJson().containsKey('outputBitDepth'),
      'older C5 files read with unknown video facts and no implicit defaults',
    );
    for (final invalid in [
      for (final depth in [0, -1, 8.0, '8', true])
        starting.copyWith(sequence: 2, outputBitDepth: depth),
      for (final reduces in [0, 'false'])
        starting.copyWith(
          sequence: 2,
          pixelFormatConversionReducesPrecision: reduces,
        ),
    ]) {
      await atomicWrite(liveFile, jsonEncode(invalid.data));
      await rejects(() => liveReader.read(liveFile), 'INVALID-DATA');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      check(
        identical(live.last, good),
        'invalid video fact retains last valid live status',
      );
    }
    for (final bad in [
      '{"live":1',
      jsonEncode(starting.copyWith(sequence: 0, state: RenderState.done).data),
      jsonEncode(
        starting
            .copyWith(sequence: 2, jobId: 'other', state: RenderState.failed)
            .data,
      ),
      jsonEncode(starting.copyWith(sequence: 2, live: 2).data),
    ]) {
      await atomicWrite(liveFile, bad);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      check(
        identical(live.last, good),
        'malformed/out-of-order/other-job/future live snapshot retains last good value',
      );
    }
    await removeLive(File(liveFile));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    check(
      live.last!.state == RenderState.starting,
      'disappearance does not infer terminal state',
    );
    await atomicWrite(
      liveFile,
      jsonEncode(
        starting
            .copyWith(
              sequence: 2,
              state: RenderState.encoding,
              outputBitDepth: 10,
              pixelFormatConversionReducesPrecision: false,
            )
            .data,
      ),
    );
    await waitFor(() => live.last?.sequence == 2);
    check(
      live.last!.outputBitDepth == 10 &&
          live.last!.pixelFormatConversionReducesPrecision == false &&
          (await liveReader.read(liveFile))!.outputBitDepth == 10,
      'repaired C5 read and watch carry known depth without precision reduction',
    );
    await atomicWrite(
      liveFile,
      jsonEncode(starting.copyWith(sequence: 3).data),
    );
    await waitFor(() => live.last?.sequence == 3);
    check(
      live.last!.outputBitDepth == null &&
          live.last!.pixelFormatConversionReducesPrecision == null,
      'explicit null video facts stay unknown after a known status',
    );
    await liveWatch.cancel();

    final jobs = FileJobRepository(core: core, paths: paths);
    check((await jobs.list()).isEmpty, 'missing job root');
    final fakeJobs = FakeJobRepository();
    final jobId = (await fakeJobs.list()).first.id;
    final oldJob = (await fakeJobs.get(jobId))!;
    final job = oldJob.copyWith(
      logFile: '$jobId.ffmpeg.log',
      commandLine: 'recorded command',
      durationSec: 60,
      realtime: 1.5,
      errorTokenIndices: [0],
    );
    await atomicWrite(
      joinPath(paths.jobs, '$jobId.json'),
      jsonEncode(job.data),
    );
    check(
      (await jobs.list()).single.durationSec == 60 &&
          (await jobs.list()).single.realtime == 1.5,
      'missing index reconstructs complete record including recorded speed',
    );
    await jobs.rebuildIndex();
    final indexPath = joinPath(paths.jobs, 'jobs.jsonl');
    await File(indexPath).writeAsString('{"index":', mode: FileMode.append);
    check(
      (await jobs.list()).length == 1 &&
          (await jobs.list()).single.realtime == 1.5,
      'truncated final job index line ignored without losing speed',
    );
    check(
      (await jobs.get(jobId))!.commandLine == 'recorded command' &&
          (await jobs.get(jobId))!.errorTokenIndices.single == 0,
      'job command/realtime/error indexes round trip',
    );
    final logPath = joinPath(paths.jobs, '$jobId.ffmpeg.log');
    final completeLog = 'test log ü\n' * 150000;
    await File(logPath).writeAsString(completeLog);
    check(
      await jobs.readLog(jobId).join() == completeLog,
      'full log streams beyond JSON size limit',
    );
    await atomicWrite(
      joinPath(paths.jobs, '$jobId.json'),
      jsonEncode(job.copyWith(logFile: '../private.txt').data),
    );
    await rejects(() => jobs.logLocation(jobId), 'INVALID-DATA');
    await atomicWrite(
      joinPath(paths.jobs, '$jobId.json'),
      jsonEncode(job.data),
    );
    await File(indexPath).writeAsString('\n', mode: FileMode.append);
    await rejects(() => jobs.list(), 'INVALID-DATA');
    await jobs.rebuildIndex();
    check(
      (await jobs.list()).single.id == jobId,
      'explicit index reconstruction recovers interrupted append',
    );
    final speedEntry = (await jobs.list()).single.toJson();
    speedEntry['futureField'] = {'preserved': true};
    speedEntry.remove('realtime');
    await File(indexPath).writeAsString('${jsonEncode(speedEntry)}\n');
    final legacyIndex = (await jobs.list()).single;
    check(
      legacyIndex.realtime == null &&
          !legacyIndex.toJson().containsKey('realtime') &&
          legacyIndex.copyWith(realtime: 0.75).data['futureField'] != null &&
          legacyIndex.copyWith(realtime: null).realtime == null,
      'legacy index speed stays absent and copies preserve unknown fields',
    );
    for (final invalidSpeed in [-1, 'fast', true]) {
      await File(indexPath).writeAsString(
        '${jsonEncode({...speedEntry, 'realtime': invalidSpeed})}\n',
      );
      await rejects(() => jobs.list(), 'INVALID-DATA');
    }
    await jobs.rebuildIndex();
    final fromHistory = await transfers.fromJob(job, newId: 'history-copy');
    check(
      fromHistory.origin == 'job/$jobId',
      'History copy has a stable job origin',
    );
    final indexBad = (await jobs.list()).single.toJson();
    indexBad['recordFile'] = '../private.json';
    await File(indexPath).writeAsString('${jsonEncode(indexBad)}\n');
    await rejects(() => jobs.list(), 'INVALID-DATA');
    await atomicWrite(
      joinPath(paths.jobs, '$jobId.json'),
      jsonEncode(job.copyWith(published: false).data),
    );
    await rejects(() => jobs.get(jobId), 'INVALID-DATA');
    await atomicWrite(
      joinPath(paths.jobs, '$jobId.json'),
      jsonEncode(job.data),
    );
    await fakeJobs.dispose();
    final badMedia = job.toJson();
    final badMediaData = jsonMap(badMedia['media']);
    badMediaData['durationSec'] = 'unknown';
    badMedia['media'] = badMediaData;
    await atomicWrite(
      joinPath(paths.jobs, '$jobId.json'),
      jsonEncode(badMedia),
    );
    await rejects(() => jobs.get(jobId), 'INVALID-DATA');
    final badDimensions = job.media.video.copyWith(width: -1);
    await atomicWrite(
      joinPath(paths.jobs, '$jobId.json'),
      jsonEncode(
        job.copyWith(media: job.media.copyWith(video: badDimensions)).data,
      ),
    );
    await rejects(() => jobs.get(jobId), 'INVALID-DATA');
    await atomicWrite(
      joinPath(paths.jobs, '$jobId.json'),
      jsonEncode(job.data),
    );

    final requestFake = FakeEditSessionService();
    final request = await requestFake.readRequest('b0-session');
    final session = joinPath(root.path, 'session');
    await atomicWrite(
      joinPath(session, 'request.json'),
      jsonEncode(request.data),
    );
    final sessions = FileEditSessionService(core: core);
    check(
      (await sessions.readRequest(session)).sessionId == request.sessionId,
      'native-validated request',
    );
    await rejects(
      () => sessions.writeResult(
        session,
        EditSessionResult(sessionId: 'wrong', action: 'cancel'),
      ),
      'SESSION-MISMATCH',
    );
    await rejects(
      () => sessions.writeResult(
        session,
        EditSessionResult(sessionId: request.sessionId, action: 'apply'),
      ),
      'SESSION-RESULT',
    );
    await rejects(
      () => sessions.writeResult(
        session,
        EditSessionResult(
          sessionId: request.sessionId,
          action: 'cancel',
          recipe: request.recipe,
        ),
      ),
      'SESSION-RESULT',
    );
    final result = EditSessionResult(
      sessionId: request.sessionId,
      action: 'apply',
      recipe: request.recipe,
      origin: request.origin,
      extensions: {'new': true},
    );
    final sessionRaces = await Future.wait(
      [sessions, FileEditSessionService(core: core)].map((service) async {
        try {
          await service.writeResult(session, result);
          return 'saved';
        } on ServiceException catch (e) {
          return e.code;
        }
      }),
    );
    check(
      sessionRaces.where((v) => v == 'saved').length == 1 &&
          sessionRaces.contains('SESSION-CLOSED'),
      'one final result across service instances',
    );
    final finalBytes = await File(
      joinPath(session, 'result.json'),
    ).readAsString();
    await rejects(
      () => sessions.writeResult(session, result),
      'SESSION-CLOSED',
    );
    check(
      finalBytes == await File(joinPath(session, 'result.json')).readAsString(),
      'closed session result preserved',
    );

    final cancelDirectory = joinPath(root.path, 'cancel-session');
    await atomicWrite(
      joinPath(cancelDirectory, 'request.json'),
      jsonEncode(request.data),
    );
    await sessions.writeResult(
      cancelDirectory,
      EditSessionResult(sessionId: request.sessionId, action: 'cancel'),
    );
    check(
      jsonDecode(
            await File(joinPath(cancelDirectory, 'result.json')).readAsString(),
          )['recipe'] ==
          null,
      'cancel carries no draft',
    );
    await atomicWrite(
      joinPath(cancelDirectory, 'request.json'),
      jsonEncode(request.copyWith(protocol: 2).data),
    );
    await rejects(
      () => sessions.readRequest(cancelDirectory),
      'SESSION-REQUEST',
    );
    final fakeLibrary = FakePresetLibrary();
    final fakeBuiltin = (await fakeLibrary.list()).first;
    check(
      (await fakeLibrary.setPreferences(
            fakeBuiltin.recipe.id,
            favorite: true,
          )).revision ==
          fakeBuiltin.revision,
      'fake built-in preferences preserve revision',
    );
    final fakeTransfer = FakePresetTransfer(fakeLibrary);
    await fakeTransfer.exportTo(fakeBuiltin.recipe.id, 'selected.fake');
    check(
      fakeTransfer.exported.containsKey('selected.fake'),
      'fake export has no filesystem access',
    );
    final reveal = FakeFileReveal();
    await reveal.reveal('selected.fake');
    check(
      reveal.revealed.single == 'selected.fake',
      'fake reveal records the request',
    );
    await fakeLibrary.dispose();
    // Separate VMs exercise the Windows byte-range lock, not a Dart mutex.
    await contend(root.path, paths, children, 'settings');
    await contend(root.path, paths, children, 'preset');
    final lockPath = joinPath(root.path, 'crash.lock');
    final ready = joinPath(root.path, 'crash.ready');
    final lockedChild = await spawnWorker(['hold', lockPath, ready]);
    children.add(lockedChild);
    await waitFor(() => File(ready).existsSync());
    await rejects(
      () => withFileLock(
        lockPath,
        () async => 1,
        timeout: const Duration(milliseconds: 80),
      ),
      'STORE-BUSY',
    );
    check(lockedChild.kill(ProcessSignal.sigkill), 'test lock owner is killed');
    await lockedChild.exitCode;
    check(
      await withFileLock(lockPath, () async => 7) == 7,
      'OS releases crash-owned lock with persistent lock file',
    );

    // A replacement failure never deletes a destination or leaks adjacent temp.
    final destination = Directory(joinPath(root.path, 'destination-directory'));
    await destination.create();
    await rejects(() => atomicWrite(destination.path, '{}'), 'FILE-WRITE');
    check(
      await destination.exists(),
      'failed replacement preserves destination',
    );
    final lockedData = File(joinPath(root.path, 'locked.json'));
    await lockedData.writeAsString('old');
    final heldReader = await lockedData.open();
    final retryTime = Stopwatch()..start();
    await rejects(() => atomicWrite(lockedData.path, 'new'), 'FILE-WRITE');
    check(
      retryTime.elapsedMilliseconds < 1500 &&
          await lockedData.readAsString() == 'old',
      'bounded sharing retry preserves previous bytes',
    );
    await heldReader.close();
    await atomicWrite(lockedData.path, 'new');
    check(
      await lockedData.readAsString() == 'new',
      'write recovers after reader closes',
    );
    final leftovers = await root
        .list(recursive: true, followLinks: false)
        .where((e) => e.path.endsWith('.tmp'))
        .toList();
    check(leftovers.isEmpty, 'successful/failed writes leave no temp files');
    print(
      'B3 REPOSITORIES PASSED: $checks checks; real Windows files/locks and native core, synthetic records; no VEGAS.',
    );
  } finally {
    for (final subscription in active) {
      await subscription.cancel();
    }
    for (final child in children) {
      child.kill(ProcessSignal.sigkill);
    }
    // Delete only this run's createTemp result under the verified test root.
    final resolved = await root.resolveSymbolicLinks();
    final boundary = await build.resolveSymbolicLinks();
    if (!resolved.toLowerCase().startsWith(
      '${boundary.toLowerCase()}${Platform.pathSeparator}',
    ))
      throw StateError('Unsafe test cleanup root.');
    await root.delete(recursive: true);
  }
}

Future<Process> spawnWorker(List<String> args) => Process.start(
  Platform.resolvedExecutable,
  ['--worker', ...args],
  runInShell: false,
);

Future<void> contend(
  String root,
  ServicePaths paths,
  List<Process> children,
  String kind,
) async {
  final go = joinPath(root, '$kind.go');
  final ready = [for (var i = 0; i < 2; i++) joinPath(root, '$kind.$i.ready')];
  final processes = <Process>[];
  final outputs = <Future<String>>[];
  final errors = <Future<String>>[];
  final exited = <int, int>{};
  for (var i = 0; i < 2; i++) {
    final process = await spawnWorker([
      kind,
      paths.roaming,
      paths.local,
      ready[i],
      go,
    ]);
    processes.add(process);
    children.add(process);
    outputs.add(process.stdout.transform(utf8.decoder).join());
    errors.add(process.stderr.transform(utf8.decoder).join());
    unawaited(
      process.exitCode.then((code) {
        exited[i] = code;
      }),
    );
  }
  await waitFor(
    () => ready.every((p) => File(p).existsSync()) || exited.isNotEmpty,
    seconds: 40,
  );
  if (!ready.every((p) => File(p).existsSync())) {
    for (final process in processes) {
      process.kill(ProcessSignal.sigkill);
    }
    throw StateError(
      'Worker exited before barrier: ${await Future.wait(outputs)} ${await Future.wait(errors)}',
    );
  }
  await File(go).writeAsString('go');
  final codes = await Future.wait(processes.map((p) => p.exitCode));
  check(codes.every((v) => v == 0), '$kind workers exit cleanly');
  final text = await Future.wait(outputs);
  check(
    text.where((v) => v.contains('RESULT:saved')).length == 1 &&
        text.where((v) => v.contains('RESULT:REVISION-CONFLICT')).length == 1,
    'cross-process $kind revision winner is unique: $text',
  );
}

Future<void> worker(List<String> args) async {
  if (args.first == 'hold') {
    await withFileLock(args[1], () async {
      await File(args[2]).writeAsString('ready');
      await Future<void>.delayed(const Duration(seconds: 30));
    });
    return;
  }
  final paths = ServicePaths(roaming: args[1], local: args[2]);
  final settings = FileMachineSettingsRepository(paths: paths);
  final currentSettings = await settings.read();
  final library = args.first == 'preset'
      ? FilePresetLibrary(core: NativeVeCore(), paths: paths)
      : null;
  final preset = await library?.get('shared');
  await File(args[3]).writeAsString('ready');
  await waitFor(() => File(args[4]).existsSync());
  try {
    if (library == null) {
      await settings.save(
        currentSettings.copyWith(theme: 'system'),
        expectedRevision: currentSettings.revision,
      );
    } else {
      await library.save(preset!, expectedRevision: preset.revision);
    }
    print('RESULT:saved');
  } on ServiceException catch (e) {
    print('RESULT:${e.code}');
  }
}
