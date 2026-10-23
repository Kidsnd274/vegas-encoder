import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../../../design/components/button.dart';
import '../../../design/components/dialog.dart';
import '../../../design/components/field.dart';
import '../../../design/components/interactive.dart';
import '../../../design/components/message.dart';
import '../../../design/components/popover.dart';
import '../../../design/components/select.dart';
import '../../../design/components/switch.dart';
import '../../../design/components/text_field.dart';
import '../../../design/icons.dart';
import '../../../design/tokens.dart';
import '../../../state/editor.dart';
import '../../../state/services.dart';
import '../../../state/ui_state.dart';
import '../display.dart';
import 'field_anchor.dart';
import 'panel_kit.dart';

const _algorithms = [
  VeOption('bicubic', 'Bicubic'),
  VeOption('bilinear', 'Bilinear'),
  VeOption('lanczos', 'Lanczos'),
  VeOption('neighbor', 'Nearest neighbour'),
];

String _algorithmName(String id) => _algorithms.where((a) => a.value == id).firstOrNull?.label ?? id;

List<VeOption<String>> _algorithmChoices(CoreCapabilities? capabilities) {
  final scale = capabilities?.filters['scale'];
  if (scale is! Map || scale['algorithms'] is! List) return _algorithms;
  final reported = (scale['algorithms'] as List).whereType<String>().toSet();
  return [
    for (final choice in _algorithms)
      VeOption(
        choice.value,
        choice.label,
        detail: reported.contains(choice.value) ? null : 'Not reported by the selected FFmpeg',
      ),
  ];
}

/// Basic's ordered, curated filter list. The core decides which chain is
/// effective; handwritten filters are never parsed or merged by the app.
class FiltersPanel extends ConsumerWidget {
  const FiltersPanel({super.key, required this.scope});
  final PanelScope scope;

  void _replace(VideoFilter? filter) => scope.edit(
    (recipe) => filter == null && recipe.schema == 1
        ? recipe
        : recipe.copyWith(
            schema: filter != null ? 2 : recipe.schema,
            video: recipe.video.copyWith(filters: filter == null ? <VideoFilter>[] : [filter]),
          ),
  );

