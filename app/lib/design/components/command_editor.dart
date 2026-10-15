import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' show AdaptiveTextSelectionToolbar, desktopTextSelectionHandleControls;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'command_view.dart' show CommandRole;
import 'message.dart' show VeLevel;
import 'status.dart';

// ------------------------------------------------------------ display model

/// One argument of the command as the core read it, for highlighting.
/// Offsets are UTF-16 code units into the editor's text, end exclusive.
@immutable
class EditorWord {
  const EditorWord(this.start, this.end, {this.flag = false, this.macro = false, this.role});
  final int start;
  final int end;

  /// An option name (`-crf`): drawn bold, in its stage's colour when known.
  final bool flag;

  /// Holds a macro (`{gop:2s}`): drawn in the macro colour.
  final bool macro;

  /// The command stage the core says the word belongs to; null when unknown.
  final CommandRole? role;
}

/// A locked macro (`{inputs}`, `{output}`): drawn as a chip. Typing inside it
/// or deleting part of it is refused with [message]; it can be selected whole,
/// cut and pasted, or deleted.
@immutable
class EditorChip {
  const EditorChip(this.start, this.end, {required this.role, required this.message});
  final int start;
  final int end;
  final CommandRole role;

  /// "{inputs} is locked. …"
  final String message;
}

/// A diagnostic over a range of the text.
@immutable
class EditorMark {
  const EditorMark(this.start, this.end, {required this.level, required this.message, this.wholeCommand = false});
  final int start;
  final int end;
  final VeLevel level;
  final String message;

  /// About the command as a whole (its range is the whole text): listed, not
  /// underlined.
  final bool wholeCommand;

  bool get underlined => !wholeCommand && end > start;

  static int rank(VeLevel l) => switch (l) {
    VeLevel.error => 0,
    VeLevel.warning => 1,
    VeLevel.info => 2,
    VeLevel.hint => 3,
    VeLevel.ok => 4,
  };
}

/// Everything the editor draws for one text. Built by the feature from the
/// core's results; the editor computes none of it.
@immutable
class CommandEditorModel {
  const CommandEditorModel({required this.text, this.words = const [], this.chips = const [], this.marks = const []});

  final String text;
  final List<EditorWord> words;
  final List<EditorChip> chips;
  final List<EditorMark> marks;

  /// The chip [offset] falls strictly inside, if any.
  EditorChip? chipInside(int offset) => chips.where((c) => offset > c.start && offset < c.end).firstOrNull;

  /// The most severe mark touching a caret at [offset].
  EditorMark? markAt(int offset) {
    EditorMark? best;
    for (final m in marks) {
      if (m.wholeCommand || offset < m.start || offset > m.end) continue;
      if (best == null || EditorMark.rank(m.level) < EditorMark.rank(best.level)) best = m;
    }
    return best;
  }
}

/// One suggestion in the autocomplete list.
@immutable
class EditorSuggestion {
  const EditorSuggestion(this.value, {this.description = '', this.detail = '', this.availability});

  /// What is inserted: "-preset", "slow", "libx265".
  final String value;
  final String description;

  /// Type and default: "string, default medium".
  final String detail;

  /// For encoders: ready, not in this FFmpeg, failed its test. Null shows none.
  final VeAvailability? availability;
}

/// The autocomplete list for a caret: what it offers and the range of text a
/// choice replaces (UTF-16, end exclusive).
@immutable
class EditorCompletion {
  const EditorCompletion({
    required this.title,
    required this.start,
    required this.end,
    required this.items,
    this.source = '',
    this.footer = '',
  });

  /// "Options", "Values for -tune".
  final String title;

  /// Where the entries come from: "libx264 and FFmpeg".
  final String source;
  final int start;
  final int end;
  final List<EditorSuggestion> items;
  final String footer;
}

/// Asks for the list at [caret]. [manual] is Ctrl+Space; otherwise the list
/// opens only where the caller says typing should open it. Null: nothing.
typedef EditorCompleter = EditorCompletion? Function(String text, int caret, {required bool manual});

// ------------------------------------------------------------ controller

