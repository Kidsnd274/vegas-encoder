import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/features/advanced/macros.dart';
import 'package:vegas_encoder/state/editor.dart';
import 'package:vegas_encoder/state/services.dart';

void main() {
  test('catalogue uses the active recipe, media and preview paths and follows context changes', () {
    final fixtures = FakeVeCore();
    final fixture = fixtures.fixtures.first;
    final recipe = fixture.recipe.copyWith(
      command: fixture.recipe.command.copyWith(mode: 'template', template: '{inputs} {output}'),
    );
    final withoutAudio = recipe.copyWith(audio: [recipe.audio.first.copyWith(enabled: false)]);
    final media = fixture.media.copyWith(video: fixture.media.video.copyWith(width: 3840, height: 2160));
    final paths = fixture.paths.copyWith(project: 'Popup project', output: r'E:\Render As\Popup project.mkv');
    List<MacroDefinition> answer(String value) => [
      MacroDefinition(name: '{context}', description: 'Fixture context', value: value),
    ];
    final core = FakeVeCore(
      macroFixtures: {
        FakeVeCore.macrosKey(fixture.media, fixture.paths, recipe: recipe): answer('initial'),
        FakeVeCore.macrosKey(fixture.media, fixture.paths, recipe: withoutAudio): answer('audio disabled'),
        FakeVeCore.macrosKey(media, paths, recipe: withoutAudio): answer('popup context'),
      },
    );
    EditorData data(Recipe active, MediaDescription media, CompilePaths paths) => EditorData(
      preset: Preset.fromJson({'recipe': active.toJson()}),
      saved: active,
      recipe: active,
      draft: null,
      catalog: fixtures.profiles(),
      installations: const [],
      installation: null,
      defaultInstallationId: null,
      media: media,
      paths: paths,
      compiled: CoreResult.ok(fixture.compiled),
      perMinute: () => CoreResult.ok(fixture.estimate),
      total: () => null,
    );

    EditorData? active = data(recipe, fixture.media, fixture.paths);
    final container = ProviderContainer(
      overrides: [veCoreProvider.overrideWithValue(core), editorProvider.overrideWith((ref) => active)],
    );
    addTearDown(container.dispose);
    container.listen(macroEntriesProvider, (_, _) {});
    String? value() => container.read(macroEntriesProvider)?.value?.single.value;
    expect(value(), 'initial');

    active = data(withoutAudio, fixture.media, fixture.paths);
    container.invalidate(editorProvider);
    expect(value(), 'audio disabled', reason: 'recipe-only changes must refresh the input policy');

    active = data(withoutAudio, media, paths);
    container.invalidate(editorProvider);
    expect(value(), 'popup context', reason: 'uses the editor paths and media rather than desktop samples');

    active = data(fixture.recipe, media, paths);
    container.invalidate(editorProvider);
    expect(container.read(macroEntriesProvider), isNull, reason: 'no catalogue work in Basic mode');
  });
}
