import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/launch.dart';
import '../platform/window_channel.dart';

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

/// Settings > Theme (UI_SPEC §1). Both windows use the same choice.
enum ThemePreference {
  followWindows('Follow Windows'),
  light('Light'),
  dark('Dark');

  const ThemePreference(this.label);
  final String label;

  ThemeMode get themeMode => switch (this) {
    ThemePreference.followWindows => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };
}

/// Held in memory until the machine settings service exists (ve_services, C3/C7);
/// see docs/product/workstreams/app.md, Needs.
final themePreferenceProvider = NotifierProvider<ThemePreferenceNotifier, ThemePreference>(ThemePreferenceNotifier.new);

class ThemePreferenceNotifier extends Notifier<ThemePreference> {
  @override
  ThemePreference build() => ThemePreference.followWindows;

  void set(ThemePreference value) => state = value;
}