/// The editor's text, highlighted from [describe]'s model for the current
/// text. A caret moved strictly inside a chip jumps to the chip's edge.
class CommandEditingController extends TextEditingController {
  CommandEditingController({super.text, this.describe});

  /// The model for a text; called with the current text whenever the editor
  /// draws or guards an edit, so it should be cheap for a repeated text.
  CommandEditorModel Function(String text)? describe;

  CommandEditorModel modelFor(String text) {
    final m = describe?.call(text);
    return m != null && m.text == text ? m : CommandEditorModel(text: text);
  }

  CommandEditorModel get model => modelFor(text);

  @override
  set value(TextEditingValue next) => super.value = _keepCaretOutOfChips(next);

  TextEditingValue _keepCaretOutOfChips(TextEditingValue next) {
    final sel = next.selection;
    if (next.text != text || !sel.isValid || !sel.isCollapsed) return next;
    final chip = modelFor(next.text).chipInside(sel.baseOffset);
    if (chip == null) return next;
    final from = selection.isValid ? selection.baseOffset : sel.baseOffset;
    final int to;
    if ((sel.baseOffset - from).abs() == 1) {
      // Arrow keys: carry on in the same direction.
      to = sel.baseOffset > from ? chip.end : chip.start;
    } else {
      to = sel.baseOffset - chip.start <= chip.end - sel.baseOffset ? chip.start : chip.end;
    }
    return next.copyWith(selection: TextSelection.collapsed(offset: to));
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    // An IME composition keeps the platform's underline.
    if (withComposing && value.isComposingRangeValid && !value.composing.isCollapsed) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final m = model;
    if (text.length > CommandEditor.highlightLimit || (m.words.isEmpty && m.chips.isEmpty && m.marks.isEmpty)) {
      return TextSpan(style: style, text: text);
    }
    final c = VeTokens.of(context).colors;
    final cuts = <int>{0, text.length};
    void cut(int s, int e) {
      if (s >= 0 && e <= text.length && s < e) cuts.addAll([s, e]);
    }

    for (final w in m.words) {
      cut(w.start, w.end);
    }
    for (final ch in m.chips) {
      cut(ch.start, ch.end);
    }
    for (final mk in m.marks) {
      if (mk.underlined) cut(mk.start, mk.end);
    }
    final points = cuts.toList()..sort();
    final children = <TextSpan>[];
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i], b = points[i + 1];
      TextStyle? s;
      final chip = m.chips.where((x) => x.start <= a && x.end >= b).firstOrNull;
      final word = m.words.where((x) => x.start <= a && x.end >= b).firstOrNull;
      if (chip != null) {
        s = TextStyle(color: c.ink2);
      } else if (word != null && word.macro) {
        s = TextStyle(color: c.macro, fontStyle: FontStyle.italic);
      } else if (word != null && word.flag) {
        s = TextStyle(fontWeight: const FontWeight(600), color: roleColor(c, word.role));
      }
      EditorMark? mark;
      for (final mk in m.marks) {
        if (!mk.underlined || mk.start > a || mk.end < b) continue;
        if (mark == null || EditorMark.rank(mk.level) < EditorMark.rank(mark.level)) mark = mk;
      }
      if (mark != null) {
        final hint = mark.level == VeLevel.hint || mark.level == VeLevel.info;
        s = (s ?? const TextStyle()).copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: hint ? TextDecorationStyle.dotted : TextDecorationStyle.wavy,
          decorationColor: switch (mark.level) {
            VeLevel.error => c.error,
            VeLevel.warning => c.warningWave,
            _ => c.muted,
          },
          decorationThickness: hint ? 2 : 1.5,
        );
      }
      children.add(TextSpan(text: text.substring(a, b), style: s));
    }
    return TextSpan(style: style, children: children);
  }

  /// A stage's colour for option names and line stripes (UI_SPEC §10 roles).
  static Color? roleColor(VePalette c, CommandRole? role) => switch (role) {
    CommandRole.inputs => c.muted,
    CommandRole.video => c.videoWire,
    CommandRole.audio => c.audioWire,
    CommandRole.mux || CommandRole.output => c.containerWire,
    null => null,
  };
}

