import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart' show CompileResult, Diagnostic;

import '../../design/components/button.dart';
import '../../design/components/command_editor.dart';
import '../../design/components/interactive.dart';
import '../../design/components/message.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/editor.dart';
import '../../state/presets.dart';
import '../../state/preview.dart';
import '../../state/services.dart';
import 'display.dart';
import 'macros.dart';

/// Advanced mode (UI_SPEC §3, S2): the command editor with its diagnostics and
/// the resolved command, beside the way back to Basic and the macros. Every
/// highlight, range, check and expansion comes from the core.
class AdvancedWorkspace extends ConsumerStatefulWidget {
  const AdvancedWorkspace({
    super.key,
    required this.data,
    required this.editorFocus,
    required this.editorPane,
    required this.sidePane,
    required this.onSwitchToBasic,
    required this.onReplaceWithBasic,
    required this.onCopy,
  });

  final EditorData data;

  /// The editor's focus: the diagram and Ctrl+M put the caret here.
  final FocusNode editorFocus;

  /// F6 panes: the editor's column and the side column.
  final FocusNode editorPane;
  final FocusNode sidePane;
  final VoidCallback onSwitchToBasic;
  final VoidCallback onReplaceWithBasic;
  final VoidCallback onCopy;

  /// The side column's width, as the Basic command column.
  static const double sideWidth = 432;

  @override
  ConsumerState<AdvancedWorkspace> createState() => AdvancedWorkspaceState();
}

class AdvancedWorkspaceState extends ConsumerState<AdvancedWorkspace> {
  late final CommandEditingController _controller = CommandEditingController(
    text: widget.data.recipe.command.template,
    describe: _describe,
  );
  CommandEditorModel? _model;
  EditorData? _modelFor;
  bool _resolvedOpen = true;

  CommandEditingController get controller => _controller;

