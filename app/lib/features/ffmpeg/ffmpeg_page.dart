import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/button.dart';
import '../../design/components/dialog.dart';
import '../../design/components/page_header.dart';
import '../../design/components/segmented.dart';
import '../../design/components/signal_path/signal_path.dart' show VeDotGridPainter;
import '../../design/components/status.dart';
import '../../design/components/text_field.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/app_state.dart';
import '../../state/ffmpeg.dart';
import '../../state/presets.dart';
import '../../state/services.dart';
import 'capability_table.dart';
import 'display.dart';
import 'encoder_detail.dart';
import 'installation_card.dart';

/// The FFmpeg screen (S4, UI_SPEC §5): the installations Vegas Encoder knows,
/// which one renders, and what each can encode on this PC and why not.
class FFmpegPage extends ConsumerStatefulWidget {
  const FFmpegPage({super.key});

  @override
  ConsumerState<FFmpegPage> createState() => _FFmpegPageState();
}

class _FFmpegPageState extends ConsumerState<FFmpegPage> with VeToastHost {
  final FocusNode _search = FocusNode(debugLabel: 'encoder search');
  late final TextEditingController _query;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: ref.read(ffmpegControllerProvider).query);
  }

  FFmpegController get _controller => ref.read(ffmpegControllerProvider.notifier);

  @override
  void dispose() {
    _search.dispose();
    _query.dispose();
    super.dispose();
  }

  /// Runs [action]; a service failure shows as a toast instead of escaping.
  Future<void> _guard(Future<void> Function() action, {required String failure}) async {
    try {
      await action();
    } on ServiceException catch (e) {
      if (mounted) showToast('$failure: ${e.message}');
    }
  }

  Future<void> _add() async {
    final path = await ref
        .read(windowControllerProvider)
        .pickFile(title: 'Choose ffmpeg.exe', filterName: 'FFmpeg', filterPattern: 'ffmpeg.exe');
    if (path == null || !mounted) return;
    await _guard(() async {
      final added = await _controller.add(path);
      if (mounted) showToast('Added ${added.label}');
    }, failure: 'Couldn’t add $path');
  }

  Future<void> _scan() => _guard(() async {
    final found = await _controller.scan();
    if (mounted) {
      showToast('Scanned again. Found ${found.length} ${found.length == 1 ? 'installation' : 'installations'}.');
    }
  }, failure: 'Couldn’t scan');

  Future<void> _test(FFmpegInstallation installation, {String? encoder}) => _guard(() async {
    final catalog = ref.read(profilesProvider);
    final status = statusLookup(installation, ref.read(ffmpegControllerProvider));
    final names = encoder == null
        ? [
            for (final id in hardwareEncoderIds(catalog))
              if (status(id).state != VeAvailability.missing) id,
          ]
        : [encoder];
    await _controller.testHardware(installation, hardwareEncoders: names, encoders: encoder == null ? null : names);
    if (!mounted) return;
    final results = ref.read(ffmpegControllerProvider).testResults[installation.id] ?? const {};
    final done = [for (final id in names) ?results[id]];
    final failed = done.where((r) => r.state != 'ok').length;
    showToast(
      encoder != null
          ? '${encoderLabel(catalog, encoder)}: ${failed == 0 ? 'the test encode passed' : 'the test encode failed'}'
          : 'Hardware tests finished: ${done.length - failed} ready, $failed failed',
    );
  }, failure: 'Couldn’t test');

  Future<void> _setDefault(FFmpegInstallation installation) => _guard(() async {
    await _controller.setDefault(installation);
    if (mounted) showToast('${installation.label} is now the default. The next render uses it.');
  }, failure: 'Couldn’t change the default');

  Future<void> _remove(FFmpegInstallation installation) async {
    final ok = await showVeDialog<bool>(
      context,
      title: 'Remove ${installation.label}?',
      message:
          'Vegas Encoder forgets it. The files stay in ${installation.path}. Scan again finds it if it is on PATH '
          'or installed with a package manager.',
      actions: const [
        VeDialogAction('Cancel', false),
        VeDialogAction('Remove', true, variant: VeButtonVariant.primary),
      ],
    );
    if (ok != true || !mounted) return;
    await _guard(() async {
      await _controller.remove(installation.id);
      if (mounted) showToast('Removed ${installation.label}');
    }, failure: 'Couldn’t remove ${installation.label}');
  }

  void _copyPath(FFmpegInstallation installation) {
    unawaited(Clipboard.setData(ClipboardData(text: installation.path)));
    showToast('Path copied');
  }

  void _openPreset(String id) {
    ref.read(presetsControllerProvider.notifier).select(id);
    ref.read(desktopSectionProvider.notifier).go(DesktopSection.presets);
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final state = ref.watch(ffmpegControllerProvider);
    final found = ref.watch(discoveredInstallationsProvider);
    final installations = found.value ?? const <FFmpegInstallation>[];
    final defaultId = ref.watch(machineSettingsProvider.select((s) => s.value?.defaultFFmpegId));
    final catalog = ref.watch(profilesProvider);
    final presets = ref.watch(presetsProvider).value ?? const <Preset>[];
    final selected =
        installations.where((i) => i.id == state.selectedId).firstOrNull ??
        installations.where((i) => i.id == defaultId).firstOrNull ??
        installations.firstOrNull;
    final testing = selected != null && (state.testing[selected.id]?.isNotEmpty ?? false);

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.keyF, control: true): _search.requestFocus},
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VePageHeader(
                title: 'FFmpeg',
                description:
                    'Vegas Encoder renders with the default FFmpeg. Each installation is checked once: its own '
                    'encoder list, then a short test encode on this PC for each hardware encoder.',
                actions: [
                  VeButton(label: 'Add FFmpeg…', icon: VeIcons.plus, onPressed: _add),
                  VeButton(
                    label: state.scanning ? 'Scanning…' : 'Scan again',
                    icon: VeIcons.refresh,
                    onPressed: state.scanning ? null : _scan,
                  ),
                  VeButton(
                    label: testing ? 'Testing…' : 'Test hardware encoders',
                    icon: VeIcons.flask,
                    variant: VeButtonVariant.primary,
                    onPressed: selected == null || testing ? null : () => _test(selected),
                  ),
                ],
              ),
              _CardStrip(
                // hasError, not AsyncError: Riverpod 3 retries a failed
                // provider, and while it does the value is loading with the error.
                empty: found.hasError
                    ? 'The installations couldn’t be read: ${found.error}'
                    : 'No FFmpeg found on this PC. Vegas Encoder needs ffmpeg.exe with ffprobe.exe beside it. '
                          'Choose Add FFmpeg… if it is somewhere Scan again doesn’t look.',
                children: [
                  for (final i in installations)
                    InstallationCard(
                      key: ValueKey(i.id),
                      model: installationCard(
                        i,
                        isDefault: i.id == defaultId,
                        state: state,
                        presets: presets,
                        catalog: catalog,
                      ),
                      selected: i.id == selected?.id,
                      onSelect: () => _controller.select(i.id),
                      onSetDefault: () => _setDefault(i),
                      onCopyPath: () => _copyPath(i),
                      onRemove: () => _remove(i),
                    ),
                ],
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(top: BorderSide(color: c.line)),
                  ),
                  child: selected == null
                      ? const SizedBox.shrink()
                      : _Capabilities(
                          installation: selected,
                          state: state,
                          catalog: catalog,
                          presets: presets,
                          query: _query,
                          searchFocus: _search,
                          onTest: (encoder) => _test(selected, encoder: encoder),
                          onOpenPreset: _openPreset,
                        ),
                ),
              ),
            ],
          ),
          toastLayer(),
        ],
      ),
    );
  }
}

