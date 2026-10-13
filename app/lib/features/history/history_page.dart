import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/page_header.dart';
import '../../design/tokens.dart';
import '../../state/app_state.dart';
import '../../state/history.dart';
import '../../state/presets.dart';
import '../../state/services.dart';
import 'display.dart';
import 'job_detail.dart';
import 'job_list.dart';

/// History (S5, UI_SPEC §6): renders Vegas Encoder made in VEGAS, read from
/// the job records (C6). The list at the left, the selected render's detail
/// at the right, in the FFmpeg screen's layout.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> with VeToastHost {
  final Map<String, FocusNode> _rows = {};

  FocusNode _rowFocus(String id) => _rows.putIfAbsent(id, () => FocusNode(debugLabel: 'job $id'));

  @override
  void dispose() {
    for (final n in _rows.values) {
      n.dispose();
    }
    super.dispose();
  }

  JobRecord? get _selectedRecord {
    final id = ref.read(historyViewProvider).value?.selectedId;
    return id == null ? null : ref.read(jobRecordProvider(id)).value;
  }

  Future<void> _copy(String text, String toast) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showToast(toast);
  }

  void _copyCommand(JobRecord record) => unawaited(_copy(commandLine(record), 'Command copied'));

  /// "Open settings as new preset": a preset in Mine with the settings this
  /// render used, opened in Presets.
  Future<void> _openAsPreset(JobRecord record) async {
    final created = await ref
        .read(presetsControllerProvider.notifier)
        .createFromRecipe(record.recipe, name: record.templateName);
    if (!mounted || created == null) return;
    ref.read(desktopSectionProvider.notifier).go(DesktopSection.presets);
  }

  /// Up and Down in the list move the selection and keyboard focus with it.
  void _move(int delta) {
    final view = ref.read(historyViewProvider).value;
    if (view == null || view.shown.isEmpty) return;
    final at = view.shown.indexWhere((e) => e.id == view.selectedId);
    final next = view.shown[(at + delta).clamp(0, view.shown.length - 1)].id;
    ref.read(historyControllerProvider.notifier).select(next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final node = _rows[next];
      if (!mounted || node == null || node.context == null) return;
      node.requestFocus();
      unawaited(
        Scrollable.ensureVisible(
          node.context!,
          alignmentPolicy: delta > 0
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(historyViewProvider);
    final filter = ref.watch(historyControllerProvider.select((s) => s.filter));
    final controller = ref.read(historyControllerProvider.notifier);

    final Widget body = switch (view) {
      AsyncValue(value: final v?) when v.all.isEmpty => const _NoRenders(),
      AsyncValue(value: final v?) => LayoutBuilder(
        builder: (context, box) {
          final detailWidth = box.maxWidth >= 1280 ? 450.0 : 380.0;
          final selected = v.shown.where((e) => e.id == v.selectedId).firstOrNull;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: JobList(
                  all: v.all,
                  shown: v.shown,
                  selectedId: v.selectedId,
                  filter: filter,
                  onFilter: controller.setFilter,
                  onSelect: controller.select,
                  onMove: _move,
                  focusFor: _rowFocus,
                ),
              ),
              SizedBox(
                width: detailWidth,
                child: JobDetail(
                  entry: selected,
                  onCopy: _copy,
                  onCopyCommand: _copyCommand,
                  onOpenAsPreset: (r) => unawaited(_openAsPreset(r)),
                ),
              ),
            ],
          );
        },
      ),
      AsyncError(:final error) => _Centered('The render history couldn’t be read: $error'),
      _ => const SizedBox.shrink(),
    };

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true): () {
          if (_selectedRecord case final r?) _copyCommand(r);
        },
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const VePageHeader(
                  title: 'History',
                  description:
                      'Renders made with Vegas Encoder in VEGAS: how each one ended, the FFmpeg and command that ran, '
                      'and what FFmpeg said.',
                ),
                Expanded(child: body),
              ],
            ),
            toastLayer(),
          ],
        ),
      ),
    );
  }
}

class _NoRenders extends StatelessWidget {
  const _NoRenders();

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return ColoredBox(
      color: t.colors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No renders yet.', style: t.text.panelTitle),
            const SizedBox(height: 6),
            Text(
              'Renders made with Vegas Encoder in VEGAS appear here.',
              style: t.text.body.copyWith(color: t.colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return ColoredBox(
      color: t.colors.surface,
      child: Center(
        child: Text(text, style: t.text.body.copyWith(color: t.colors.text2)),
      ),
    );
  }
}