  @override
  void didUpdateWidget(AdvancedWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Revert, Undo, Replace with Basic settings or another window changed the
    // command: show it, keeping the caret where it was when it still fits.
    final template = widget.data.recipe.command.template;
    if (template != _controller.text) {
      final sel = _controller.selection;
      final caret = math.min(sel.isValid ? sel.extentOffset : template.length, template.length);
      _controller.value = TextEditingValue(
        text: template,
        selection: TextSelection.collapsed(offset: caret),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The editor's model for [text]. The editor asks for the current text,
  /// which is the recipe's command once the edit reaches the state; between
  /// two keystrokes in one frame the core is asked directly.
  CommandEditorModel _describe(String text) {
    final data = widget.data;
    final cached = _model;
    if (cached != null && cached.text == text && identical(_modelFor, data)) return cached;
    final CompileResult? compiled;
    final List<Diagnostic> lint;
    if (text == data.recipe.command.template) {
      compiled = data.compiled.value;
      lint = data.lint?.value ?? const [];
    } else {
      final core = ref.read(veCoreProvider);
      final recipe = data.recipe.copyWith(command: data.recipe.command.copyWith(template: text));
      final paths = SamplePreview.paths(data.containerProfile?.ext);
      compiled = CoreResult.run(
        () => core.compile(recipe, media: data.media, paths: paths, capabilities: data.capabilities),
      ).value;
      lint = CoreResult.run(() => core.lint(text, capabilities: data.capabilities)).value ?? const [];
    }
    _modelFor = data;
    return _model = templateEditorModel(text, compiled: compiled, lint: lint);
  }

  void _changed(String text) => ref.read(presetsControllerProvider.notifier).setTemplate(text);

  /// Puts [name] at the caret (or over the selection), with a space either
  /// side where it would otherwise join a neighbouring argument.
  void insertMacro(String name) {
    final value = _controller.value;
    final text = value.text;
    var sel = value.selection.isValid ? value.selection : TextSelection.collapsed(offset: text.length);
    // Never over part of a chip: insert after it instead.
    for (final chip in _controller.model.chips) {
      final partial = sel.start < chip.end && sel.end > chip.start && !(sel.start <= chip.start && sel.end >= chip.end);
      if (partial || _controller.model.chipInside(sel.start) != null) sel = TextSelection.collapsed(offset: chip.end);
    }
    bool space(int i) => const [0x20, 0x09, 0x0A, 0x0D].contains(text.codeUnitAt(i));
    final before = sel.start > 0 && !space(sel.start - 1) ? ' ' : '';
    final after = sel.end < text.length && !space(sel.end) ? ' ' : '';
    final next = text.replaceRange(sel.start, sel.end, '$before$name$after');
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start + before.length + name.length),
    );
    _changed(next);
    widget.editorFocus.requestFocus();
  }

  /// "Go to": selects the range in the editor.
  void goTo(int start, int end) {
    widget.editorFocus.requestFocus();
    _controller.selection = TextSelection(baseOffset: start, extentOffset: end);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final model = _controller.model;
    final checks = advancedChecks(data.recipe.command.template, model.marks, data.compiled.value);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Focus(
            focusNode: widget.editorPane,
            child: FocusTraversalGroup(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 14, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _EditorBar(controller: _controller),
                    const SizedBox(height: 8),
                    CommandEditor(controller: _controller, focusNode: widget.editorFocus, onChanged: _changed),
                    const SizedBox(height: 14),
                    _Diagnostics(
                      checks: checks,
                      installation: data.installation?.label ?? 'FFmpeg',
                      coreError: data.lint?.error?.message,
                      onGoTo: goTo,
                    ),
                    const SizedBox(height: 16),
                    _Resolved(
                      data: data,
                      open: _resolvedOpen,
                      onToggle: () => setState(() => _resolvedOpen = !_resolvedOpen),
                      onCopy: widget.onCopy,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Focus(
          focusNode: widget.sidePane,
          child: FocusTraversalGroup(
            child: _SideColumn(
              data: data,
              model: model,
              onSwitchToBasic: widget.onSwitchToBasic,
              onReplaceWithBasic: widget.onReplaceWithBasic,
              onInsert: insertMacro,
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ editor bar

/// `.ed-bar`: what the editor is, the message at the caret (or that the
/// chips are locked), and where the caret is.
class _EditorBar extends StatelessWidget {
  const _EditorBar({required this.controller});
  final CommandEditingController controller;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final muted = t.text.small.copyWith(color: c.muted);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sel = controller.selection;
        final mark = sel.isValid ? controller.model.markAt(sel.extentOffset) : null;
        return Row(
          children: [
            Semantics(
              header: true,
              child: Text(
                'FFmpeg command',
                style: t.text.bodyStrong.copyWith(fontSize: 14, fontWeight: const FontWeight(650)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: mark == null
                    ? Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '{inputs}',
                              style: t.text.monoSmall.copyWith(color: c.muted),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: '{output}',
                              style: t.text.monoSmall.copyWith(color: c.muted),
                            ),
                            const TextSpan(text: ' are locked.'),
                          ],
                        ),
                        style: muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Row(
                        children: [
                          VeIcon(mark.level.icon, color: mark.level.iconColor(c)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              mark.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.text.small.copyWith(
                                color: switch (mark.level) {
                                  VeLevel.error => c.error,
                                  VeLevel.warning => c.warning,
                                  _ => c.text2,
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 12),
            if (sel.isValid) Text(caretPosition(controller.text, sel.extentOffset), style: muted),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------ diagnostics

/// `.dlist`: the command's checks for the chosen FFmpeg, each with its line
/// and "Go to" when it points at the text.
class _Diagnostics extends StatelessWidget {
  const _Diagnostics({required this.checks, required this.installation, required this.onGoTo, this.coreError});
  final List<AdvancedCheck> checks;
  final String installation;
  final void Function(int start, int end) onGoTo;

  /// The core couldn't lint the command.
  final String? coreError;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final counts = checkCounts(checks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Semantics(
              header: true,
              child: Text('Diagnostics', style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(650))),
            ),
            const SizedBox(width: 8),
            Text(counts.isEmpty ? 'none' : counts, style: t.text.caption.copyWith(color: c.muted)),
            const Spacer(),
            Text(installation, style: t.text.caption.copyWith(color: c.muted)),
          ],
        ),
        const SizedBox(height: 8),
        if (coreError != null)
          VeMessage(level: VeLevel.error, text: 'The core couldn’t check the command: $coreError')
        else if (checks.isEmpty)
          const VeCheckList(checks: [], emptyText: 'No problems found. Diagnostics update as you type.')
        else
          for (final check in checks) ...[_CheckRow(check: check, onGoTo: onGoTo), const SizedBox(height: 6)],
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check, required this.onGoTo});
  final AdvancedCheck check;
  final void Function(int start, int end) onGoTo;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final start = check.start, end = check.end;
    final canGo = start != null && end != null;
    Widget row(VeControlState s) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: s.hovered && canGo ? c.lineHover : c.line),
        borderRadius: BorderRadius.circular(VeRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: VeIcon(check.level.icon, color: check.level.iconColor(c)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(check.line == null ? '' : 'Line ${check.line}', style: t.text.small.copyWith(color: c.muted)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.message, style: t.text.small.copyWith(height: 1.4)),
                if (check.fix case final fix?) Text(fix, style: t.text.small.copyWith(color: c.muted, height: 1.4)),
              ],
            ),
          ),
          if (canGo) ...[
            const SizedBox(width: 8),
            Text(
              'Go to',
              style: t.text.small.copyWith(
                color: c.muted,
                decoration: TextDecoration.underline,
                decorationColor: c.muted,
              ),
            ),
          ],
        ],
      ),
    );
    if (!canGo) return Semantics(container: true, label: '${check.level.label}: ${check.message}', child: row(_idle));
    return Semantics(
      button: true,
      label: '${check.level.label}, line ${check.line}: ${check.message}. Go to',
      child: VeInteractive(
        onTap: () => onGoTo(start, end),
        cursor: SystemMouseCursors.click,
        builder: (context, s) => VeFocusRing(visible: s.focused, child: row(s)),
      ),
    );
  }

  static const _idle = VeControlState(hovered: false, focused: false, pressed: false, enabled: true);
}

// ------------------------------------------------------------ resolved command

/// "Resolved command": the core's compile of the command for the sample
/// context, with real pipe names, the output path and macros expanded.
class _Resolved extends StatelessWidget {
  const _Resolved({required this.data, required this.open, required this.onToggle, required this.onCopy});
  final EditorData data;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final compiled = data.compiled.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Semantics(
              button: true,
              expanded: open,
              label: 'Resolved command',
              child: VeInteractive(
                onTap: onToggle,
                cursor: SystemMouseCursors.click,
                builder: (context, s) => VeFocusRing(
                  visible: s.focused,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VeIcon(open ? VeIcons.chevronDown : VeIcons.chevronRight, color: c.ink),
                      const SizedBox(width: 4),
                      Text('Resolved command', style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(650))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'for the sample project',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.text.caption.copyWith(color: c.muted),
              ),
            ),
            const Spacer(),
            VeButton(
              label: 'Copy',
              icon: VeIcons.copy,
              size: VeButtonSize.small,
              variant: VeButtonVariant.ghost,
              tooltip: 'Copy the resolved command (Ctrl+Shift+C)',
              onPressed: compiled == null ? null : onCopy,
            ),
          ],
        ),
        if (open) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(VeRadius.lg),
            ),
            child: compiled == null
                ? Text(
                    'The core couldn’t build the command: ${data.compiled.error?.message ?? 'unknown error'}',
                    style: t.text.small.copyWith(color: c.text2),
                  )
                : _ResolvedText(lines: resolvedLines(compiled, data.recipe.command.template)),
          ),
        ],
      ],
    );
  }
}

