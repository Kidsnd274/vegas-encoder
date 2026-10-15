import 'package:flutter/widgets.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/button.dart';
import '../../design/components/dialog.dart';
import '../../design/tokens.dart';
import '../../state/editor.dart' show CoreResult;
import 'display.dart' show nodeForField;

/// What to do after the warning before a save.
enum SaveCheck { save, cancel, showSetting }

/// A preset's errors, split the way saving treats them (owner decision,
/// 2026-10-15): [settings] are the core's errors in the settings themselves
/// (`VeCore.validate` with no FFmpeg; the library refuses these, C3
/// `RECIPE-INVALID`); [ffmpeg] are the further errors the core found for the
/// FFmpeg the checks are for ([compiled], the compile's issues).
({List<Issue> settings, List<Issue> ffmpeg}) saveErrors(VeCore core, Recipe recipe, List<Issue> compiled) {
  // A core that can't check leaves the decision to the library.
  final own = CoreResult.run(() => core.validate(recipe)).value ?? const <Issue>[];
  final settings = own.where((i) => i.level == IssueLevel.error).toList();
  final known = {for (final i in settings) '${i.id}|${i.field}'};
  final ffmpeg = compiled.where((i) => i.level == IssueLevel.error && !known.contains('${i.id}|${i.field}')).toList();
  return (settings: settings, ffmpeg: ffmpeg);
}

/// Presets with errors aren't saved, and the user hears why first (owner
/// decision, 2026-10-15). Errors in the settings themselves stop the save:
/// "Show setting" opens the first one. Errors only for the chosen FFmpeg
/// warn, with Save anyway, since the preset may suit another FFmpeg.
Future<SaveCheck> checkSave(
  BuildContext context, {
  required String name,
  required List<Issue> settings,
  required List<Issue> ffmpeg,
  required String installation,
}) async {
  if (settings.isNotEmpty) {
    final choice = await showVeDialog<SaveCheck>(
      context,
      title: 'Fix the errors before saving',
      message: '“$name” has settings that can’t render, so it can’t be saved yet. Your changes stay as they are.',
      content: _ErrorList(settings),
      actions: [
        if (nodeForField(settings.first.field) != null) const VeDialogAction('Show setting', SaveCheck.showSetting),
        const VeDialogAction('Keep editing', SaveCheck.cancel, variant: VeButtonVariant.primary),
      ],
    );
    return choice ?? SaveCheck.cancel;
  }
  if (ffmpeg.isNotEmpty) {
    final choice = await showVeDialog<SaveCheck>(
      context,
      title: '“$name” can’t render with $installation',
      message:
          'The settings themselves are fine, so it can be saved for another FFmpeg, but renders with this one '
          'would fail.',
      content: _ErrorList(ffmpeg),
      actions: const [
        VeDialogAction('Save anyway', SaveCheck.save),
        VeDialogAction('Cancel', SaveCheck.cancel, variant: VeButtonVariant.primary),
      ],
    );
    return choice ?? SaveCheck.cancel;
  }
  return SaveCheck.save;
}

/// The first few errors as the core words them, then how many more.
class _ErrorList extends StatelessWidget {
  const _ErrorList(this.issues);
  final List<Issue> issues;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final shown = issues.take(3).toList();
    final more = issues.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final i in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('• ${i.message}', style: t.text.small.copyWith(color: t.colors.errorText, height: 1.4)),
          ),
        if (more > 0) Text('and $more more.', style: t.text.small.copyWith(color: t.colors.muted)),
      ],
    );
  }
}
