import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../app/launch.dart';
import 'app_state.dart';
import 'desktop_interaction.dart';
import 'ffmpeg.dart';
import 'services.dart';
import 'ui_state.dart';

/// The first-run setup (UI_SPEC §5a): find FFmpeg, check it on this PC, choose
/// the default. It offers itself on a desktop start while renders have no
/// default FFmpeg, unless the user skipped it before (C7 `setupDismissed`).
final shouldOfferSetupProvider = Provider<bool>((ref) {
  if (ref.watch(launchModeProvider) is! DesktopLaunch || ref.watch(coreLoadErrorProvider) != null) return false;
  final settings = ref.watch(machineSettingsProvider).value;
  return settings != null && settings.defaultFFmpegId == null && !(settings.uiState?.setupDismissed ?? false);
});

enum SetupStep { find, check, choose }

@immutable
class SetupWizardState {
  const SetupWizardState({
    this.step = SetupStep.find,
    this.finding = false,
    this.checking = false,
    this.saving = false,
    this.chosenId,
    this.error,
  });

  final SetupStep step;

  /// Discovery is looking (PATH, winget, Scoop, Chocolatey).
  final bool finding;

  /// Probes or hardware tests the wizard started are still running.
  final bool checking;

  /// The default is being saved.
  final bool saving;

  /// The installation the user picked; null takes the recommended one.
  final String? chosenId;

  /// Why the last scan, add or save failed.
  final String? error;

  SetupWizardState copyWith({
    SetupStep? step,
    bool? finding,
    bool? checking,
    bool? saving,
    Object? chosenId = _keep,
    Object? error = _keep,
  }) => SetupWizardState(
    step: step ?? this.step,
    finding: finding ?? this.finding,
    checking: checking ?? this.checking,
    saving: saving ?? this.saving,
    chosenId: identical(chosenId, _keep) ? this.chosenId : chosenId as String?,
    error: identical(error, _keep) ? this.error : error as String?,
  );
}

const Object _keep = Object();

final setupWizardProvider = NotifierProvider.autoDispose<SetupWizardController, SetupWizardState>(
  SetupWizardController.new,
);

/// Drives the wizard's steps. The work is [FFmpegController]'s: scan, probe
/// (which tests the listed hardware encoders), hardware tests and the default,
/// so the FFmpeg page shows the same progress and results.
class SetupWizardController extends Notifier<SetupWizardState> {
  @override
  SetupWizardState build() => const SetupWizardState();

  FFmpegController get _ffmpeg => ref.read(ffmpegControllerProvider.notifier);

  /// Checks the wizard started that are still running (a scan's and adds').
  int _checks = 0;

  void _checkStarted() => state = state.copyWith(checking: ++_checks > 0);

  /// The last check to end moves Check on to Choose.
  void _checkEnded() {
    if (!ref.mounted) return;
    final checking = --_checks > 0;
    state = state.copyWith(
      checking: checking,
      step: !checking && state.step == SetupStep.check ? SetupStep.choose : null,
    );
  }

  /// Scans, checks each installation that was never checked, then tests the
  /// hardware encoders whose result isn't known (an expired or changed GPU
  /// record) as [untested] lists them. Moves to Check once something is
  /// found and to Choose once the checks end.
  Future<void> start({required List<String> Function(FFmpegInstallation installation) untested}) async {
    state = state.copyWith(step: SetupStep.find, finding: true, error: null);
    var found = const <FFmpegInstallation>[];
    var started = false;
    try {
      found = await _ffmpeg.scan(
        onFound: (list) {
          if (!ref.mounted) return;
          state = state.copyWith(finding: false, step: list.isEmpty ? SetupStep.find : SetupStep.check);
          if (list.isEmpty) return;
          started = true;
          _checkStarted();
        },
      );
    } on ServiceException catch (e) {
      if (ref.mounted) state = state.copyWith(finding: false, error: e.message);
      if (started) _checkEnded();
      return;
    }
    if (!ref.mounted || found.isEmpty) return;
    try {
      for (final installation in await ref.read(ffmpegDiscoveryProvider).list()) {
        final names = untested(installation);
        if (!ref.mounted) return;
        if (names.isNotEmpty) await _ffmpeg.testHardware(installation, hardwareEncoders: names, encoders: names);
      }
    } on ServiceException {
      // The rows show what is known; a test that couldn't start stays "Not checked yet".
    } finally {
      _checkEnded();
    }
  }

  /// Add FFmpeg…: discovery adds [path], it is checked and chosen.
  Future<void> add(String path) async {
    state = state.copyWith(error: null, step: state.step == SetupStep.find ? SetupStep.check : null);
    _checkStarted();
    try {
      final added = await _ffmpeg.add(path);
      if (ref.mounted) state = state.copyWith(chosenId: added.id);
    } on ServiceException catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          error: 'Couldn’t add $path: ${e.message}',
          step: ref.read(discoveredInstallationsProvider).value?.isNotEmpty ?? false ? null : SetupStep.find,
        );
      }
    } finally {
      _checkEnded();
    }
  }

  /// Choose without waiting: the checks go on and their results fill the list.
  void skipWaiting() => state = state.copyWith(step: SetupStep.choose);

  void choose(String id) => state = state.copyWith(chosenId: id);

  /// Makes [installation] the default. Returns false, with the reason in
  /// [SetupWizardState.error], if it couldn't be saved.
  Future<bool> finish(FFmpegInstallation installation) async {
    state = state.copyWith(saving: true, error: null);
    try {
      await ref.read(desktopInteractionProvider).run(() => _ffmpeg.setDefault(installation));
      return true;
    } on ServiceException catch (e) {
      if (ref.mounted) state = state.copyWith(error: 'Couldn’t make it the default: ${e.message}');
      return false;
    } finally {
      if (ref.mounted) state = state.copyWith(saving: false);
    }
  }

  /// Skip for now: remembered, so the next start doesn't ask again. A lost
  /// write only means the wizard offers itself once more.
  Future<void> skip() async {
    try {
      await ref.read(uiStateWriterProvider).update((ui) => ui.copyWith(setupDismissed: true));
    } on ServiceException {
      // Keep closing.
    }
  }
}