/// Refuses an edit that changes part of a chip, and selects the chip instead
/// so a second Delete removes it whole.
class _ChipGuard extends TextInputFormatter {
  _ChipGuard(this.controller, this.onRefused);
  final CommandEditingController Function() controller;
  final void Function(EditorChip chip) onRefused;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    if (old.text == next.text) return next;
    final chips = controller().modelFor(old.text).chips;
    if (chips.isEmpty) return next;
    final (a, b) = replacedRange(old, next);
    for (final chip in chips) {
      final touches = a < b ? (a < chip.end && b > chip.start) : (a > chip.start && a < chip.end);
      final whole = a <= chip.start && b >= chip.end;
      if (touches && !whole) {
        onRefused(chip);
        return old.copyWith(
          selection: TextSelection(baseOffset: chip.start, extentOffset: chip.end),
          composing: TextRange.empty,
        );
      }
    }
    return next;
  }
}

/// The range of [old]'s text that [next] replaced. A typed, pasted or
/// deleted edit ends at the new caret, so the text after it is the unchanged
/// tail; the start is then kept at or before both selections. Without that
/// anchor (a composing IME) the common prefix and suffix decide. This keeps a
/// repeated character, such as the "{" of a pasted "{output} " before
/// "{inputs}", from moving the edit inside a chip.
(int, int) replacedRange(TextEditingValue old, TextEditingValue next) {
  final o = old.text, n = next.text;
  final shortest = math.min(o.length, n.length);
  int? s;
  final caret = next.selection;
  if (caret.isValid && caret.isCollapsed && caret.end <= n.length) {
    final tail = n.length - caret.end;
    if (tail <= o.length && o.endsWith(n.substring(caret.end))) s = tail;
  }
  if (s == null) {
    s = 0;
    while (s! < shortest && o.codeUnitAt(o.length - 1 - s) == n.codeUnitAt(n.length - 1 - s)) {
      s++;
    }
  }
  final limit = [
    o.length - s,
    n.length - s,
    if (old.selection.isValid) old.selection.start,
    if (caret.isValid) caret.start,
  ].reduce(math.min);
  var p = 0;
  while (p < limit && o.codeUnitAt(p) == n.codeUnitAt(p)) {
    p++;
  }
  return (p, o.length - s);
}

// ------------------------------------------------------------ widget

/// `CommandEditor` (UI_SPEC §3, §11; `.edbox`): a multi-line monospace editor
/// for a whole FFmpeg command. Line numbers and a stripe per line in the
/// gutter; option names, macros and locked chips highlighted; diagnostics
/// underlined (errors red, warnings amber, hints dotted) with the most severe
/// message of each line at its end and a bubble on hover. Everything drawn
/// comes from the controller's model. With [complete], an autocomplete list
/// opens where it says (and on Ctrl+Space): arrows move, Tab or Enter
/// inserts, Esc closes.
class CommandEditor extends StatefulWidget {
  const CommandEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.complete,
    this.semanticLabel = 'FFmpeg command',
    this.minLines = 4,
  });

  final CommandEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final EditorCompleter? complete;
  final String semanticLabel;
  final int minLines;

  /// Longer text is shown plain: the core still checks it.
  static const int highlightLimit = 20000;

  /// Left of the text: line numbers and the stripe.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(58, 12, 18, 14);

  @override
  State<CommandEditor> createState() => CommandEditorState();
}