class _ResolvedText extends StatelessWidget {
  const _ResolvedText({required this.lines});
  final List<List<ResolvedToken>> lines;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      for (final (j, token) in lines[i].indexed) {
        if (j > 0) spans.add(const TextSpan(text: ' '));
        spans.add(
          TextSpan(
            text: token.text,
            style: TextStyle(
              color: switch (token.part) {
                ResolvedPart.generated || ResolvedPart.input => c.muted,
                ResolvedPart.command => c.ink2,
                ResolvedPart.output => c.containerWire,
              },
              decoration: token.error ? TextDecoration.underline : null,
              decorationStyle: TextDecorationStyle.wavy,
              decorationColor: c.error,
            ),
          ),
        );
      }
      if (i < lines.length - 1) {
        spans.add(
          TextSpan(
            text: ' ^\n',
            style: TextStyle(color: c.faintText),
          ),
        );
      }
    }
    return Text.rich(TextSpan(children: spans), style: t.text.mono.copyWith(fontSize: 12, height: 1.6));
  }
}

// ------------------------------------------------------------ side column

class _SideColumn extends ConsumerWidget {
  const _SideColumn({
    required this.data,
    required this.model,
    required this.onSwitchToBasic,
    required this.onReplaceWithBasic,
    required this.onInsert,
  });

