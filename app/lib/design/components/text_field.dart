import 'package:flutter/material.dart' show InputDecoration, TextField, InputBorder;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../tokens.dart';
import 'interactive.dart';

/// `.inp`: a single-line text field. The mono variant is for FFmpeg
/// arguments (Extra arguments); the search variant has a leading icon on paper.
class VeTextField extends StatefulWidget {
  const VeTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.focusNode,
    this.mono = false,
    this.search = false,
    this.textAlign = TextAlign.start,
    this.height = 32,
    this.width,
    this.inputFormatters,
    this.semanticLabel,
    this.enabled = true,
    this.error = false,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final FocusNode? focusNode;
  final bool mono;
  final bool search;
  final TextAlign textAlign;
  final double height;
  final double? width;
  final List<TextInputFormatter>? inputFormatters;
  final String? semanticLabel;
  final bool enabled;

  /// Draws the border in the error colour.
  final bool error;

  @override
  State<VeTextField> createState() => _VeTextFieldState();
}

class _VeTextFieldState extends State<VeTextField> {
  TextEditingController? _own;
  FocusNode? _ownFocus;

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController(text: widget.initialValue));
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(VeTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _own?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final base = widget.mono ? t.text.mono.copyWith(fontSize: 13, height: 1.3) : t.text.body.copyWith(height: 1.3);
    final field = TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      inputFormatters: widget.inputFormatters,
      textAlign: widget.textAlign,
      style: base,
      cursorColor: c.ink,
      cursorWidth: 1.5,
      cursorHeight: 16,
      autocorrect: false,
      enableSuggestions: false,
      maxLines: 1,
      decoration: InputDecoration(
        isDense: true,
        isCollapsed: true,
        border: InputBorder.none,
        hintText: widget.placeholder,
        hintStyle: base.copyWith(color: c.faintText),
        contentPadding: EdgeInsets.zero,
      ),
    );
    return Semantics(
      label: widget.semanticLabel,
      textField: true,
      child: VeFocusRing(
        visible: _focus.hasFocus,
        child: VeDisabled(
          disabled: !widget.enabled,
          child: Container(
            height: widget.height,
            width: widget.width,
            padding: EdgeInsets.only(left: widget.search ? 9 : 10, right: 10),
            decoration: BoxDecoration(
              color: widget.search ? c.paper : c.surface,
              border: Border.all(color: widget.error ? c.error : c.line2),
              borderRadius: BorderRadius.circular(VeRadius.md),
            ),
            child: Row(
              children: [
                if (widget.search) ...[VeIcon(VeIcons.search, color: c.muted), const SizedBox(width: 7)],
                Expanded(child: field),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.num`: a right-aligned number field with its unit ("kb/s", "seconds").
/// [onChanged] gets null for an empty field and ignores text that is not a
/// number. The field shows [value] whenever it is not being edited.
class VeNumberField extends StatefulWidget {
  const VeNumberField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.unit,
    this.placeholder,
    this.width = 100,
    this.height = 32,
    this.decimals = false,
    this.focusNode,
  });

  final num? value;
  final ValueChanged<num?>? onChanged;
  final String semanticLabel;
  final String? unit;
  final String? placeholder;
  final double width;
  final double height;
  final bool decimals;
  final FocusNode? focusNode;

  @override
  State<VeNumberField> createState() => _VeNumberFieldState();
}

class _VeNumberFieldState extends State<VeNumberField> {
  late final TextEditingController _controller = TextEditingController(text: _text(widget.value));
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  String _text(num? v) {
    if (v == null) return '';
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toString();
  }

  @override
  void didUpdateWidget(VeNumberField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) _controller.text = _text(widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _changed(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) {
      widget.onChanged?.call(null);
      return;
    }
    final v = num.tryParse(trimmed);
    if (v != null) widget.onChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final field = VeTextField(
      controller: _controller,
      focusNode: _focus,
      width: widget.width,
      height: widget.height,
      textAlign: TextAlign.right,
      placeholder: widget.placeholder,
      semanticLabel: widget.semanticLabel,
      enabled: widget.onChanged != null,
      onChanged: _changed,
      onEditingComplete: () => _controller.text = _text(widget.value),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(widget.decimals ? r'[0-9.]' : r'[0-9]'))],
    );
    if (widget.unit == null) return field;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        field,
        const SizedBox(width: 8),
        Text(widget.unit!, style: t.text.small.copyWith(color: t.colors.muted)),
      ],
    );
  }
}