  Future<void> _edit(BuildContext context, VeCore core, VideoFilter? initial) async {
    final choice = await showVeDialog<_ResizeChoice>(
      context,
      title: 'Resize / Upscale',
      width: 490,
      content: _ResizeEditor(scope: scope, core: core, initial: initial),
      actions: const [],
    );
    if (choice != null && context.mounted) _replace(choice.filter);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final expanded = ref.watch(videoFiltersExpandedProvider);
    final filter = scope.recipe.video.filters.firstOrNull;
    final control = scope.data.compiled.value?.filterControl;
    final extra = control == 'extra';
    final inactive = extra || scope.data.advanced;
    final summary = extra
        ? 'Set in Extra arguments'
        : filter == null
        ? 'None'
        : !filter.enabled
        ? 'None · 1 disabled'
        : 'Resize to ${filter.width} × ${filter.height} · ${_algorithmName(filter.algorithm)}';
    final core = ref.watch(veCoreProvider);
    final realMedia = scope.data.preview == PreviewMedia.project ? scope.data.media : null;
    final checked = CoreResult.run(
      () => core.validate(scope.recipe, media: realMedia, capabilities: scope.data.capabilities),
    );
    final issues = checked.value?.where((i) => i.field.startsWith('video.filters')) ?? const <Issue>[];
    return FieldAnchor(
      fields: const [
        'video.filters',
        'video.filters[0]',
        'video.filters[0].width',
        'video.filters[0].height',
        'video.filters[0].algorithm',
        'video.filters[0].enabled',
        'video.filters[0].backend',
        'video.filters[0].fit',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The same disclosure row as the popup's "Library and command".
          Semantics(
            button: true,
            expanded: expanded,
            label: 'Video filters. $summary',
            excludeSemantics: true,
            child: VeInteractive(
              onTap: () => unawaited(ref.read(videoFiltersExpandedProvider.notifier).set(!expanded)),
              cursor: SystemMouseCursors.click,
              builder: (context, s) => VeFocusRing(
                visible: s.focused,
                child: Row(
                  children: [
                    VeIcon(expanded ? VeIcons.chevronDown : VeIcons.chevronRight, color: c.ink),
                    const SizedBox(width: 4),
                    Text('Filters', style: t.text.label),
                    const SizedBox(width: 10),
                    // Open, the entry below says the same thing.
                    Expanded(
                      child: expanded
                          ? const SizedBox.shrink()
                          : Text(
                              summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.text.small.copyWith(color: c.muted),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            if (extra) ...[
              const VeMessage(
                level: VeLevel.info,
                text:
                    'Filters set in Extra arguments. Remove the handwritten video filter to use these controls. '
                    'Your structured filter settings are retained.',
              ),
              const SizedBox(height: 10),
            ],
            if (filter == null)
              Row(
                children: [
                  VePopover(
                    width: 260,
                    anchorBuilder: (context, open, toggle) => VeButton(
                      label: 'Add filter',
                      size: VeButtonSize.small,
                      trailingIcon: VeIcons.chevronDown,
                      onPressed: inactive ? null : toggle,
                      tooltip: extra ? 'Filters set in Extra arguments' : null,
                    ),
                    contentBuilder: (menuContext, close) => VeListbox<String>(
                      groups: const [
                        VeOptionGroup([VeOption('resize', 'Resize / Upscale')]),
                      ],
                      selected: null,
                      semanticLabel: 'Add video filter',
                      onClose: close,
                      onPick: (_) => unawaited(_edit(context, core, null)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: PanelBlurb('The output stays the size VEGAS delivers.')),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                decoration: BoxDecoration(
                  border: Border.all(color: c.line),
                  borderRadius: BorderRadius.circular(VeRadius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VeSwitch(
                            label: 'Resize / Upscale',
                            small: true,
                            value: filter.enabled,
                            onChanged: inactive ? null : (v) => _replace(filter.copyWith(enabled: v)),
                          ),
                          // Lined up with the switch's label.
                          Padding(
                            padding: const EdgeInsets.only(left: 41, top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PanelBlurb(
                                  '${filter.width} × ${filter.height} · Fit with padding · '
                                  '${_algorithmName(filter.algorithm)}${filter.enabled ? '' : ' · Disabled'}',
                                ),
                                if (!inactive && filter.enabled)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: _GeometryFacts(
                                      data: scope.data,
                                      geometry: scope.data.compiled.value?.videoGeometry,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    VeButton(
                      label: 'Edit',
                      semanticLabel: 'Edit resize filter',
                      size: VeButtonSize.small,
                      onPressed: inactive ? null : () => unawaited(_edit(context, core, filter)),
                    ),
                    const SizedBox(width: 4),
                    VeButton(
                      label: 'Remove',
                      semanticLabel: 'Remove resize filter',
                      size: VeButtonSize.small,
                      variant: VeButtonVariant.ghost,
                      onPressed: inactive ? null : () => _replace(null),
                    ),
                  ],
                ),
              ),
            for (final issue in issues)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: VeMessage(level: levelOf(issue.level), text: issue.message, fix: issue.fix),
              ),
          ],
        ],
      ),
    );
  }
}

/// Source-dependent information is only shown for actual supplied project
/// facts. The command's sample compile is never presented as VEGAS's input.
class _GeometryFacts extends StatelessWidget {
  const _GeometryFacts({required this.data, required this.geometry});
  final EditorData data;
  final VideoGeometry? geometry;

  @override
  Widget build(BuildContext context) {
    if (data.preview != PreviewMedia.project) {
      return const PanelBlurb(
        'Input size is set by VEGAS. Padding is determined from the delivered frames at render time.',
      );
    }
    final g = geometry;
    if (g == null || g.inputWidth == null || g.inputHeight == null) {
      return const PanelBlurb('Input size is set by VEGAS.');
    }
    if (g.width == null || g.height == null) {
      return PanelBlurb('From VEGAS: ${g.inputWidth} × ${g.inputHeight}. Output geometry is not determined.');
    }
    final direction = switch (g.direction) {
      'upscale' => 'Upscaling',
      'downscale' => 'Downscaling',
      'unchanged' => 'Unchanged size',
      'mixed' => 'Resizing',
      _ => 'Resizing',
    };
    return PanelFacts([
      ('From VEGAS → Encoded output', '${g.inputWidth} × ${g.inputHeight} → ${g.width} × ${g.height}'),
      ('Processing', '$direction · Square output pixels'),
      if (g.contentWidth != null && g.contentHeight != null)
        (
          'Picture',
          '${g.contentWidth} × ${g.contentHeight}${g.rounded == true ? ' · Rounded for chroma alignment' : ''}',
        ),
      if (g.padLeft != null && g.padTop != null && g.padRight != null && g.padBottom != null)
        ('Black padding', 'Left ${g.padLeft}, top ${g.padTop}, right ${g.padRight}, bottom ${g.padBottom} px'),
    ]);
  }
}

class _ResizeChoice {
  const _ResizeChoice(this.filter);
  final VideoFilter? filter;
}

class _ResizeEditor extends StatefulWidget {
  const _ResizeEditor({required this.scope, required this.core, required this.initial});
  final PanelScope scope;
  final VeCore core;
  final VideoFilter? initial;

  @override
  State<_ResizeEditor> createState() => _ResizeEditorState();
}

class _ResizeEditorState extends State<_ResizeEditor> {
  static const _sizes = <String, (int, int)>{
    '720p': (1280, 720),
    '1080p': (1920, 1080),
    '1440p': (2560, 1440),
    '2160p': (3840, 2160),
  };
  late String _size = widget.initial == null
      ? 'source'
      : _sizes.entries.where((e) => e.value == (widget.initial!.width, widget.initial!.height)).firstOrNull?.key ??
            'custom';
  late int? _width = widget.initial?.width ?? 1920;
  late int? _height = widget.initial?.height ?? 1080;
  late String _algorithm = widget.initial?.algorithm ?? 'bicubic';

  @override
  Widget build(BuildContext context) {
    final source = _size == 'source';
    final filter = source
        ? null
        : VideoFilter(
            width: _width ?? 0,
            height: _height ?? 0,
            algorithm: _algorithm,
            enabled: widget.initial?.enabled ?? true,
          );
    final recipe = source && widget.scope.recipe.schema == 1
        ? widget.scope.recipe
        : widget.scope.recipe.copyWith(
            schema: filter == null ? widget.scope.recipe.schema : 2,
            video: widget.scope.recipe.video.copyWith(filters: filter == null ? <VideoFilter>[] : [filter]),
          );
    final realMedia = widget.scope.data.preview == PreviewMedia.project ? widget.scope.data.media : null;
    final checked = CoreResult.run(() => widget.core.validate(recipe, media: realMedia));
    final ownIssues = checked.value?.where((i) => i.field.startsWith('video.filters')).toList() ?? const <Issue>[];
    final ownErrors = ownIssues.any((i) => i.level == IssueLevel.error);
    final presented = CoreResult.run(
      () => widget.core.validate(recipe, media: realMedia, capabilities: widget.scope.data.capabilities),
    );
    final compiled = realMedia == null
        ? null
        : CoreResult.run(
            () => widget.core.compile(
              recipe,
              media: realMedia,
              paths: widget.scope.data.paths,
              capabilities: widget.scope.data.capabilities,
            ),
          );
    final shown = <String>{};
    final issues = [
      ...ownIssues.where((i) => i.level == IssueLevel.error),
      ...?presented.value?.where((i) => i.field.startsWith('video.filters')),
    ].where((i) => shown.add('${i.id}|${i.message}')).toList();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height - 150),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const PanelBlurb('Resizing happens after VEGAS supplies the frames. It does not change the project.'),
            const SizedBox(height: 16),
            VeField(
              label: 'Output resolution',
              child: VeSelect<String>(
                semanticLabel: 'Resize output resolution',
                value: _size,
                options: const [
                  VeOption('source', 'Same as input from VEGAS'),
                  VeOption('720p', '1280 × 720 · HD'),
                  VeOption('1080p', '1920 × 1080 · Full HD'),
                  VeOption('1440p', '2560 × 1440 · QHD'),
                  VeOption('2160p', '3840 × 2160 · UHD (not DCI 4K)'),
                  VeOption('custom', 'Custom width and height'),
                ],
                onChanged: (value) => setState(() {
                  _size = value;
                  if (_sizes[value] case final size?) {
                    _width = size.$1;
                    _height = size.$2;
                  }
                }),
              ),
            ),
            if (!source) ...[
              const SizedBox(height: 16),
              if (_size == 'custom') ...[
                PanelRow(
                  children: [
                    VeField(
                      label: 'Width',
                      child: VeNumberField(
                        value: _width,
                        semanticLabel: 'Resize width',
                        unit: 'px',
                        onChanged: (value) => setState(() => _width = value?.toInt()),
                      ),
                    ),
                    VeField(
                      label: 'Height',
                      child: VeNumberField(
                        value: _height,
                        semanticLabel: 'Resize height',
                        unit: 'px',
                        onChanged: (value) => setState(() => _height = value?.toInt()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              VeField(
                label: 'Scaling algorithm',
                child: VeSelect<String>(
                  semanticLabel: 'Resize scaling algorithm',
                  value: _algorithm,
                  options: _algorithmChoices(widget.scope.data.capabilities),
                  onChanged: (value) => setState(() => _algorithm = value),
                ),
              ),
              const SizedBox(height: 14),
              PanelFacts([
                ('Encoded output', '${_width ?? '—'} × ${_height ?? '—'}'),
                ('Aspect ratio', 'Fit with centered black padding'),
                ('Backend', 'FFmpeg software scale'),
              ]),
              _GeometryFacts(data: widget.scope.data, geometry: compiled?.value?.videoGeometry),
            ],
            for (final issue in issues)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: VeMessage(level: levelOf(issue.level), text: issue.message, fix: issue.fix),
              ),
            if (checked.error != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: VeMessage(level: VeLevel.error, text: 'The core could not check these filter settings.'),
              ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.initial != null)
                  VeButton(
                    label: 'Reset resizing',
                    variant: VeButtonVariant.ghost,
                    onPressed: () => setState(() => _size = 'source'),
                  ),
                VeButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
                VeButton(
                  label: 'Apply',
                  variant: VeButtonVariant.primary,
                  autofocus: true,
                  onPressed: checked.error != null || ownErrors
                      ? null
                      : () => Navigator.of(context).pop(_ResizeChoice(filter)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
