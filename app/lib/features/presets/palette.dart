import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../design/components/interactive.dart';
import '../../design/components/text_field.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import 'library_model.dart';

/// Ctrl+K "Open preset…" (UI_SPEC §7): type to filter by the library's search,
/// arrows to move, Enter to open. Returns the chosen preset's ID.
Future<String?> showPresetPalette(BuildContext context, List<LibraryEntry> entries) {
  final t = VeTokens.of(context);
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: t.shadow(t.brightness == Brightness.dark ? 0.45 : 0.2),
    transitionDuration: VeTokens.motion(context, VeDurations.short),
    pageBuilder: (_, _, _) => _Palette(entries: entries),
    transitionBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
  );
}

class _Palette extends StatefulWidget {
  const _Palette({required this.entries});
  final List<LibraryEntry> entries;

  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _field = FocusNode(debugLabel: 'palette search');
  final ScrollController _scroll = ScrollController();
  int _active = 0;

  List<LibraryEntry> get _matches => [
    for (final g in groupLibrary(widget.entries, query: _query.text))
      for (final sub in g.subgroups) ...sub.entries,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _field.requestFocus();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _field.dispose();
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final matches = _matches;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() => _active = matches.isEmpty ? 0 : (_active + 1) % matches.length);
      case LogicalKeyboardKey.arrowUp:
        setState(() => _active = matches.isEmpty ? 0 : (_active - 1 + matches.length) % matches.length);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        if (matches.isNotEmpty) Navigator.of(context).pop(matches[_active.clamp(0, matches.length - 1)].id);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final matches = _matches;
    final active = matches.isEmpty ? -1 : _active.clamp(0, matches.length - 1);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 72),
        child: Shortcuts(
          shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
          child: Actions(
            actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => Navigator.of(context).pop())},
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: 'Open preset',
              child: Container(
                width: 560,
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.line2),
                  borderRadius: BorderRadius.circular(VeRadius.xl),
                  boxShadow: t.toastShadow,
                ),
                child: DefaultTextStyle(
                  style: t.text.body,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Focus(
                          onKeyEvent: _onKey,
                          child: VeTextField(
                            controller: _query,
                            focusNode: _field,
                            search: true,
                            placeholder: 'Open a preset by name, encoder or tag',
                            semanticLabel: 'Open preset',
                            onChanged: (_) => setState(() => _active = 0),
                          ),
                        ),
                      ),
                      Container(height: 1, color: c.line),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 380),
                        child: matches.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text(
                                  'No presets match “${_query.text.trim()}”.',
                                  style: t.text.body.copyWith(color: c.muted),
                                ),
                              )
                            : ListView.builder(
                                controller: _scroll,
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                itemCount: matches.length,
                                itemBuilder: (context, i) => _Row(
                                  entry: matches[i],
                                  active: i == active,
                                  onHover: () => setState(() => _active = i),
                                  onTap: () => Navigator.of(context).pop(matches[i].id),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.active, required this.onHover, required this.onTap});
  final LibraryEntry entry;
  final bool active;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Semantics(
      button: true,
      selected: active,
      label: '${entry.name}, ${entry.line}, ${entry.builtin ? 'built-in' : 'mine'}',
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => onHover(),
        child: VeInteractive(
          onTap: onTap,
          canRequestFocus: false,
          builder: (context, s) => Container(
            color: active ? c.fillSelected : null,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 30, child: entry.depth == null ? null : WireGlyph(outputDepth: entry.depth!)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.text.bodyStrong),
                      Text(
                        entry.line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.text.caption.copyWith(color: entry.problem != null ? c.error : c.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(entry.builtin ? 'Built-in' : 'Mine', style: t.text.caption.copyWith(color: c.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
