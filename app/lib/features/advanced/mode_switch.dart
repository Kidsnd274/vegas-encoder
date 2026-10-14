import 'package:flutter/widgets.dart';

import '../../design/components/button.dart';
import '../../design/components/dialog.dart';
import '../../state/editor.dart';

/// How Advanced mode starts (SETTINGS_AND_COMMANDS §5).
enum AdvancedStart {
  /// From the Basic settings: the core's `advancedTemplate`.
  seed,

  /// With the command already saved.
  keepSaved,

  cancel,
}

/// Switching to Advanced: the first time the command starts from the Basic
/// settings; with a command already saved the user chooses ("Use your saved
/// command", the default and focused, "Replace it with the current settings",
/// or Cancel). Both settings are kept either way.
Future<AdvancedStart> askAdvancedStart(BuildContext context, EditorData data) async {
  if (data.recipe.command.template.trim().isEmpty) return AdvancedStart.seed;
  final choice = await showVeDialog<AdvancedStart>(
    context,
    title: 'Switch to Advanced',
    message:
        'This preset already has a command from Advanced mode. Use it, or start again from the current '
        'Basic settings? The Basic settings are kept either way.',
    actions: const [
      VeDialogAction('Cancel', AdvancedStart.cancel),
      VeDialogAction('Replace it with the current settings', AdvancedStart.seed),
      VeDialogAction('Use your saved command', AdvancedStart.keepSaved, variant: VeButtonVariant.primary),
    ],
  );
  return choice ?? AdvancedStart.cancel;
}
