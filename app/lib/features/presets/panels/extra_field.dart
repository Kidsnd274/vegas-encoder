import 'package:flutter/widgets.dart';

import '../../../design/components/field.dart';
import '../../../design/components/message.dart';
import '../../../design/components/text_field.dart';

/// `ExtraArgumentsField` (UI_SPEC §2, Extra arguments): one per stream, in a
/// monospace font. The core checks each option against what the selected
/// FFmpeg reports and returns warnings for this field; it never blocks saving.
class ExtraArgumentsField extends StatefulWidget {
  const ExtraArgumentsField({
    super.key,
    required this.kind,
    required this.value,
    required this.onChanged,
    this.modified = false,
    this.onReset,
    this.messages = const [],
  });

  /// "video" or "audio".
  final String kind;
  final String value;
  final ValueChanged<String> onChanged;
  final bool modified;
  final VoidCallback? onReset;
  final List<VeMessage> messages;

  @override
  State<ExtraArgumentsField> createState() => _ExtraArgumentsFieldState();
}

class _ExtraArgumentsFieldState extends State<ExtraArgumentsField> {
  late final TextEditingController _text = TextEditingController(text: widget.value);
  final FocusNode _focus = FocusNode(debugLabel: 'extra arguments');

  @override
  void didUpdateWidget(ExtraArgumentsField old) {
    super.didUpdateWidget(old);
    // Reset, Revert or another preset: show the new value unless it is being typed.
    if (widget.value != _text.text && (!_focus.hasFocus || widget.value != old.value)) _text.text = widget.value;
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VeField(
      label: 'Extra arguments',
      modified: widget.modified,
      onReset: widget.onReset,
      messages: widget.messages,
      blurb: const Text(
        'For anything without a control here. An option typed here replaces the generated one of the same name.',
      ),
      child: VeTextField(
        controller: _text,
        focusNode: _focus,
        mono: true,
        placeholder: widget.kind == 'video' ? 'Such as -bf 3' : 'Such as -cutoff 18000',
        semanticLabel: 'Extra ${widget.kind} arguments',
        onChanged: widget.onChanged,
      ),
    );
  }
}