/// `.insts`: the installation cards on dotted paper, three across; more
/// scroll sideways.
class _CardStrip extends StatelessWidget {
  const _CardStrip({required this.children, required this.empty});
  final List<Widget> children;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return CustomPaint(
      painter: VeDotGridPainter(t.colors),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        child: children.isEmpty
            ? Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: t.colors.surface,
                  border: Border.all(color: t.colors.line2),
                  borderRadius: BorderRadius.circular(VeRadius.xl),
                ),
                child: Text(empty, style: t.text.body.copyWith(color: t.colors.text2)),
              )
            : LayoutBuilder(
                builder: (context, box) {
                  const gap = 14.0;
                  final across = children.length.clamp(1, 3);
                  final width = ((box.maxWidth - gap * (across - 1)) / across).clamp(300.0, double.infinity);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < children.length; i++) ...[
                            if (i > 0) const SizedBox(width: gap),
                            SizedBox(width: width, child: children[i]),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// `.capw`: the capability list with its filter bar, and the selected
/// encoder's details at the right.
class _Capabilities extends ConsumerWidget {
  const _Capabilities({
    required this.installation,
    required this.state,
    required this.catalog,
    required this.presets,
    required this.query,
    required this.searchFocus,
    required this.onTest,
    required this.onOpenPreset,
  });

  final FFmpegInstallation installation;
  final FFmpegState state;
  final ProfileCatalog catalog;
  final List<Preset> presets;
  final TextEditingController query;
  final FocusNode searchFocus;
  final ValueChanged<String> onTest;
  final ValueChanged<String> onOpenPreset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final controller = ref.read(ffmpegControllerProvider.notifier);
    final video = state.kind == EncoderKind.video;
    final status = statusLookup(installation, state);
    final filter = !video && state.filter == CapabilityFilter.hardware ? CapabilityFilter.all : state.filter;
    final groups = capabilityGroups(catalog, kind: state.kind, statusOf: status, filter: filter, query: state.query);
    final rows = [for (final g in groups) ...g.rows];
    final encoderId =
        state.selectedEncoder ??
        rows.firstOrNull?.id ??
        (video ? catalog.video.firstOrNull?.id : catalog.audio.firstOrNull?.id);

    return LayoutBuilder(
      builder: (context, box) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.line)),
                  ),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      VeSegmented<EncoderKind>(
                        semanticLabel: 'Encoder type',
                        segments: const [
                          VeSegment(EncoderKind.video, 'Video encoders'),
                          VeSegment(EncoderKind.audio, 'Audio encoders'),
                        ],
                        selected: state.kind,
                        onChanged: controller.setKind,
                      ),
                      VeSegmented<CapabilityFilter>(
                        semanticLabel: 'Show',
                        segments: [
                          const VeSegment(CapabilityFilter.all, 'All'),
                          const VeSegment(CapabilityFilter.problems, 'Only problems'),
                          if (video) const VeSegment(CapabilityFilter.hardware, 'Hardware'),
                        ],
                        selected: filter,
                        onChanged: controller.setFilter,
                      ),
                      VeTextField(
                        controller: query,
                        focusNode: searchFocus,
                        search: true,
                        width: 200,
                        placeholder: 'Search encoders',
                        semanticLabel: 'Search encoders (Ctrl+F)',
                        onChanged: controller.setQuery,
                      ),
                      Text(
                        problemSummary(catalog, installation.label, status),
                        style: t.text.small.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CapabilityTable(
                    groups: groups,
                    selectedId: encoderId,
                    video: video,
                    onSelect: controller.selectEncoder,
                    emptyText: switch (filter) {
                      _ when state.query.trim().isNotEmpty => 'No encoders match “${state.query.trim()}”.',
                      CapabilityFilter.problems => 'Everything in this list is ready.',
                      CapabilityFilter.hardware => 'No hardware encoders in this list.',
                      CapabilityFilter.all => 'No encoders to show.',
                    },
                  ),
                ),
              ],
            ),
          ),
          if (encoderId != null)
            Container(
              width: box.maxWidth >= 1240 ? 450 : 380,
              decoration: BoxDecoration(
                color: c.panel,
                border: Border(left: BorderSide(color: c.line)),
              ),
              child: EncoderDetail(
                key: ValueKey('${installation.id}/$encoderId'),
                model: encoderDetail(
                  catalog,
                  encoderId,
                  installation: installation,
                  status: status(encoderId),
                  presets: presets,
                ),
                onTest: state.isTesting(installation.id, encoderId) ? null : () => onTest(encoderId),
                onOpenPreset: onOpenPreset,
              ),
            ),
        ],
      ),
    );
  }
}
