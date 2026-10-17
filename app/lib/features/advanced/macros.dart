import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../../state/editor.dart';
import '../../state/services.dart';
import 'display.dart';

/// The macros panel's entries for the selected preset in Advanced mode: the
/// core catalogue using the same recipe, media and paths as the command
/// preview. Null outside Advanced mode.
final macroEntriesProvider = Provider<CoreResult<List<MacroEntry>>?>((ref) {
  final context = ref.watch(
    editorProvider.select((d) => d == null || !d.advanced ? null : (d.recipe, d.media, d.paths)),
  );
  if (context == null) return null;
  final (recipe, media, paths) = context;
  final core = ref.watch(veCoreProvider);
  return CoreResult.run(() => macroEntries(core.macros(media: media, paths: paths, recipe: recipe)));
});
