import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../tokens.dart';
import 'button.dart';

/// Message levels. Colour is always paired with an icon and text (UI_SPEC §9).
enum VeLevel {
  error('Error'),
  warning('Warning'),
  info('Note'),
  hint('Hint'),
  ok('No problems');

  const VeLevel(this.label);
  final String label;

  VeIconData get icon => switch (this) {
    VeLevel.error => VeIcons.error,
    VeLevel.warning => VeIcons.warning,
    VeLevel.info => VeIcons.info,
    VeLevel.hint => VeIcons.hint,
    VeLevel.ok => VeIcons.check,
  };

  Color iconColor(VePalette c) => switch (this) {
    VeLevel.error => c.error,
    VeLevel.warning => c.warning,
    VeLevel.info || VeLevel.hint => c.muted,
    VeLevel.ok => c.success,
  };
}

/// `.msg`: a message at the field it belongs to. Errors and warnings sit on a
/// tinted row; notes are plain muted text.
class VeMessage extends StatelessWidget {
  const VeMessage({super.key, required this.level, required this.text, this.fix});

  final VeLevel level;

  /// What happened.
  final String text;

  /// How to fix it, on its own line.
  final String? fix;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final (Color? bg, Color fg) = switch (level) {
      VeLevel.error => (c.errorBackground, c.errorText),
      VeLevel.warning => (c.warningBackground, c.warningText),
      _ => (null, c.muted),
    };
    final style = t.text.small.copyWith(color: fg);
    return Semantics(
      container: true,
      label: '${level.label}. $text${fix == null ? '' : ' $fix'}',
      excludeSemantics: true,
      child: Container(
        padding: bg == null
            ? const EdgeInsets.symmetric(vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: bg == null ? null : BoxDecoration(color: bg, borderRadius: BorderRadius.circular(VeRadius.md)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: VeIcon(level.icon, color: level.iconColor(c)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: style),
                  if (fix != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Opacity(opacity: 0.85, child: Text(fix!, style: style)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One entry in the checks summary near the command.
@immutable
class VeCheck {
  const VeCheck({required this.level, required this.text, this.fix, this.actionLabel, this.onAction});
  final VeLevel level;
  final String text;
  final String? fix;

  /// "Show setting": focuses the field the message belongs to.
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// `.cks`: the summary list beside the command. Errors first, then warnings,
/// then notes. With nothing to report it says so, naming the FFmpeg checked.
class VeCheckList extends StatelessWidget {
  const VeCheckList({super.key, required this.checks, required this.emptyText});

  final List<VeCheck> checks;

  /// Such as "No problems with FFmpeg 8.1 full."
  final String emptyText;

  static int _rank(VeLevel l) => switch (l) {
    VeLevel.error => 0,
    VeLevel.warning => 1,
    _ => 2,
  };

  @override
  Widget build(BuildContext context) {
    final items = checks.isEmpty
        ? [VeCheck(level: VeLevel.ok, text: emptyText)]
        : ([...checks]..sort((a, b) => _rank(a.level).compareTo(_rank(b.level))));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 8), _CheckRow(items[i])],
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(this.check);
  final VeCheck check;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final textColor = check.level == VeLevel.info ? c.text2 : c.ink;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Semantics(
              label: check.level.label,
              child: VeIcon(check.level.icon, color: check.level.iconColor(c)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.text, style: t.text.small.copyWith(color: textColor)),
                if (check.fix != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(check.fix!, style: t.text.small.copyWith(color: c.muted)),
                  ),
                if (check.actionLabel != null) VeLinkButton(label: check.actionLabel!, onPressed: check.onAction),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
