import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';
import 'package:ve_services/ve_services.dart';
import 'package:ve_services/src/storage.dart';

@Native<Int32 Function(Pointer<Uint16>, Uint32, Pointer<Uint8>, Uint32)>(
  symbol: 've_library_metadata',
  assetId: 'package:ve_services/src/windows_gpu.dart',
)
external int metadata(
  Pointer<Uint16> directory,
  int length,
  Pointer<Uint8> buffer,
  int capacity,
);

void metadataBounds(String root) {
  const capacity = 1048576;
  final normalized = Directory(root).absolute.uri.normalizePath().toFilePath();
  final path = normalized.toNativeUtf16(allocator: calloc);
  final buffer = calloc<Uint8>(capacity + 16);
  try {
    buffer.asTypedList(capacity + 16).fillRange(capacity, capacity + 16, 0xa5);
    check(
      metadata(path.cast(), normalized.length, buffer, capacity) > 0,
      'counted UTF-16 Unicode directory path',
    );
    check(metadata(nullptr, 0, buffer, capacity) == -1, 'null input rejected');
    check(
      metadata(path.cast(), 32701, buffer, capacity) == -1,
      'path bound checked before reading',
    );
    check(
      metadata(path.cast(), normalized.length + 1, buffer, capacity) == -1,
      'embedded NUL rejected',
    );
    check(
      metadata(path.cast(), normalized.length, nullptr, capacity) == -1,
      'null output rejected',
    );
    check(
      metadata(path.cast(), normalized.length, buffer, 0) == -1,
      'zero capacity rejected',
    );
    check(
      metadata(path.cast(), normalized.length, buffer, capacity + 1) == -1,
      'capacity bound rejected',
    );
    check(
      metadata(path.cast(), normalized.length, buffer, 4) == -2,
      'small buffer gives fallback instead of partial JSON',
    );
    for (var i = 0; i < 16; i++)
      check(
        buffer.asTypedList(capacity + 16)[capacity + i] == 0xa5,
        'output guard $i intact',
      );
  } finally {
    calloc.free(path);
    calloc.free(buffer);
  }
}

int checks = 0;
void check(bool ok, String message) {
  checks++;
  if (!ok) throw StateError(message);
}

Future<void> until(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) throw StateError('Watch timed out.');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

// A call counter around the real native core, not an alternate domain engine.
class CountingCore implements VeCore {
  CountingCore(this.native);
  final NativeVeCore native;
  int normalizes = 0;
  @override
  NormalizeResult normalize(JsonMap json) {
    normalizes++;
    return native.normalize(json);
  }

