import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/launch.dart';
import '../../design/components/button.dart';
import '../../design/components/title_bar.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/app_state.dart';

/// The VEGAS popup (`--edit-session`). F0 shell: title bar, ownership and the
/// footer; the template header, strip and editor arrive in F5.
class PopupWindow extends ConsumerWidget {
  const PopupWindow({super.key, this.launchError});

  final String? launchError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final window = ref.watch(windowControllerProvider);
    final mode = ref.watch(launchModeProvider);
    final session = mode is EditSessionLaunch ? mode.sessionDir : null;

    return ColoredBox(
      color: c.paper,
      child: Column(
        children: [
          VeTitleBar(
            height: 34,
            title: const Text('Vegas Encoder, editing a VEGAS render template'),
            onDragStart: window.startDrag,
            onClose: window.close,
            closeLabel: 'Cancel',
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(VeSpace.s5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(launchError ?? 'The template editor arrives in milestone F5.', style: t.text.panelTitle),
                    if (session != null) ...[
                      const SizedBox(height: 6),
                      Text('Session: $session', style: t.text.small.copyWith(color: c.text2)),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 58,
            padding: const EdgeInsets.only(left: 20, right: 16),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              children: [
                VeIcon(VeIcons.info, color: c.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Apply updates this render template. Save it in VEGAS to keep it for next time.',
                    style: t.text.small.copyWith(color: c.muted),
                  ),
                ),
                VeButton(label: 'Cancel', onPressed: window.close),
                const SizedBox(width: 10),
                const VeButton(
                  label: 'Apply to template',
                  variant: VeButtonVariant.primary,
                  onPressed: null,
                  tooltip: 'The editor arrives in F5.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
