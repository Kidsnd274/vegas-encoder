import 'package:flutter/widgets.dart';

import '../../design/components/button.dart';
import '../../design/components/popover.dart';
import '../../design/components/segmented.dart';
import '../../design/components/select.dart';
import '../../design/format.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/editor.dart';
import 'display.dart';

enum EditorMode { basic, advanced }

/// The editor's header (`.head`): the preset's name and state, Basic or
/// Advanced, the FFmpeg the checks are for, Duplicate and Save.
class PresetHeader extends StatelessWidget {
  const PresetHeader({
    super.key,
    required this.data,
    required this.onMode,
    required this.onInstallation,
    required this.onDuplicate,
    required this.onRevert,
    required this.onSave,
  });

  final EditorData data;
  final ValueChanged<EditorMode> onMode;
  final ValueChanged<String> onInstallation;
  final VoidCallback onDuplicate;
  final VoidCallback onRevert;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final p = data.preset;
    final builtin = p.builtin;
    final updated = DateTime.tryParse(p.updatedAt);
    final mode = data.recipe.command.mode == 'template' ? EditorMode.advanced : EditorMode.basic;
    const builtinNote = 'Built-in presets can’t be changed. Your changes will be saved as a new preset.';

    return Container(
      // 62 px at 100% text; taller when Windows text is larger.
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.fromLTRB(22, 6, 16, 6),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          // The name keeps its room: the built-in note sits at the right only
          // in a wide header, and in the meta line otherwise.
          final roomy = box.maxWidth >= 1080;
          final wide = box.maxWidth >= 1400;
          final noteInMeta = data.dirty && builtin && !wide;
          return Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Semantics(
                            header: true,
                            child: Text(
                              data.recipe.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.text.pageTitle,
                            ),
                          ),
                        ),
                        if (data.dirty) ...[const SizedBox(width: 10), const _EditedPill()],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        builtin ? 'Built-in' : 'Mine',
                        if (noteInMeta)
                          'Your changes will be saved as a new preset.'
                        else ...[
                          categoryLabel(data.recipe.category),
                          'Revision ${p.revision}${updated == null ? '' : ', updated ${VeFormat.date(updated)}'}',
                        ],
                      ].join('   '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.text.small.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              if (data.dirty && builtin && wide) ...[
                const SizedBox(width: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 250),
                  child: Text(
                    builtinNote,
                    textAlign: TextAlign.right,
                    style: t.text.small.copyWith(color: c.muted, height: 1.3),
                  ),
                ),
              ],
              const SizedBox(width: 14),
              VeSegmented<EditorMode>(
                semanticLabel: 'Editing mode',
                segments: const [VeSegment(EditorMode.basic, 'Basic'), VeSegment(EditorMode.advanced, 'Advanced')],
                selected: mode,
                onChanged: onMode,
              ),
              const SizedBox(width: 10),
              Container(width: 1, height: 24, color: c.line),
              const SizedBox(width: 10),
              if (roomy) ...[Text('FFmpeg', style: t.text.small.copyWith(color: c.muted)), const SizedBox(width: 8)],
              VeSelect<String>(
                semanticLabel: 'FFmpeg for checks',
                width: roomy ? 200 : 170,
                value: data.installation?.id,
                options: [
                  for (final i in data.installations)
                    VeOption(i.id, i.id == data.defaultInstallationId ? '${i.label} (default)' : i.label),
                ],
                onChanged: onInstallation,
              ),
              const SizedBox(width: 10),
              VeButton(
                label: 'Duplicate',
                icon: VeIcons.layers,
                tooltip: 'Copy this preset into Mine',
                onPressed: onDuplicate,
              ),
              if (data.dirty) ...[
                const SizedBox(width: 8),
                VeButton(
                  label: 'Revert',
                  variant: VeButtonVariant.ghost,
                  tooltip: 'Discard the changes to this preset',
                  onPressed: onRevert,
                ),
              ],
              const SizedBox(width: 8),
              VeButton(
                label: builtin ? 'Save as new preset' : 'Save preset',
                icon: VeIcons.save,
                variant: VeButtonVariant.primary,
                tooltip: data.dirty ? (builtin ? builtinNote : 'Save (Ctrl+S)') : 'No changes to save',
                onPressed: data.dirty ? onSave : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EditedPill extends StatelessWidget {
  const _EditedPill();

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(color: t.colors.ink, borderRadius: BorderRadius.circular(10)),
      child: Text(
        'Edited',
        style: t.text.caption.copyWith(color: t.colors.onInk, fontWeight: const FontWeight(600)),
      ),
    );
  }
}