  @override
  List<Issue> validate(
    Recipe recipe, {
    MediaDescription? media,
    CoreCapabilities? capabilities,
  }) => native.validate(recipe, media: media, capabilities: capabilities);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, double> timings(List<double> values) {
  values.sort();
  return {
    'medianMs': values[values.length ~/ 2],
    'p95Ms': values[((values.length - 1) * .95).round()],
    'maxMs': values.last,
  };
}

Map<String, double> enumerationTiming(String directory) {
  final normalized = Directory(
    directory,
  ).absolute.uri.normalizePath().toFilePath();
  final path = normalized.toNativeUtf16(allocator: calloc);
  final buffer = calloc<Uint8>(1048576);
  try {
    final values = <double>[];
    for (var i = 0; i < 50; i++) {
      final clock = Stopwatch()..start();
      final length = metadata(path.cast(), normalized.length, buffer, 1048576);
      values.add(clock.elapsedMicroseconds / 1000);
      if (length < 0) throw StateError('Metadata scan failed: $length');
    }
    return timings(values);
  } finally {
    calloc.free(buffer);
    calloc.free(path);
  }
}

Future<void> main() async {
  final build = Directory('../../build/test-results').absolute;
  await build.create(recursive: true);
  final root = await build.createTemp('library-watch-编码-');
  final paths = ServicePaths(
    roaming: joinPath(root.path, 'roaming'),
    local: joinPath(root.path, 'local'),
  );
  final core = CountingCore(NativeVeCore());
  final library = FilePresetLibrary(core: core, paths: paths);
  final other = FilePresetLibrary(core: core.native, paths: paths);
  final subscriptions = <StreamSubscription<Object?>>[];
  try {
    metadataBounds(root.path);
    final builtins = await library.list();
    check(
      builtins.length == 6 && !Directory(paths.library).existsSync(),
      'missing root is read-only and supplies built-ins',
    );
    for (var i = 0; i < 494; i++) {
      final source = builtins[i % builtins.length];
      final preset = source.copyWith(
        builtin: false,
        recipe: source.recipe.copyWith(
          id: 'watch-${i.toString().padLeft(4, '0')}',
          name: 'Preset $i A',
        ),
      );
      await atomicWrite(
        joinPath(paths.library, '${preset.recipe.id}.vepreset'),
        jsonEncode(preset.data),
      );
    }
    core.normalizes = 0;
    final cold = Stopwatch()..start();
    final initial = await library.list();
    cold.stop();
    check(
      initial.length == 500 && core.normalizes == 988,
      'new files decoded and requirements derived by native core once per new entry',
    );
    final calls = core.normalizes;
    final wall = <double>[];
    for (var i = 0; i < 50; i++) {
      final watch = Stopwatch()..start();
      final current = await library.list();
      wall.add(watch.elapsedMicroseconds / 1000);
      check(
        identical(current, initial),
        'unchanged poll reuses immutable snapshot $i',
      );
    }
    check(
      core.normalizes == calls,
      '50 unchanged scans make zero native core calls',
    );
    await Directory(joinPath(paths.library, 'ignored.vepreset')).create();
    await File(joinPath(paths.library, 'unrelated.json')).writeAsBytes([0xff]);
    check(
      identical(await library.list(), initial) && core.normalizes == calls,
      'directories and unrelated files do not invalidate preset snapshots',
    );
    final first = library.list(), second = library.list();
    check(
      identical(first, second) && identical(await first, await second),
      'concurrent lists share one scan',
    );
    final report = {
      'presets': initial.length,
      'samples': wall.length,
      'coldMs': cold.elapsedMicroseconds / 1000,
      'nativeEnumeration': enumerationTiming(paths.library),
      'unchanged': timings(wall),
      'unchangedCoreNormalizeCalls': core.normalizes - calls,
    };
    print('LIBRARY WATCH TIMING ${jsonEncode(report)}');

    final snapshots = <List<Preset>>[], lateSnapshots = <List<Preset>>[];
    final errors = <Object>[];
    final sub = library.watch().listen(snapshots.add, onError: errors.add);
    subscriptions.add(sub);
    await until(() => snapshots.isNotEmpty);
    final late = library.watch().listen(lateSnapshots.add, onError: errors.add);
    subscriptions.add(late);
    await until(() => lateSnapshots.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    check(
      snapshots.length == 1 &&
          lateSnapshots.length == 1 &&
          core.normalizes == calls,
      'each listener gets current once; unchanged ticks neither emit nor normalize',
    );

    final added = await other.save(
      builtins.first.copyWith(
        builtin: false,
        recipe: builtins.first.recipe.copyWith(id: 'added', name: 'Added A'),
      ),
    );
    await until(
      () => snapshots.last.length == 501 && lateSnapshots.last.length == 501,
    );
    check(
      core.normalizes == calls + 2,
      'two listeners decode only the externally added file',
    );
    final addedPath = joinPath(paths.library, 'added.vepreset');
    final beforeSize = (await File(addedPath).stat()).size;
    await atomicWrite(
      addedPath,
      jsonEncode(
        added.copyWith(recipe: added.recipe.copyWith(name: 'Added B')).data,
      ),
    );
    await until(() => snapshots.last.any((p) => p.recipe.name == 'Added B'));
    check(
      (await File(addedPath).stat()).size == beforeSize &&
          core.normalizes == calls + 4,
      'same-size external edit is detected without re-reading unchanged entries',
    );

    final beforePreferences = core.normalizes;
    await other.setPreferences(
      builtins.first.recipe.id,
      favorite: !builtins.first.favorite,
    );
    await until(() => snapshots.last.first.favorite != builtins.first.favorite);
    check(
      core.normalizes == beforePreferences,
      'preferences overlay changes without native recipe work',
    );
    final preferences = await File(paths.preferences).readAsBytes();
    await File(paths.preferences).writeAsString('{bad');
    await until(
      () =>
          errors.any((e) => e is ServiceException && e.code == 'INVALID-DATA'),
    );
    await File(paths.preferences).writeAsBytes(preferences);
    await library.list();
    await File(paths.preferences).delete();
    await until(() => snapshots.last.first.favorite == builtins.first.favorite);
    check(
      core.normalizes == beforePreferences,
      'malformed preferences recover and removal restores defaults',
    );
    final beforeDirectoryError = errors.length;
    final beforeDirectorySnapshot = snapshots.last;
    await Directory(paths.preferences).create();
    await until(() => errors.length > beforeDirectoryError);
    check(
      errors.last is ServiceException &&
          (errors.last as ServiceException).code == 'FILE-READ' &&
          identical(snapshots.last, beforeDirectorySnapshot),
      'preferences directory emits a read error and retains the last snapshot',
    );
    try {
      await library.list();
      throw StateError('Preferences directory was hidden by cache.');
    } on ServiceException catch (e) {
      check(
        e.code == 'FILE-READ',
        'explicit list rejects preferences directory',
      );
    }
    await Directory(paths.preferences).delete();
    check(
      identical(await library.list(), beforeDirectorySnapshot),
      'removing preferences directory recovers the cached default snapshot',
    );

    final good = await File(addedPath).readAsString();
    final lastGood = snapshots.last;
    await atomicWrite(addedPath, '{"vepreset":2}');
    await until(
      () => errors.any(
        (e) => e is ServiceException && e.code == 'UNSUPPORTED-VERSION',
      ),
    );
    check(
      identical(snapshots.last, lastGood),
      'malformed replacement emits an error and keeps last published snapshot',
    );
    try {
      await library.list();
      throw StateError('Malformed file was hidden by cache.');
    } on ServiceException catch (e) {
      check(
        e.code == 'UNSUPPORTED-VERSION',
        'explicit list still rejects malformed file',
      );
    }
    final repaired = Preset.fromJson(jsonMap(jsonDecode(good)));
    await atomicWrite(
      addedPath,
      jsonEncode(
        repaired
            .copyWith(recipe: repaired.recipe.copyWith(name: 'Added C'))
            .data,
      ),
    );
    await until(() => snapshots.last.any((p) => p.recipe.name == 'Added C'));
    check(snapshots.last.length == 501, 'repair is revalidated and published');
    await other.delete('added', expectedRevision: added.revision);
    await until(
      () => snapshots.last.length == 500 && lateSnapshots.last.length == 500,
    );
    final afterDelete = core.normalizes;
    await atomicWrite(addedPath, good);
    await until(() => snapshots.last.length == 501);
    check(
      core.normalizes == afterDelete + 2,
      'deleted entry is evicted; restoring it revalidates',
    );

    // Own writes invalidate even when an editor restores the prior metadata.
    final stamp = await File(addedPath).lastModified();
    final own = await library.save(
      repaired.copyWith(recipe: repaired.recipe.copyWith(name: 'Added D')),
      expectedRevision: repaired.revision,
    );
    await File(addedPath).setLastModified(stamp);
    check(
      (await library.list()).any((p) => p.recipe.name == own.recipe.name),
      'own successful save cannot reuse a stale cache entry',
    );
    final unchanged = await library.list();
    await atomicWrite(addedPath, await File(addedPath).readAsString());
    final notifications = snapshots.length;
    await library.list();
    await Future<void>.delayed(const Duration(milliseconds: 550));
    check(
      snapshots.last.any((p) => p.recipe.name == own.recipe.name) &&
          snapshots.length <= notifications + 1,
      'identical content rewrite does not manufacture extra watch events',
    );
    check(unchanged.length == 501, 'snapshot retained across later changes');

    for (final active in subscriptions) await active.cancel();
    subscriptions.clear();
    final cancelledCalls = core.normalizes;
    final cancelledEvents = snapshots.length;
    await atomicWrite(addedPath, good);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    check(
      core.normalizes == cancelledCalls && snapshots.length == cancelledEvents,
      'cancelled watchers stop work and delivery',
    );

    // Deliberately preserve every cached stamp. Lists may miss this external edit,
    // but an explicit get and Save/CAS must still read the authoritative bytes.
    final authoritativeFile = File(addedPath);
    final fixedTime = DateTime.utc(2026, 1, 1);
    await authoritativeFile.setLastModified(fixedTime);
    final cachedSnapshot = await library.list();
    final cachedPreset = cachedSnapshot.firstWhere(
      (p) => p.recipe.id == 'added',
    );
    final external = cachedPreset.copyWith(
      revision: cachedPreset.revision + 1,
      recipe: cachedPreset.recipe.copyWith(name: 'Added Z'),
    );
    final cachedBytes = await authoritativeFile.length();
    await authoritativeFile.writeAsString(
      jsonEncode(external.data),
      flush: true,
    );
    await authoritativeFile.setLastModified(fixedTime);
    check(
      await authoritativeFile.length() == cachedBytes &&
          identical(await library.list(), cachedSnapshot),
      'metadata-preserving external edit can retain the list cache',
    );
    check(
      (await library.get('added'))!.recipe.name == 'Added Z',
      'explicit get bypasses the list cache',
    );
    try {
      await library.save(cachedPreset, expectedRevision: cachedPreset.revision);
      throw StateError('Save/CAS used a cached revision.');
    } on ServiceException catch (e) {
      check(
        e.code == 'REVISION-CONFLICT',
        'Save/CAS uses the on-disk revision',
      );
    }

    var reads = 0;
    final paused = watchSnapshots(() async => ++reads).listen((_) {});
    subscriptions.add(paused);
    await until(() => reads > 0);
    paused.pause();
    final pausedReads = reads;
    await Future<void>.delayed(const Duration(milliseconds: 550));
    check(reads == pausedReads, 'paused watcher schedules no reads');
    paused.resume();
    await until(() => reads > pausedReads);
    await paused.cancel();
    subscriptions.clear();
    await File(
      joinPath(build.path, 'library-watch-timings.json'),
    ).writeAsString(jsonEncode(report));
    print(
      'LIBRARY WATCH PASSED: $checks checks, real Windows files and native Dart FFI; no FFmpeg, fake host or VEGAS.',
    );
  } finally {
    for (final active in subscriptions) await active.cancel();
    final resolvedBuild = (await build.resolveSymbolicLinks()).toLowerCase();
    final resolvedRoot = await root.resolveSymbolicLinks();
    final actual = resolvedRoot.toLowerCase();
    if (!actual.startsWith('$resolvedBuild${Platform.pathSeparator}') ||
        !root.uri.pathSegments
            .where((p) => p.isNotEmpty)
            .last
            .startsWith('library-watch-') ||
        await FileSystemEntity.isLink(root.path))
      throw StateError('Unsafe test cleanup root.');
    await Directory(resolvedRoot).delete(recursive: true);
  }
}
