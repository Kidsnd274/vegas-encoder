import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/button.dart';
import '../../design/components/field.dart';
import '../../design/components/message.dart';
import '../../design/components/page_header.dart';
import '../../design/components/popover.dart';
import '../../design/components/segmented.dart';
import '../../design/components/select.dart';
import '../../design/components/switch.dart';
import '../../design/tokens.dart';
import '../../state/app_state.dart';
import '../../state/services.dart';
import '../../state/settings.dart';
import '../presets/panels/panel_kit.dart';
import 'display.dart';

/// Settings (Ctrl+4): this PC's choices, stored in machine settings (C7).
/// Appearance is app-only; the default FFmpeg and the rendering switches are
/// what VEGAS reads when a render starts. Every control saves at once through
/// [MachineSettingsWriter], so another window's change survives, and shows the
/// stored value, so a change made elsewhere appears here too.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> with VeToastHost {
  Future<void> _save(MachineSettings Function(MachineSettings s) change) async {
    try {
      await ref.read(machineSettingsWriterProvider).update(change);
    } on ServiceException catch (e) {
      if (mounted) showToast('Couldn’t save: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(machineSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VePageHeader(
          title: 'Settings',
          description: 'How Vegas Encoder looks on this PC, which FFmpeg renders, and what happens during a render.',
        ),
        Expanded(
          child: Stack(
            children: [
              switch (settings) {
                AsyncData(:final value) => _SettingsList(settings: value, save: _save),
                AsyncError(:final error) => _Unreadable(error),
                _ => const SizedBox.shrink(),
              },
              toastLayer(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsList extends ConsumerWidget {
  const _SettingsList({required this.settings, required this.save});
  final MachineSettings settings;
  final Future<void> Function(MachineSettings Function(MachineSettings s) change) save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(veCoreProvider).version;
    // Null for the platform's fakes, which keep nothing.
    final paths = ref.watch(servicesProvider).paths;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(
                title: 'Appearance',
                children: [
                  VeField(
                    label: 'Theme',
                    blurb: const Text(
                      'Follow Windows uses the app mode from Windows Settings, Personalization, Colors, and '
                      'changes with it. The editor that opens from VEGAS uses the same choice.',
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: VeSegmented<ThemePreference>(
                        semanticLabel: 'Theme',
                        segments: [for (final p in ThemePreference.values) VeSegment(p, p.label)],
                        selected: ref.watch(themePreferenceProvider),
                        onChanged: (p) => unawaited(ref.read(themePreferenceProvider.notifier).set(p)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: VeSpace.s4),
              _Section(
                title: 'FFmpeg',
                children: [
                  _DefaultFFmpeg(
                    settings: settings,
                    onChanged: (id) => unawaited(save((s) => s.copyWith(defaultFFmpegId: id))),
                    onManage: () => ref.read(desktopSectionProvider.notifier).go(DesktopSection.ffmpeg),
                  ),
                ],
              ),
              const SizedBox(height: VeSpace.s4),
              _Section(
                title: 'Rendering',
                children: [
                  _SwitchSetting(
                    label: 'Show a progress window during renders',
                    value: settings.progressWindow,
                    onChanged: (v) => unawaited(save((s) => s.copyWith(progressWindow: v))),
                    blurb:
                        'A small window in a corner of the screen shows the frame count, speed and size while '
                        'VEGAS renders. It never takes the focus. Rendering is cancelled in VEGAS’s own dialog.',
                  ),
                  _SwitchSetting(
                    label: 'Keep the progress window on top',
                    value: settings.keepOnTop,
                    onChanged: settings.progressWindow ? (v) => unawaited(save((s) => s.copyWith(keepOnTop: v))) : null,
                    blurb: settings.progressWindow
                        ? 'Off by default. The pin in the progress window’s title bar changes this too.'
                        : 'Turn on the progress window to choose this.',
                  ),
                  _SwitchSetting(
                    label: 'Check each file after rendering',
                    value: settings.verifyOutput,
                    onChanged: (v) => unawaited(save((s) => s.copyWith(verifyOutput: v))),
                    blurb: settings.verifyOutput
                        ? 'ffprobe reads the finished file and checks it holds the streams the preset asked for '
                              'before the file gets its final name.'
                        : 'Files get their final name without the ffprobe check. History records that the '
                              'check was skipped.',
                  ),
                  const VeMessage(
                    level: VeLevel.info,
                    text:
                        'VEGAS reads these when a render starts. A render that is already running keeps the '
                        'settings it started with.',
                  ),
                ],
              ),
              const SizedBox(height: VeSpace.s4),
              _Section(
                title: 'About',
                children: [
                  PanelFacts([
                    ('App', 'Vegas Encoder'),
                    ('Core', coreVersionLabel(version)),
                    ('Formats', 'Recipe schema ${version.schemaMax}, contracts ${version.contracts}'),
                    (
                      'Services',
                      paths == null
                          ? 'Sample data from the platform’s fakes. Settings last until the app closes.'
                          : 'This PC. Settings and presets are in "${paths.roaming}"; FFmpeg checks and render '
                                'records in "${paths.local}".',
                    ),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Default FFmpeg: the installation every render uses (C7 `defaultFFmpegId`).
class _DefaultFFmpeg extends StatelessWidget {
  const _DefaultFFmpeg({required this.settings, required this.onChanged, required this.onManage});
  final MachineSettings settings;
  final ValueChanged<String> onChanged;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final installations = settings.installations;
    final state = defaultFFmpegState(settings);
    final selected = installations.where((i) => i.id == settings.defaultFFmpegId).firstOrNull;
    // Problems sit right under the control, before the explanation.
    final problem = switch (state) {
      DefaultFFmpegState.ok => null,
      DefaultFFmpegState.noInstallations => const VeMessage(
        level: VeLevel.warning,
        text: 'Renders need a default FFmpeg, and none is set up yet.',
        fix: 'Add one on the FFmpeg page; Vegas Encoder can also look for installed copies there.',
      ),
      DefaultFFmpegState.notChosen => const VeMessage(
        level: VeLevel.warning,
        text: 'Renders need a default FFmpeg. Choose one of the installations above.',
      ),
      DefaultFFmpegState.unregistered => VeMessage(
        level: VeLevel.error,
        text: 'The default FFmpeg “${settings.defaultFFmpegId}” isn’t one of the installations any more.',
        fix: 'Renders stop until you choose one.',
      ),
    };

    return VeField(
      label: 'Default FFmpeg',
      blurb: const Text(
        'Every render uses this FFmpeg. Presets never name a path, so they keep working when you change it. '
        'A render that is already running keeps the FFmpeg it started with.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (installations.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: VeButton(label: 'Open the FFmpeg page', onPressed: onManage),
            )
          else ...[
            Row(
              children: [
                VeSelect<String>(
                  semanticLabel: 'Default FFmpeg',
                  width: 360,
                  value: selected?.id,
                  options: [for (final i in installations) VeOption(i.id, i.label, detail: installationDetail(i))],
                  onChanged: onChanged,
                ),
                const SizedBox(width: 14),
                VeLinkButton(label: 'Manage installations', onPressed: onManage),
              ],
            ),
            if (selected != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                // Paths are never shortened in words; the tooltip has it whole.
                child: VeTooltip(
                  message: selected.path,
                  child: Text(
                    selected.path,
                    style: t.text.monoSmall.copyWith(color: c.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    semanticsLabel: 'Path: ${selected.path}',
                  ),
                ),
              ),
            ],
          ],
          if (problem != null) ...[const SizedBox(height: 10), problem],
        ],
      ),
    );
  }
}

/// A switch with its explanation under the label.
class _SwitchSetting extends StatelessWidget {
  const _SwitchSetting({required this.label, required this.value, required this.onChanged, required this.blurb});
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String blurb;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      VeSwitch(label: label, value: value, onChanged: onChanged),
      Padding(
        // Lines up with the label: switch width plus its gap.
        padding: const EdgeInsets.only(left: 41, top: 4),
        child: PanelBlurb(blurb),
      ),
    ],
  );
}

/// One group of settings on a surface card.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Semantics(
      container: true,
      label: title,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line2),
          borderRadius: BorderRadius.circular(VeRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(title, style: t.text.panelTitle)),
            for (final child in children) ...[const SizedBox(height: 18), child],
          ],
        ),
      ),
    );
  }
}

class _Unreadable extends StatelessWidget {
  const _Unreadable(this.error);
  final Object error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(22),
    child: VeMessage(level: VeLevel.error, text: 'The settings couldn’t be read: $error'),
  );
}
