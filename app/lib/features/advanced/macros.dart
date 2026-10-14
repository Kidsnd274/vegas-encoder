import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/editor.dart';
import '../../state/preview.dart';
import '../../state/recipe_edit.dart';
import '../../state/services.dart';
import 'display.dart';

/// The macros panel's entries for the selected preset in Advanced mode: the
/// macros the core offers after "{" (`VeCore.complete`), each with the value
/// the core expands it to for the sample context (a compile of the names
/// alone). Null outside Advanced mode. See workstreams/app.md, Needs: a macro
/// list with descriptions and values from the core would replace this.
final macroEntriesProvider = Provider<CoreResult<List<MacroEntry>>?>((ref) {
  // Only what changes a value: the context, whether audio is delivered and
  // the output's extension. Typing in the command doesn't.
  final key = ref.watch(
    editorProvider.select(
      (d) => d == null || !d.advanced ? null : (d.media, d.recipe.audioTrack.enabled, d.containerProfile?.ext),
    ),
  );
  final data = ref.read(editorProvider);
  if (key == null || data == null) return null;
  final core = ref.watch(veCoreProvider);
  return CoreResult.run(() {
    final offered = core.complete('{', 1);
    final probe = macroProbeText(offered);
    final compiled = CoreResult.run(
      () => core.compile(
        data.recipe.copyWith(command: data.recipe.command.copyWith(template: probe)),
        media: data.media,
        paths: SamplePreview.paths(data.containerProfile?.ext),
      ),
    );
    return macroEntries(offered, probe, compiled.value);
  });
});
