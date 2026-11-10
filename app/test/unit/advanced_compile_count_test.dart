import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/state/editor.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

/// Counts the core calls one Advanced keystroke causes (C8). Fakes only.
class _Spy extends FakeVeCore {
  int compiles = 0, lints = 0;

  @override
  CompileResult compile(
    Recipe recipe, {
    required MediaDescription media,
    required CompilePaths paths,
    CoreCapabilities? capabilities,
  }) {
    compiles++;
    return super.compile(recipe, media: media, paths: paths, capabilities: capabilities);
  }

  @override
  List<Diagnostic> lint(String text, {CoreCapabilities? capabilities}) {
    lints++;
    return super.lint(text, capabilities: capabilities);
  }
}

void main() {
  test('one Advanced keystroke compiles at most once and lints at most once (C8)', () async {
    final core = _Spy();
    final container = ProviderContainer(
      overrides: [
        veCoreProvider.overrideWithValue(core),
        servicesOverride(),
        presetLibraryProvider.overrideWithValue(FakePresetLibrary(now: () => '2026-10-12T02:00:00Z')),
        machineSettingsRepositoryProvider.overrideWithValue(FakeMachineSettingsRepository()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(presetsProvider, (_, _) {});
    container.listen(machineSettingsProvider, (_, _) {});
    container.listen(editorProvider, (_, _) {});
    await container.read(presetsProvider.future);
    await container.read(machineSettingsProvider.future);
    final controller = container.read(presetsControllerProvider.notifier)..select('yt-h264');

    const template = 'ffmpeg -hide_banner {inputs} -map {v} -map {a} -c:v libx264 -crf 18 -c:a aac -f mp4 {output}';
    controller.edit((r) => r.copyWith(command: r.command.copyWith(mode: 'template', template: template)));
    void readAsTheEditorDoes() {
      final data = container.read(editorProvider)!;
      data.compiled.value;
      data.lint?.value;
      data.basic?.value;
    }

    readAsTheEditorDoes();
    core.compiles = core.lints = 0;
    controller.edit((r) => r.copyWith(command: r.command.copyWith(template: '$template -movflags +faststart')));
    readAsTheEditorDoes();
    expect(core.compiles, lessThanOrEqualTo(1), reason: 'the preview compile only; the Basic one is reused');
    expect(core.lints, lessThanOrEqualTo(1));
  });
}
