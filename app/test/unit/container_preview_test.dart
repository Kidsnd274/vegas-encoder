import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/state/editor.dart';
import 'package:vegas_encoder/state/preview.dart';

void main() {
  late NativeVeCore core;
  late Recipe recipe;
  setUpAll(() {
    core = NativeVeCore();
    recipe = FakeVeCore().fixtures.first.recipe;
  });

  test('Advanced preview suffix comes from active muxer and keeps native context', () {
    final advanced = recipe.copyWith(
      container: recipe.container.copyWith(format: 'mp4'),
      command: CommandSettings(mode: 'template', template: '{inputs} -c:v ffv1 -c:a pcm_f32le -f matroska {output}'),
    );
    final preview = compilePreview(
      core,
      advanced,
      media: SamplePreview.media,
      basicExtension: '.mp4',
      target: {'id': 'vegas-native-v1'},
    );
    expect(preview.result.ok, isTrue);
    expect(preview.result.value!.outputContainerId, 'mkv');
    expect(preview.paths.output, endsWith('.mkv'));
    expect(preview.result.value!.argv.last, preview.paths.output);
    expect(preview.paths.target?['id'], 'vegas-native-v1');
    expect(preview.result.value!.issues.where((issue) => issue.level == IssueLevel.error), isEmpty);
  });

  test('unknown Advanced muxer has no Basic suffix and blocks native Apply', () {
    final advanced = recipe.copyWith(
      command: CommandSettings(mode: 'template', template: '{inputs} -c:v ffv1 -c:a pcm_f32le {output}'),
    );
    final preview = compilePreview(
      core,
      advanced,
      media: SamplePreview.media,
      basicExtension: '.mp4',
      target: {'id': 'vegas-native-v1'},
    );
    expect(preview.paths.output, SamplePreview.outputPath(null));
    expect(preview.result.value!.outputExtension, isNull);
    expect(
      preview.result.value!.issues.any((issue) => issue.id == 'N-CONTAINER' && issue.level == IssueLevel.error),
      isTrue,
    );
    final desktop = compilePreview(core, advanced, media: SamplePreview.media, basicExtension: '.mp4');
    expect(desktop.result.value!.issues.any((issue) => issue.id.startsWith('N-')), isFalse);
  });
}