  final EditorData data;
  final CommandEditorModel model;
  final VoidCallback onSwitchToBasic;
  final VoidCallback onReplaceWithBasic;
  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final macros = ref.watch(macroEntriesProvider);
    final basic = data.basic;
    final present = {for (final chip in model.chips) chip.role.name};
    return Container(
      width: AdvancedWorkspace.sideWidth,
      decoration: BoxDecoration(
        color: c.panel,
        border: Border(left: BorderSide(color: c.line)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
        children: [
          _SwitchBackCard(
            basicLine: basic?.value == null
                ? 'The core couldn’t build the Basic settings: ${basic?.error?.message ?? 'unknown error'}'
                : '${basicSummaryLine(basic!.value!.summary)} These render if you switch now.',
            canReplace: basic?.value != null,
            onSwitchToBasic: onSwitchToBasic,
            onReplaceWithBasic: onReplaceWithBasic,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Semantics(
                header: true,
                child: Text('Macros', style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(650))),
              ),
              const Spacer(),
              Text('click to insert', style: t.text.caption.copyWith(color: c.muted)),
            ],
          ),
          const SizedBox(height: 6),
          if (macros?.value case final entries?)
            for (final m in entries)
              _MacroRow(
                entry: m,
                present: m.required && present.contains(m.name == '{inputs}' ? 'inputs' : 'output'),
                onInsert: () => onInsert(m.name),
              )
          else
            Text(
              'The core couldn’t list the macros: ${macros?.error?.message ?? 'unknown error'}',
              style: t.text.small.copyWith(color: c.text2),
            ),
        ],
      ),
    );
  }
}

/// `.card`: each mode keeps its own settings; what renders in each.
class _SwitchBackCard extends StatelessWidget {
  const _SwitchBackCard({
    required this.basicLine,
    required this.canReplace,
    required this.onSwitchToBasic,
    required this.onReplaceWithBasic,
  });

  final String basicLine;
  final bool canReplace;
  final VoidCallback onSwitchToBasic;
  final VoidCallback onReplaceWithBasic;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    Widget row(String label, String text) => Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(label, style: t.text.small.copyWith(fontWeight: const FontWeight(620))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: t.text.small.copyWith(color: c.text2, height: 1.45)),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(VeRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Switching back to Basic',
              style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(650)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Each mode keeps its own settings in this preset. Switching doesn’t convert anything.',
            style: t.text.small.copyWith(color: c.text2, height: 1.5),
          ),
          const SizedBox(height: 8),
          row('Advanced', 'Renders while Advanced is selected. Kept when you switch, and back when you switch again.'),
          row('Basic', basicLine),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              VeButton(
                label: 'Switch to Basic',
                size: VeButtonSize.small,
                tooltip: 'Ctrl+M',
                onPressed: onSwitchToBasic,
              ),
              VeButton(
                label: 'Replace with Basic settings',
                size: VeButtonSize.small,
                variant: VeButtonVariant.ghost,
                tooltip: 'Start the command again from the Basic settings',
                onPressed: canReplace ? onReplaceWithBasic : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `.macs li`: a macro, its value for the sample, and what it is for. The
/// locked macros insert only when the command has lost them.
class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.entry, required this.present, required this.onInsert});
  final MacroEntry entry;
  final bool present;
  final VoidCallback onInsert;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final enabled = !present;
    final (String? state, Color stateColor) = entry.required
        ? (present ? ('Required, locked', c.muted) : ('Required, missing: insert', c.error))
        : (null, c.muted);
    return Semantics(
      button: true,
      enabled: enabled,
      label: '${entry.name}. ${entry.description}${state == null ? '' : '. $state'}',
      child: VeInteractive(
        enabled: enabled,
        onTap: onInsert,
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        builder: (context, s) => VeFocusRing(
          visible: s.focused,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: s.hovered && enabled ? c.fill : null,
              borderRadius: BorderRadius.circular(VeRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      entry.name,
                      style: entry.required
                          ? t.text.monoSmall.copyWith(fontWeight: const FontWeight(600))
                          : t.text.monoSmall.copyWith(color: c.macro, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(width: 10),
                    const Spacer(),
                    if (state != null)
                      Text(state, style: t.text.caption.copyWith(color: stateColor))
                    else if (entry.value case final value?)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.text.monoSmall.copyWith(fontSize: 12, color: c.muted),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(entry.description, style: t.text.caption.copyWith(color: c.muted, height: 1.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
