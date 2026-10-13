import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart' show ServiceException;

import '../app/launch.dart';
import '../platform/window_channel.dart';
import 'services.dart';

/// How the process was started. Overridden in `main` and in tests.
final launchModeProvider = Provider<LaunchMode>((ref) => const DesktopLaunch());

/// The runner's window channel. Tests override it with [FakeWindowController].
final windowControllerProvider = Provider<WindowController>((ref) => MethodChannelWindowController());

/// The window state read before `runApp`; the notifier keeps it current.
final initialWindowStateProvider = Provider<WindowState>((ref) => const WindowState());

final windowStateProvider = NotifierProvider<WindowStateNotifier, WindowState>(WindowStateNotifier.new);

class WindowStateNotifier extends Notifier<WindowState> {
  @override
  WindowState build() {
    final StreamSubscription<WindowState> sub = ref.watch(windowControllerProvider).changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return ref.watch(initialWindowStateProvider);
  }
}

/// Settings > Theme (UI_SPEC §1). Both windows use the same choice, stored as
/// C7 `theme` in machine settings (`system` is Follow Windows).
enum ThemePreference {
  followWindows('Follow Windows', 'system'),
  light('Light', 'light'),
  dark('Dark', 'dark');

  const ThemePreference(this.label, this.stored);
  final String label;

  /// The C7 value.
  final String stored;

  static ThemePreference fromStored(String? value) =>
      values.where((p) => p.stored == value).firstOrNull ?? ThemePreference.followWindows;

  ThemeMode get themeMode => switch (this) {
    ThemePreference.followWindows => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };
}

final themePreferenceProvider = NotifierProvider<ThemePreferenceNotifier, ThemePreference>(ThemePreferenceNotifier.new);

class ThemePreferenceNotifier extends Notifier<ThemePreference> {
  @override
  ThemePreference build() => ThemePreference.fromStored(ref.watch(machineSettingsProvider).value?.theme);

  /// Applies at once and saves to machine settings. A save that loses to a
  /// change made elsewhere leaves that change in place.
  Future<void> set(ThemePreference value) async {
    state = value;
    final repository = ref.read(machineSettingsRepositoryProvider);
    final current = await repository.read();
    if (current.theme == value.stored) return;
    try {
      await repository.save(current.copyWith(theme: value.stored), expectedRevision: current.revision);
    } on ServiceException {
      ref.invalidateSelf();
    }
  }
}
