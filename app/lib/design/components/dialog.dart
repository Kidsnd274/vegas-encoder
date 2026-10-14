import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'button.dart';
import 'text_field.dart';

/// One button in a [showVeDialog]. The last action is the default and has
/// focus when the dialog opens. A disabled action says why in [tooltip].
@immutable
class VeDialogAction<T> {
  const VeDialogAction(
    this.label,
    this.value, {
    this.variant = VeButtonVariant.secondary,
    this.enabled = true,
    this.tooltip,
  });
  final String label;
  final T value;
  final VeButtonVariant variant;
  final bool enabled;
  final String? tooltip;
}

/// A small modal question (UI_SPEC §2: "Save changes to 'name'?"). Esc and
/// a click outside return null, which callers treat as Cancel.
Future<T?> showVeDialog<T>(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  required List<VeDialogAction<T>> actions,
  double width = 440,
}) {
  final t = VeTokens.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: t.shadow(t.brightness == Brightness.dark ? 0.5 : 0.28),
    transitionDuration: VeTokens.motion(context, VeDurations.short),
    pageBuilder: (dialogContext, _, _) =>
        _VeDialog<T>(title: title, message: message, content: content, actions: actions, width: width),
    transitionBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
  );
}

class _VeDialog<T> extends StatelessWidget {
  const _VeDialog({required this.title, required this.actions, required this.width, this.message, this.content});
  final double width;
  final String title;
  final String? message;
  final Widget? content;
  final List<VeDialogAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Center(
      child: Shortcuts(
        shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
        child: Actions(
          actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => Navigator.of(context).pop())},
          child: FocusScope(
            autofocus: true,
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: title,
              child: Container(
                width: width,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
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
                      Text(title, style: t.text.panelTitle),
                      if (message != null) ...[
                        const SizedBox(height: 8),
                        Text(message!, style: t.text.body.copyWith(color: c.text2)),
                      ],
                      if (content != null) ...[const SizedBox(height: 12), content!],
                      const SizedBox(height: 18),
                      // Long labels wrap to a second row, still right-aligned.
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < actions.length; i++)
                            VeButton(
                              label: actions[i].label,
                              variant: actions[i].variant,
                              autofocus: i == actions.length - 1 && actions[i].enabled,
                              tooltip: actions[i].tooltip,
                              onPressed: actions[i].enabled ? () => Navigator.of(context).pop(actions[i].value) : null,
                            ),
                        ],
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

/// Asks for a name (Rename…). Returns the trimmed text, or null on Cancel.
Future<String?> showVeTextDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String initial,
  required String confirmLabel,
}) async {
  final typed = _Typed(initial);
  final result = await showVeDialog<bool>(
    context,
    title: title,
    content: _NameField(typed: typed, label: label),
    actions: [
      const VeDialogAction('Cancel', false),
      VeDialogAction(confirmLabel, true, variant: VeButtonVariant.primary),
    ],
  );
  final text = typed.text.trim();
  return result == true && text.isNotEmpty ? text : null;
}

/// The text typed in a [showVeTextDialog]. The field owns its controller, so
/// the controller lives as long as the dialog's closing transition.
class _Typed {
  _Typed(this.text);
  String text;
}

class _NameField extends StatefulWidget {
  const _NameField({required this.typed, required this.label});
  final _Typed typed;
  final String label;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  final FocusNode _focus = FocusNode(debugLabel: 'dialog name');
  late final TextEditingController _text = TextEditingController(text: widget.typed.text)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.typed.text.length);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: t.text.label),
        const SizedBox(height: 6),
        VeTextField(
          controller: _text,
          focusNode: _focus,
          semanticLabel: widget.label,
          onChanged: (v) => widget.typed.text = v,
          onSubmitted: (_) => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