class CommandEditorState extends State<CommandEditor> implements TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey = GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  late final TextSelectionGestureDetectorBuilder _gestures = TextSelectionGestureDetectorBuilder(delegate: this);
  late final _ChipGuard _guard = _ChipGuard(() => widget.controller, _refused);
  final GlobalKey _paintKey = GlobalKey();
  final OverlayPortalController _bubblePortal = OverlayPortalController();

  /// What the bubble says and the text range (global coordinates) it points at.
  ({Rect anchor, String text, bool status})? _bubble;
  Timer? _bubbleTimer;

  RenderEditable? get renderEditable => editableTextKey.currentState?.renderEditable;

  /// The caret's rectangle in global coordinates, for popovers.
  Rect? caretRect() {
    final editable = renderEditable;
    final sel = widget.controller.selection;
    if (editable == null || !editable.attached || !sel.isValid) return null;
    final local = editable.getLocalRectForCaret(TextPosition(offset: sel.extentOffset));
    return MatrixUtils.transformRect(editable.getTransformTo(null), local);
  }

  // Autocomplete.
  final OverlayPortalController _suggestPortal = OverlayPortalController();
  final ScrollController _suggestScroll = ScrollController();
  EditorCompletion? _completion;
  int _active = 0;
  TextEditingValue _seen = TextEditingValue.empty;

  /// The open autocomplete list, if any.
  EditorCompletion? get completion => _completion;

  /// The highlighted entry of [completion].
  int get activeSuggestion => _active;

  static const double _suggestionHeight = 28;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_focusChanged);
    widget.controller.addListener(_controllerChanged);
    _seen = widget.controller.value;
  }

  @override
  void didUpdateWidget(CommandEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_focusChanged);
      widget.focusNode.addListener(_focusChanged);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_controllerChanged);
      widget.controller.addListener(_controllerChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusChanged);
    widget.controller.removeListener(_controllerChanged);
    _bubbleTimer?.cancel();
    _suggestScroll.dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (!widget.focusNode.hasFocus) _closeCompletion();
    setState(() {});
  }

  /// A caret moved without typing (a click, an arrow, Go to) closes the list.
  void _controllerChanged() {
    final value = widget.controller.value;
    if (_completion != null && value.text == _seen.text && value.selection != _seen.selection) _closeCompletion();
    _seen = value;
  }

  void _changed(String text) {
    widget.onChanged(text);
    _refreshCompletion(manual: false);
  }

  void _refreshCompletion({required bool manual}) {
    final complete = widget.complete;
    final sel = widget.controller.selection;
    if (complete == null || !sel.isValid || !sel.isCollapsed) return _closeCompletion();
    final next = complete(widget.controller.text, sel.baseOffset, manual: manual);
    if (next == null || next.items.isEmpty) return _closeCompletion();
    setState(() {
      _completion = next;
      _active = 0;
    });
    _suggestPortal.show();
    if (_suggestScroll.hasClients) _suggestScroll.jumpTo(0);
    // The caret's place is known after this frame's layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _completion != null) setState(() {});
    });
  }

  void _closeCompletion() {
    if (_completion == null) return;
    _suggestPortal.hide();
    if (mounted) setState(() => _completion = null);
  }

  void _move(int step) {
    final c = _completion;
    if (c == null) return;
    setState(() => _active = (_active + step) % c.items.length);
    if (!_suggestScroll.hasClients) return;
    final top = _active * _suggestionHeight;
    final view = _suggestScroll.position.viewportDimension;
    if (top < _suggestScroll.offset) {
      _suggestScroll.jumpTo(top);
    } else if (top + _suggestionHeight > _suggestScroll.offset + view) {
      _suggestScroll.jumpTo(top + _suggestionHeight - view);
    }
  }

  /// Puts the chosen entry over the word being completed, then a space, and
  /// asks again: an option that takes values opens its values next.
  void accept(int index) {
    final c = _completion;
    if (c == null || index < 0 || index >= c.items.length) return;
    final controller = widget.controller;
    final text = controller.text;
    final start = c.start.clamp(0, text.length);
    final end = c.end.clamp(start, text.length);
    final model = controller.model;
    if (model.chips.any((chip) => start < chip.end && end > chip.start)) return _closeCompletion();
    final value = c.items[index].value;
    // A space or tab already there is reused; a line break keeps its line.
    final spaced = end < text.length && const [0x20, 0x09].contains(text.codeUnitAt(end));
    final next = text.replaceRange(start, end, spaced ? value : '$value ');
    _closeCompletion();
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + value.length + 1),
    );
    _changed(next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.space && HardwareKeyboard.instance.isControlPressed && widget.complete != null) {
      _refreshCompletion(manual: true);
      return KeyEventResult.handled;
    }
    if (_completion == null) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
      accept(_active);
    } else if (key == LogicalKeyboardKey.escape) {
      _closeCompletion();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ------------------------------------------------------------ bubbles

  Rect? _globalRange(int start, int end) {
    final editable = renderEditable;
    if (editable == null || !editable.attached) return null;
    final rects = glyphRects(editable, start, end);
    if (rects.isEmpty) return null;
    return MatrixUtils.transformRect(editable.getTransformTo(null), rects.reduce((a, b) => a.expandToInclude(b)));
  }

  void _showBubble(Rect anchor, String text, {required bool status, Duration? hideAfter}) {
    _bubbleTimer?.cancel();
    setState(() => _bubble = (anchor: anchor, text: text, status: status));
    _bubblePortal.show();
    if (hideAfter != null) _bubbleTimer = Timer(hideAfter, _hideBubble);
  }

  void _hideBubble() {
    _bubbleTimer?.cancel();
    if (!mounted || _bubble == null) return;
    _bubblePortal.hide();
    setState(() => _bubble = null);
  }

  void _refused(EditorChip chip) {
    // Called from the formatter, during text input: show after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anchor = _globalRange(chip.start, chip.end);
      if (anchor != null) {
        _showBubble(anchor, chip.message, status: true, hideAfter: const Duration(milliseconds: 2800));
      }
    });
  }

  void _hover(PointerHoverEvent e) {
    final editable = renderEditable;
    if (editable == null || !editable.attached) return;
    final offset = editable.getPositionForPoint(e.position).offset;
    final local = editable.globalToLocal(e.position);
    EditorMark? hit;
    for (final m in widget.controller.model.marks) {
      if (!m.underlined || offset < m.start || offset > m.end) continue;
      if (!glyphRects(editable, m.start, m.end).any((r) => r.inflate(2).contains(local))) continue;
      if (hit == null || EditorMark.rank(m.level) < EditorMark.rank(hit.level)) hit = m;
    }
    if (hit == null) {
      if (_bubble != null && !_bubble!.status) _hideBubble();
      return;
    }
    if (_bubble?.text == hit.message && _bubble?.status == false) return;
    final anchor = _globalRange(hit.start, hit.end);
    if (anchor != null) _showBubble(anchor, hit.message, status: false);
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final focused = widget.focusNode.hasFocus;
    final style = t.text.monoEditor.copyWith(color: c.ink);
    final editable = EditableText(
      key: editableTextKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      style: style,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      cursorColor: c.ink,
      backgroundCursorColor: c.faint,
      cursorWidth: 1.5,
      selectionColor: focused ? c.selection : null,
      selectionControls: desktopTextSelectionHandleControls,
      contextMenuBuilder: (context, state) => AdaptiveTextSelectionToolbar.editableText(editableTextState: state),
      maxLines: null,
      minLines: widget.minLines,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      inputFormatters: [_guard],
      onChanged: _changed,
      rendererIgnoresPointer: true,
      mouseCursor: MouseCursor.defer,
    );
    final painterArgs = _PaintArgs(
      paintKey: _paintKey,
      editableKey: editableTextKey,
      controller: widget.controller,
      model: widget.controller.model,
      colors: c,
      numberStyle: t.text.caption.copyWith(fontSize: 12, height: 1, color: c.faintText),
      lensStyle: t.text.small.copyWith(height: 1),
      lineHeight: style.fontSize! * style.height!,
    );
    return Semantics(
      label: widget.semanticLabel,
      textField: true,
      child: OverlayPortal(
        controller: _bubblePortal,
        overlayChildBuilder: _buildBubble,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: focused ? c.ink : c.line2),
            borderRadius: BorderRadius.circular(VeRadius.lg),
            boxShadow: focused ? [BoxShadow(color: c.shadow.withValues(alpha: 0.08), spreadRadius: 3)] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(VeRadius.lg),
            child: CustomPaint(
              key: _paintKey,
              painter: _BackPainter(painterArgs),
              foregroundPainter: _FrontPainter(painterArgs),
              child: MouseRegion(
                cursor: SystemMouseCursors.text,
                onHover: _hover,
                onExit: (_) {
                  if (_bubble != null && !_bubble!.status) _hideBubble();
                },
                child: Padding(
                  padding: CommandEditor.padding,
                  child: TextFieldTapRegion(
                    child: OverlayPortal(
                      controller: _suggestPortal,
                      overlayChildBuilder: _buildSuggestions,
                      // Sees keys before the text-editing shortcuts above it.
                      child: Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        onKeyEvent: _onKey,
                        child: _gestures.buildGestureDetector(behavior: HitTestBehavior.translucent, child: editable),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// `.ac`: the autocomplete list under the caret (over it without room).
  Widget _buildSuggestions(BuildContext context) {
    final c = _completion;
    final caret = caretRect();
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (c == null || caret == null || overlay == null || !overlay.hasSize) return const SizedBox.shrink();
    final t = VeTokens.of(context);
    final colors = t.colors;
    const width = 400.0;
    final listHeight = math.min(c.items.length, 8) * _suggestionHeight + 8;
    final height = listHeight + 64;
    final at = overlay.globalToLocal(caret.bottomLeft);
    final top = overlay.globalToLocal(caret.topLeft).dy;
    final left = (at.dx - 8).clamp(8.0, math.max(8.0, overlay.size.width - width - 8)).toDouble();
    final below = at.dy + 6 + height <= overlay.size.height - 8;
    return Positioned(
      left: left,
      top: below ? at.dy + 6 : math.max(8.0, top - 6 - height),
      width: width,
      child: TextFieldTapRegion(
        child: Semantics(
          container: true,
          label: c.title,
          explicitChildNodes: true,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.line2),
              borderRadius: BorderRadius.circular(VeRadius.lg),
              boxShadow: t.popoverShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: colors.line)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        c.title,
                        style: t.text.caption.copyWith(color: colors.ink, fontWeight: const FontWeight(600)),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          c.source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.text.caption.copyWith(color: colors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    controller: _suggestScroll,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemExtent: _suggestionHeight,
                    itemCount: c.items.length,
                    itemBuilder: (context, i) =>
                        _SuggestionRow(item: c.items[i], active: i == _active, onTap: () => accept(i)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.footer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.text.caption.copyWith(color: colors.muted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Tab or Enter inserts', style: t.text.caption.copyWith(color: colors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final b = _bubble;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (b == null || overlay == null) return const SizedBox.shrink();
    final t = VeTokens.of(context);
    final at = overlay.globalToLocal(b.anchor.bottomLeft) + const Offset(0, 8);
    final left = math.max(8.0, math.min(at.dx, overlay.size.width - 340));
    return Positioned(
      left: left,
      top: at.dy,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: b.status,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 330),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: t.colors.ink, borderRadius: BorderRadius.circular(VeRadius.md)),
            child: Text(b.text, style: t.text.small.copyWith(color: t.colors.onInk, height: 1.35)),
          ),
        ),
      ),
    );
  }
}

/// `.ac-i`: the value, then what it is (description, type and default), and
/// an encoder's state in the chosen FFmpeg.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.item, required this.active, required this.onTap});
  final EditorSuggestion item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final about = [
      if (item.description.isNotEmpty) item.description,
      if (item.detail.isNotEmpty) item.detail,
    ].join(' · ');
    final availability = item.availability;
    return Semantics(
      button: true,
      selected: active,
      label: [item.value, if (about.isNotEmpty) about, if (availability != null) availability.label].join(', '),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: ExcludeSemantics(
            child: Container(
              color: active ? c.videoTint : null,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (active)
                    Positioned(
                      left: -12,
                      top: 4,
                      bottom: 4,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: c.videoWire,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          item.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.text.mono.copyWith(
                            fontSize: 13,
                            color: c.videoText,
                            fontWeight: const FontWeight(600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          about,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.text.small.copyWith(color: c.muted),
                        ),
                      ),
                      if (availability != null) ...[const SizedBox(width: 8), VeStatusTag(availability)],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ painting

/// What both painters need: where the text is laid out and what to draw.
class _PaintArgs {
  _PaintArgs({
    required this.paintKey,
    required this.editableKey,
    required this.controller,
    required this.model,
    required this.colors,
    required this.numberStyle,
    required this.lensStyle,
    required this.lineHeight,
  });

  final GlobalKey paintKey;
  final GlobalKey<EditableTextState> editableKey;
  final CommandEditingController controller;

  /// The model when the editor was built; a new one (new diagnostics for the
  /// same text) repaints.
  final CommandEditorModel model;
  final VePalette colors;
  final TextStyle numberStyle;
  final TextStyle lensStyle;
  final double lineHeight;

  /// The laid-out text and the transform from it to the painter's box.
  ({RenderEditable editable, Matrix4 transform})? geometry() {
    final self = paintKey.currentContext?.findRenderObject() as RenderBox?;
    final editable = editableKey.currentState?.renderEditable;
    if (self == null || editable == null || !editable.attached || !editable.hasSize) return null;
    return (editable: editable, transform: editable.getTransformTo(self));
  }

  bool same(_PaintArgs o) =>
      o.controller == controller &&
      identical(o.model, model) &&
      o.colors == colors &&
      o.numberStyle == numberStyle &&
      o.lensStyle == lensStyle &&
      o.lineHeight == lineHeight;
}

/// Rectangles around the text of [start, end) in [editable]'s coordinates.
/// The platform's selection boxes (`BoxWidthStyle.max`, as text fields use)
/// pad a range's first and last lines out to the widest line; the padding is
/// cut back to the range's own caret positions.
List<Rect> glyphRects(RenderEditable editable, int start, int end) {
  final first = editable.getLocalRectForCaret(TextPosition(offset: start));
  final last = editable.getLocalRectForCaret(TextPosition(offset: end, affinity: TextAffinity.upstream));
  bool onLine(Rect box, Rect caret) => caret.center.dy >= box.top && caret.center.dy <= box.bottom;
  final out = <Rect>[];
  for (final box in editable.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end))) {
    var r = box.toRect();
    if (onLine(r, first)) {
      if (r.right <= first.left + 0.5) continue;
      r = Rect.fromLTRB(math.max(r.left, first.left), r.top, r.right, r.bottom);
    }
    if (onLine(r, last)) {
      if (r.left >= last.left - 0.5) continue;
      r = Rect.fromLTRB(r.left, r.top, math.min(r.right, last.left), r.bottom);
    }
    if (r.width > 0) out.add(r);
  }
  return out;
}

/// Logical lines of [text]: start offset and end offset (before the line break).
List<(int, int)> _lines(String text) {
  final out = <(int, int)>[];
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0A) {
      out.add((start, i));
      start = i + 1;
    }
  }
  out.add((start, text.length));
  return out;
}

int _lineOf(List<(int, int)> lines, int offset) {
  for (var i = 0; i < lines.length; i++) {
    if (offset <= lines[i].$2) return i;
  }
  return lines.length - 1;
}

/// The most severe mark starting on each line (whole-command marks on the first).
Map<int, EditorMark> _lineMarks(CommandEditorModel m, List<(int, int)> lines) {
  final out = <int, EditorMark>{};
  for (final mk in m.marks) {
    final line = mk.wholeCommand ? 0 : _lineOf(lines, mk.start);
    final best = out[line];
    if (best == null || EditorMark.rank(mk.level) < EditorMark.rank(best.level)) out[line] = mk;
  }
  return out;
}

/// The stage a line belongs to: its first chip or coloured option.
CommandRole? _lineRole(CommandEditorModel m, (int, int) line) {
  int? first;
  CommandRole? role;
  void consider(int start, CommandRole? r) {
    if (r == null || start < line.$1 || start > line.$2) return;
    if (first == null || start < first!) {
      first = start;
      role = r;
    }
  }

  for (final c in m.chips) {
    consider(c.start, c.role);
  }
  for (final w in m.words) {
    if (w.flag) consider(w.start, w.role);
  }
  return role;
}

/// Gutter (line numbers and stripes) and chip backgrounds, under the text.
class _BackPainter extends CustomPainter {
  _BackPainter(this.args) : super(repaint: args.controller);
  final _PaintArgs args;

  @override
  void paint(Canvas canvas, Size size) {
    final g = args.geometry();
    if (g == null) return;
    final c = args.colors;
    final m = args.controller.model;
    final text = args.controller.text;
    Rect caret(int offset) =>
        MatrixUtils.transformRect(g.transform, g.editable.getLocalRectForCaret(TextPosition(offset: offset)));
    final textLeft = MatrixUtils.transformPoint(g.transform, Offset.zero).dx;

    final lines = _lines(text);
    final marks = _lineMarks(m, lines);
    for (var i = 0; i < lines.length; i++) {
      final (start, end) = lines[i];
      final top = caret(start).top;
      final bottom = caret(end).top + args.lineHeight;
      final mark = marks[i];
      final number = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: mark == null
              ? args.numberStyle
              : args.numberStyle.copyWith(
                  fontWeight: const FontWeight(700),
                  color: switch (mark.level) {
                    VeLevel.error => c.error,
                    VeLevel.warning => c.warning,
                    _ => c.ink,
                  },
                ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      number.paint(canvas, Offset(textLeft - 22 - number.width, top + (args.lineHeight - number.height) / 2));
      number.dispose();
      final stripe = CommandEditingController.roleColor(c, _lineRole(m, lines[i]));
      if (stripe != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(textLeft - 14, top + 3, textLeft - 11, bottom - 3),
            const Radius.circular(2),
          ),
          Paint()..color = stripe,
        );
      }
    }

    final fill = Paint()..color = c.fillSelected2;
    for (final chip in m.chips) {
      if (chip.end > text.length) continue;
      for (final box in glyphRects(g.editable, chip.start, chip.end)) {
        final r = MatrixUtils.transformRect(g.transform, box).inflate(2);
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), fill);
      }
    }
  }

  @override
  bool shouldRepaint(_BackPainter old) => !old.args.same(args);
}

/// Lock badges on chips and each line's most severe message, over the text.
class _FrontPainter extends CustomPainter {
  _FrontPainter(this.args) : super(repaint: args.controller);
  final _PaintArgs args;

  @override
  void paint(Canvas canvas, Size size) {
    final g = args.geometry();
    if (g == null) return;
    final c = args.colors;
    final m = args.controller.model;
    final text = args.controller.text;

    for (final chip in m.chips) {
      if (chip.end > text.length) continue;
      final boxes = glyphRects(g.editable, chip.start, chip.end);
      if (boxes.isEmpty) continue;
      final r = MatrixUtils.transformRect(g.transform, boxes.last);
      // At the chip's top-right corner, but kept inside its own line box so
      // it doesn't cover the line above (a wrapped `{inputs}`).
      final lineTop = r.center.dy - args.lineHeight / 2;
      _lockBadge(canvas, Offset(r.right, math.max(r.top, lineTop + _badgeRadius)), c);
    }

    final lines = _lines(text);
    final right = size.width - CommandEditor.padding.right;
    _lineMarks(m, lines).forEach((line, mark) {
      final end = MatrixUtils.transformRect(
        g.transform,
        g.editable.getLocalRectForCaret(TextPosition(offset: lines[line].$2)),
      );
      final left = end.right + 28;
      if (right - left < 48) return;
      final lens = TextPainter(
        text: TextSpan(
          text: mark.message,
          style: args.lensStyle.copyWith(
            color: switch (mark.level) {
              VeLevel.error => c.error,
              VeLevel.warning => c.warning,
              _ => c.muted,
            },
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: right - left);
      lens.paint(canvas, Offset(left, end.top + (args.lineHeight - lens.height) / 2));
      lens.dispose();
    });
  }

  static const double _badgeRadius = 6;

  /// The mockup's `.t-lock::after`: a 12 px dark disc with a white padlock.
  static void _lockBadge(Canvas canvas, Offset center, VePalette c) {
    canvas.drawCircle(center, _badgeRadius, Paint()..color = c.lockBackground);
    final o = center - const Offset(6, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(o.dx + 3, o.dy + 5.5, 6, 4.5), const Radius.circular(1)),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawPath(
      Path()
        ..moveTo(o.dx + 4.3, o.dy + 5.5)
        ..lineTo(o.dx + 4.3, o.dy + 4.2)
        ..arcToPoint(Offset(o.dx + 7.7, o.dy + 4.2), radius: const Radius.circular(1.7))
        ..lineTo(o.dx + 7.7, o.dy + 5.5),
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  @override
  bool shouldRepaint(_FrontPainter old) => !old.args.same(args);
}
