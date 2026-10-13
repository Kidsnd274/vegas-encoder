import 'dart:async';

import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'toast.dart';

/// `.ffh`: a desktop section's heading on surface, with what the page is for
/// and its actions at the right (FFmpeg, History, Settings).
class VePageHeader extends StatelessWidget {
  const VePageHeader({super.key, required this.title, this.description, this.actions = const []});

  final String title;
  final String? description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: t.text.headline)),
                if (description != null) ...[
                  const SizedBox(height: 3),
                  ConstrainedBox(
                    // max-width: 78ch at 13 px
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Text(description!, style: t.text.body.copyWith(color: c.muted)),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[const SizedBox(width: 16), Wrap(spacing: 10, runSpacing: 8, children: actions)],
        ],
      ),
    );
  }
}

/// A screen's toast: one at a time, centred near the bottom, gone after a few
/// seconds (longer with an action such as Undo). Add [toastLayer] last in the
/// screen's [Stack].
mixin VeToastHost<T extends StatefulWidget> on State<T> {
  ({String message, String? action, VoidCallback? onAction})? _toast;
  Timer? _toastTimer;

  void showToast(String message, {String? action, VoidCallback? onAction}) {
    _toastTimer?.cancel();
    setState(() => _toast = (message: message, action: action, onAction: onAction));
    _toastTimer = Timer(Duration(seconds: action == null ? 3 : 8), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void hideToast() {
    _toastTimer?.cancel();
    if (_toast != null) setState(() => _toast = null);
  }

  Widget toastLayer() {
    final toast = _toast;
    if (toast == null) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 22,
      child: Center(
        child: VeToast(message: toast.message, actionLabel: toast.action, onAction: toast.onAction),
      ),
    );
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }
}
