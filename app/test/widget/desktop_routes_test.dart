import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/app/launch.dart';
import 'package:vegas_encoder/platform/desktop_channel.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/desktop_routes.dart';
import 'package:vegas_encoder/state/desktop_interaction.dart';
import 'package:vegas_encoder/state/history.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

class _Routes implements DesktopRouteSource {
  final controller = StreamController<DesktopRoute>.broadcast();
  final List<DesktopRoute> pending;
  _Routes([this.pending = const []]);
  @override
  Stream<DesktopRoute> get changes => controller.stream;
  @override
  Future<List<DesktopRoute>> start() async => pending;
  @override
  void dispose() => unawaited(controller.close());
}

class _DelayedLibrary extends FakePresetLibrary {
  bool holdNext = false;
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<Preset> save(Preset preset, {int? expectedRevision}) async {
    if (holdNext) {
      holdNext = false;
      started.complete();
      await release.future;
    }
    return super.save(preset, expectedRevision: expectedRevision);
  }
}

void main() {
  testWidgets('startup drain stays ahead of live messages received while ready is pending', (tester) async {
    const channel = MethodChannel('vegas_encoder/desktop');
    const codec = StandardMethodCodec();
    final reply = Completer<List<Object?>>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) => reply.future);
    final source = MethodChannelDesktopRouteSource();
    addTearDown(source.dispose);
    final received = <DesktopRoute>[];
    final listening = source.changes.listen(received.add);
    addTearDown(listening.cancel);
    final starting = source.start();
    await tester.pump();
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'vegas_encoder/desktop',
      codec.encodeMethodCall(const MethodCall('route', {'kind': 'preset', 'id': 'av1-small'})),
      (_) {},
    );
    reply.complete([
      {'kind': 'preset', 'id': 'yt-h264'},
    ]);
    expect(await starting, const [DesktopRoute.preset('yt-h264'), DesktopRoute.preset('av1-small')]);
    expect(received, isEmpty);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'vegas_encoder/desktop',
      codec.encodeMethodCall(const MethodCall('route', {'kind': 'job', 'id': 'j-1042'})),
      (_) {},
    );
    await tester.pump();
    expect(received, const [DesktopRoute.job('j-1042')]);
  });

  testWidgets('a handoff waits for the save warning and its delayed save to finish', (tester) async {
    final source = _Routes();
    final library = _DelayedLibrary();
    addTearDown(source.dispose);
    addTearDown(library.dispose);
    await pumpApp(
      tester,
      core: NativeVeCore(),
      overrides: [
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        desktopRouteSourceProvider.overrideWithValue(source),
        presetLibraryProvider.overrideWithValue(library),
      ],
    );
    final container = tester.container();
    final controller = container.read(presetsControllerProvider.notifier);
    controller.select('av1-small');
    controller.edit((r) => r.copyWith(name: 'B awaiting'));
    controller.select('yt-h264');
    controller.selectInstallation('btbn-lgpl-8.0');
    controller.edit((r) => r.copyWith(video: r.video.copyWith(quality: 20)));
    await tester.pumpAndSettle();
    library.holdNext = true;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Save anyway'), findsOneWidget);
    source.controller.add(const DesktopRoute.preset('av1-small'));
    await tester.pumpAndSettle();
    expect(container.read(presetsControllerProvider).selectedId, 'yt-h264');
    await tester.tap(find.text('Save anyway'));
    await tester.pumpAndSettle();
    expect(library.started.isCompleted, isTrue);
    expect(
      container.read(presetsControllerProvider).selectedId,
      'yt-h264',
      reason: 'modal dismissed but the save is still running',
    );
    library.release.complete();
    await tester.pumpAndSettle();
    final saved = (await library.list()).where((p) => !p.builtin).single;
    expect(saved.origin, 'builtin/yt-h264');
    expect(saved.recipe.video.quality, 20);
    expect(container.read(presetsControllerProvider).selectedId, 'av1-small');
    expect(container.read(presetsControllerProvider).drafts['av1-small']?.recipe.name, 'B awaiting');
  });

  test('idle waits are released by shell cancellation and gate disposal', () async {
    final gate = DesktopInteractionGate();
    final release = Completer<void>();
    final action = gate.run(() => release.future);
    final cancel = Completer<void>();
    final waiting = gate.waitUntilIdle(cancelled: cancel.future);
    cancel.complete();
    expect(await waiting, isFalse);
    final disposedWait = gate.waitUntilIdle();
    gate.dispose();
    expect(await disposedWait, isFalse);
    release.complete();
    await action;
  });

  testWidgets('cold and forwarded routes select targets, clear filters and preserve drafts', (tester) async {
    final source = _Routes();
    addTearDown(source.dispose);
    await pumpApp(
      tester,
      overrides: [
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        desktopRouteSourceProvider.overrideWithValue(source),
        launchModeProvider.overrideWithValue(const DesktopLaunch(route: DesktopRoute.preset('av1-small'))),
      ],
    );
    final container = tester.container();
    expect(container.read(presetsControllerProvider).selectedId, 'av1-small');
    final controller = container.read(presetsControllerProvider.notifier);
    controller.edit((r) => r.copyWith(name: 'Unsaved draft'));
    controller.setQuery('never matches');
    container.read(historyControllerProvider.notifier).setFilter(HistoryFilter.failed);
    source.controller.add(const DesktopRoute.job('j-1042'));
    await tester.pumpAndSettle();
    expect(container.read(desktopSectionProvider), DesktopSection.history);
    expect(container.read(historyControllerProvider).selectedId, 'j-1042');
    expect(container.read(historyControllerProvider).filter, HistoryFilter.all);
    source.controller.add(const DesktopRoute.preset('yt-h264'));
    await tester.pumpAndSettle();
    expect(container.read(desktopSectionProvider), DesktopSection.presets);
    expect(container.read(presetsControllerProvider).selectedId, 'yt-h264');
    expect(container.read(presetsControllerProvider).query, isEmpty);
    expect(container.read(presetsControllerProvider).drafts['av1-small']?.recipe.name, 'Unsaved draft');
  });

  testWidgets('queued startup handoff and a removed target have actionable behavior', (tester) async {
    final source = _Routes([const DesktopRoute.job('j-1042')]);
    addTearDown(source.dispose);
    await pumpApp(
      tester,
      overrides: [
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        desktopRouteSourceProvider.overrideWithValue(source),
      ],
    );
    final container = tester.container();
    expect(container.read(desktopSectionProvider), DesktopSection.history);
    source.controller.add(const DesktopRoute.preset('removed-preset'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t open the requested item'), findsOneWidget);
    expect(find.textContaining('no longer in the library'), findsOneWidget);
    expect(container.read(historyControllerProvider).selectedId, 'j-1042');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    source.controller.add(const DesktopRoute.preset('yt-h264'));
    await tester.pumpAndSettle();
    expect(container.read(presetsControllerProvider).selectedId, 'yt-h264');
  });

  test('launching desktop needs no core or library', () {
    var coreLoads = 0;
    final container = ProviderContainer(
      overrides: [
        veCoreProvider.overrideWith((ref) {
          coreLoads++;
          throw StateError('must not load');
        }),
        desktopAppLauncherProvider.overrideWithValue(WindowsDesktopAppLauncher(launch: (_, _) async {})),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(desktopAppLauncherProvider), isA<WindowsDesktopAppLauncher>());
    expect(coreLoads, 0);
  });
}
