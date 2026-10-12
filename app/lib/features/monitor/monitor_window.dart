import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/launch.dart';
import '../../design/components/button.dart';
import '../../design/components/title_bar.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/app_state.dart';

/// The render progress window (`--render-monitor`). F0 shell: no-activate
/// window, title bar with the keep-on-top pin, footer. Figures from the live
/// status file (C5) arrive in F6.
class MonitorWindow extends ConsumerWidget {
  const MonitorWindow({super.key, this.launchError});

  final String? launchError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final window = ref.watch(windowControllerProvider);
    final keepOnTop = ref.watch(windowStateProvider.select((s) => s.keepOnTop));
    final mode = ref.watch(launchModeProvider);
    final file = mode is RenderMonitorLaunch ? mode.liveFile : null;

    return ColoredBox(
      color: c.surface,
      child: Column(
        children: [
          VeTitleBar(
            height: 34,
            title: const Text('Render progress'),
            onDragStart: window.startDrag,
            onClose: window.close,
            trailing: [
              VeIconButton(
                icon: VeIcons.pin,
                label: 'Keep on top',
                selected: keepOnTop,
                dimension: 34,
                onPressed: () => window.setKeepOnTop(!keepOnTop),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(launchError ?? 'Live figures arrive in milestone F6.', style: t.text.panelTitle),
                  if (file != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      file,
                      style: t.text.caption.copyWith(color: c.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 9, 12, 9),
            decoration: BoxDecoration(
              color: c.panel,
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Cancel the render in VEGAS.', style: t.text.caption.copyWith(color: c.muted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
