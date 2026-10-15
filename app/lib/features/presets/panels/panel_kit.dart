import 'package:flutter/widgets.dart';
import 'package:ve_services/ve_services.dart';

import '../../../design/components/message.dart';
import '../../../design/components/signal_path/signal_path_model.dart';
import '../../../design/tokens.dart';
import '../../../state/editor.dart';
import '../../../state/recipe_edit.dart';
import '../display.dart';

/// What a node panel needs: the editor data, edits, and per-field state.
class PanelScope {
  PanelScope(this.data, this.controller);
  final EditorData data;
  final RecipeEditor controller;

  Recipe get recipe => data.recipe;
  Recipe get saved => data.saved;
  ProfileCatalog get catalog => data.catalog;
  ResolvedSettings? get resolved => data.compiled.value?.resolved;

  void edit(Recipe Function(Recipe r) change) => controller.edit(change);

  /// Changed from the saved preset: the field shows a dot and a Reset.
  bool modified(String path) => fieldDiffers(recipe, saved, path);
  VoidCallback? reset(String path) => modified(path) ? () => edit((r) => resetField(r, saved, path)) : null;

  /// Extra arguments replaced the option this control generates (C2
  /// `overriddenFields`), so its value isn't in the command.
  bool overridden(Iterable<String> fields) => fields.any(data.overriddenFields.contains);

  /// The control's messages: "Set in Extra arguments" when they replaced its
  /// option, then the core's issues for its fields (`field` in each issue).
  List<VeMessage> messages(Iterable<String> fields) => [
    if (overridden(fields)) const VeMessage(level: VeLevel.info, text: setInExtraArguments),
    for (final f in fields)
      for (final i in data.issuesFor(f)) VeMessage(level: levelOf(i.level), text: i.message, fix: i.fix),
  ];
}

/// `.ip-h`: the node's name and what it does.
class NodePanelHeader extends StatelessWidget {
  const NodePanelHeader({super.key, required this.node});
  final SignalNode node;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final (title, sub, color) = switch (node) {
      SignalNode.source => ('From VEGAS', 'What the project delivers', c.faint),
      SignalNode.video => ('Video encoder', 'Encodes the frames', c.videoWire),
      SignalNode.audio => ('Audio encoder', 'Encodes the samples', c.audioWire),
      SignalNode.container => ('Container', 'Joins the streams into one file', c.containerWire),
      SignalNode.file => ('File', 'Where the render goes, and how big it will be', c.containerWire),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Semantics(header: true, child: Text(title, style: t.text.panelTitle)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(sub, style: t.text.small.copyWith(color: c.muted)),
        ),
      ],
    );
  }
}

/// `.cols`: the panel's two columns.
class PanelColumns extends StatelessWidget {
  const PanelColumns({super.key, required this.left, required this.right, this.gap = VeSpace.s4});
  final List<Widget> left;
  final List<Widget> right;
  final double gap;

  @override
  Widget build(BuildContext context) {
    Widget column(List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[if (i > 0) SizedBox(height: gap), items[i]],
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(left)),
        const SizedBox(width: 28),
        Expanded(child: column(right)),
      ],
    );
  }
}

/// `.row2`/`.row3`: controls side by side within a column.
class PanelRow extends StatelessWidget {
  const PanelRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: children[i])],
    ],
  );
}

/// `.more`: the Extra arguments area under a stream's controls.
class PanelMore extends StatelessWidget {
  const PanelMore({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = VeTokens.of(context).colors;
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: child,
    );
  }
}

/// `.static`: a plain sentence where a control would be.
class PanelStatic extends StatelessWidget {
  const PanelStatic(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: VeTokens.of(context).text.body);
}

/// `.blurb`: muted explanation under a control.
class PanelBlurb extends StatelessWidget {
  const PanelBlurb(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Text(text, style: t.text.small.copyWith(color: t.colors.muted, height: 1.4));
  }
}

/// `.facts`: a definition list.
class PanelFacts extends StatelessWidget {
  const PanelFacts(this.facts, {super.key});
  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      children: [
        for (final (k, v) in facts)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 6),
                child: Text(k, style: t.text.body.copyWith(color: t.colors.muted)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(v, style: t.text.body),
              ),
            ],
          ),
      ],
    );
  }
}
