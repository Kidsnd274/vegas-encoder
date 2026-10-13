import 'package:flutter/widgets.dart';

import '../../design/components/button.dart';
import '../../design/components/command_view.dart';
import '../../design/components/message.dart';
import '../../design/components/signal_path/signal_path_model.dart';
import '../../design/tokens.dart';
import '../../state/editor.dart';
import 'display.dart';

/// The command and checks column (`.cc`): the compiled FFmpeg command with the
/// selected node's group highlighted, then the core's checks for the chosen
/// FFmpeg. Clicking "Show setting" opens the node that holds the field.
class CommandColumn extends StatelessWidget {
  const CommandColumn({
    super.key,
    required this.data,
    required this.node,
    required this.onShowField,
    required this.multiline,
    required this.onToggleLayout,
  });

  final EditorData data;
  final SignalNode node;
  final ValueChanged<String> onShowField;

  /// Grouped lines, or one line.
  final bool multiline;
  final VoidCallback onToggleLayout;

  static const double width = 432;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final compiled = data.compiled.value;
    final installation = data.installation?.label ?? 'FFmpeg';
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.panel,
        border: Border(left: BorderSide(color: c.line)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 14, 16),
        children: [
          Row(
            children: [
              Expanded(child: CommandHeader(onCopy: compiled == null ? null : () => copyCommand(compiled.commandLine))),
              if (compiled != null) ...[
                const SizedBox(width: 4),
                VeButton(
                  label: multiline ? 'One line' : 'Grouped',
                  variant: VeButtonVariant.ghost,
                  size: VeButtonSize.small,
                  tooltip: multiline ? 'Show the command on one line' : 'Show each stage on its own line',
                  onPressed: onToggleLayout,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (compiled != null)
            CommandView(
              command: commandDisplay(compiled, audio: data.recipe.audio.first.enabled),
              activeRole: switch (node) {
                SignalNode.source => CommandRole.inputs,
                SignalNode.video => CommandRole.video,
                SignalNode.audio => CommandRole.audio,
                SignalNode.container => CommandRole.mux,
                SignalNode.file => CommandRole.output,
              },
              multiline: multiline,
              maxHeight: 360,
            )
          else
            _Unavailable(_whyNoCommand(data)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Semantics(
                header: true,
                child: Text('Checks', style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(650))),
              ),
              const Spacer(),
              Text(installation, style: t.text.caption.copyWith(color: c.muted)),
            ],
          ),
          const SizedBox(height: 8),
          if (compiled != null)
            VeCheckList(
              emptyText: 'No problems with $installation.',
              checks: [
                for (final i in compiled.issues)
                  VeCheck(
                    level: levelOf(i.level),
                    text: i.message,
                    fix: i.fix,
                    actionLabel: nodeForField(i.field) == null ? null : 'Show setting',
                    onAction: nodeForField(i.field) == null ? null : () => onShowField(i.field),
                  ),
              ],
            )
          else
            Text('Checks run once the core can build the command.', style: t.text.small.copyWith(color: c.muted)),
        ],
      ),
    );
  }
}

/// The fake core (B0) only knows the built-in presets as shipped.
String _whyNoCommand(EditorData data) {
  if (!data.compiled.notInPreviewCore) {
    return 'The core couldn’t build the command: ${data.compiled.error?.message ?? 'unknown error'}';
  }
  const later = 'The real core (platform milestone B2) builds it for any settings.';
  if (data.dirty && data.preset.builtin) {
    return 'The preview core only knows the built-in presets as shipped, so it can’t build the command for '
        'this edit. $later Revert to see the shipped command.';
  }
  return 'The preview core only knows the built-in presets as shipped, so it can’t build the command for '
      '${data.dirty ? 'this edit' : 'this preset'}. $later';
}

class _Unavailable extends StatelessWidget {
  const _Unavailable(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.colors.surface,
        border: Border.all(color: t.colors.line),
        borderRadius: BorderRadius.circular(VeRadius.lg),
      ),
      child: Text(text, style: t.text.small.copyWith(color: t.colors.text2, height: 1.4)),
    );
  }
}
