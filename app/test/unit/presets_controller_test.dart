import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/editor.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/recipe_edit.dart';
import 'package:vegas_encoder/state/services.dart';

/// The Presets screen's state against the platform fakes (B0). Nothing here
/// runs FFmpeg or VEGAS.
void main() {
  late ProviderContainer container;
  late FakePresetLibrary library;
  late FakeMachineSettingsRepository machine;

  PresetsController controller() => container.read(presetsControllerProvider.notifier);
  PresetsState state() => container.read(presetsControllerProvider);
  Future<List<Preset>> presets() => library.list();
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    library = FakePresetLibrary(now: () => '2026-10-12T02:00:00Z');
    machine = FakeMachineSettingsRepository();
    container = ProviderContainer(
      overrides: [
        veCoreProvider.overrideWithValue(FakeVeCore()),
        presetLibraryProvider.overrideWithValue(library),
        machineSettingsRepositoryProvider.overrideWithValue(machine),
      ],
    );
    addTearDown(container.dispose);
    container.listen(presetsProvider, (_, _) {});
    container.listen(machineSettingsProvider, (_, _) {});
    await container.read(presetsProvider.future);
    await container.read(machineSettingsProvider.future);
    controller().select('yt-h264');
  });

  test('an edit makes a draft; editing back to the saved value drops it', () {
    controller().edit((r) => r.withVideo((v) => v.copyWith(quality: 17)));
    expect(state().drafts.keys, ['yt-h264']);
    expect(state().drafts['yt-h264']!.baseRevision, 6);
    controller().edit((r) => r.withVideo((v) => v.copyWith(quality: 18)));
    expect(state().drafts, isEmpty);
  });

  test('saving a built-in saves a new preset in Mine and selects it', () async {
    controller().edit((r) => r.withVideo((v) => v.copyWith(quality: 17)));
    expect(await controller().save(), SaveOutcome.savedAsNew);
    await settle();
    final mine = (await presets()).where((p) => !p.builtin).single;
    expect(mine.recipe.name, 'YouTube upload, H.264 (copy)');
    expect(mine.recipe.id, 'youtube-upload-h-264-copy');
    expect(mine.origin, 'builtin/yt-h264');
    expect(mine.recipe.video.quality, 17);
    expect(state().selectedId, mine.recipe.id);
    expect(state().drafts, isEmpty);
    expect((await library.get('yt-h264'))!.recipe.video.quality, 18, reason: 'built-ins are never changed');
  });

  test('saving a preset in Mine moves it to the next revision', () async {
    await controller().duplicate('yt-h264');
    await settle();
    final id = state().selectedId!;
    controller().edit((r) => r.withAudio((a) => a.copyWith(bitrateK: 256)));
    expect(await controller().save(), SaveOutcome.saved);
    final saved = (await library.get(id))!;
    expect(saved.revision, 2);
    expect(saved.recipe.audioTrack.bitrateK, 256);
    expect(state().drafts, isEmpty);
  });

  test('a preset changed in another window is a conflict until the user chooses', () async {
    await controller().duplicate('yt-h264');
    await settle();
    final id = state().selectedId!;
    controller().edit((r) => r.withVideo((v) => v.copyWith(quality: 20)));

    // Another window saves first.
    final other = (await library.get(id))!;
    await library.save(other.copyWith(recipe: other.recipe.copyWith(notes: 'From the popup')), expectedRevision: 1);
    await settle();

    final data = container.read(editorProvider)!;
    expect(data.changedElsewhere, isTrue);
    expect(await controller().save(), SaveOutcome.conflict);
    controller().keepEditing(id);
    expect(container.read(editorProvider)!.changedElsewhere, isFalse);
    expect(container.read(editorProvider)!.behindLibrary, isTrue);

    expect(await controller().save(overwrite: true), SaveOutcome.saved);
    final saved = (await library.get(id))!;
    expect(saved.revision, 3);
    expect(saved.recipe.video.quality, 20);
  });

  test('favorites: Mine saves to the library, built-ins last the session', () async {
    await controller().duplicate('yt-h264');
    await settle();
    final id = state().selectedId!;
    controller().edit((r) => r.withVideo((v) => v.copyWith(quality: 21)));
    await controller().toggleFavorite(id);
    await settle();
    expect((await library.get(id))!.favorite, isTrue);
    expect(state().drafts[id]!.baseRevision, 2, reason: 'our own save is not a change elsewhere');
    expect(container.read(editorProvider)!.changedElsewhere, isFalse);

    final builtin = (await library.get('av1-small'))!;
    await controller().toggleFavorite('av1-small');
    expect(state().isFavorite(builtin), isTrue);
    expect((await library.get('av1-small'))!.revision, builtin.revision);
  });

  test('rename and delete work on Mine only', () async {
    await controller().duplicate('yt-h264');
    await settle();
    final id = state().selectedId!;
    await controller().rename(id, '  Client upload  ');
    expect((await library.get(id))!.recipe.name, 'Client upload');
    await controller().rename('yt-h264', 'Nope');
    expect((await library.get('yt-h264'))!.recipe.name, 'YouTube upload, H.264');
    await controller().delete(id);
    expect(await library.get(id), isNull);
    expect(state().selectedId, isNull);
    await controller().delete('yt-h264');
    expect(await library.get('yt-h264'), isNotNull);
  });

  group('editor results', () {
    test('a built-in as shipped compiles; an edit is beyond the preview core', () {
      final data = container.read(editorProvider)!;
      expect(data.compiled.ok, isTrue);
      expect(data.perMinute.ok, isTrue);
      expect(data.total!.notInPreviewCore, isTrue, reason: 'B0 has no estimates for a typed length');
      controller().edit((r) => r.withVideo((v) => v.copyWith(quality: 17)));
      final edited = container.read(editorProvider)!;
      expect(edited.dirty, isTrue);
      expect(edited.compiled.notInPreviewCore, isTrue);
      expect(edited.coreError?.code, 'B0-FIXTURE-MISSING');
    });

    test('checks follow the chosen FFmpeg', () async {
      container.listen(capabilitiesProvider('btbn-lgpl-8.0'), (_, _) {});
      controller().selectInstallation('btbn-lgpl-8.0');
      await container.read(capabilitiesProvider('btbn-lgpl-8.0').future);
      final data = container.read(editorProvider)!;
      expect(data.installation!.label, 'FFmpeg 8.0 LGPL');
      expect(data.hasErrors, isTrue);
      expect(data.issues.map((i) => i.id), contains('V-ENC-MISSING'));
    });
  });

  test('the theme choice is stored in machine settings (C7)', () async {
    container.listen(themePreferenceProvider, (_, _) {});
    expect(container.read(themePreferenceProvider), ThemePreference.followWindows);
    await container.read(themePreferenceProvider.notifier).set(ThemePreference.dark);
    expect((await machine.read()).theme, 'dark');
    await settle();
    expect(container.read(themePreferenceProvider), ThemePreference.dark);
  });
}
