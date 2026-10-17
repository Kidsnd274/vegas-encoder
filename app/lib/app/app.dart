import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../features/monitor/monitor_window.dart';
import '../features/popup/popup_window.dart';
import '../features/shell/desktop_shell.dart';
import '../state/app_state.dart';
import '../state/desktop_interaction.dart';
import 'launch.dart';

/// The root: theme (light and dark, following Windows unless Settings forces
/// one), reduced motion from the runner, and the window for the launch mode.
class VeApp extends ConsumerWidget {
  const VeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(launchModeProvider);
    final themeMode = ref.watch(themePreferenceProvider.select((p) => p.themeMode));
    final reducedMotion = ref.watch(windowStateProvider.select((s) => s.reducedMotion));

    return MaterialApp(
      title: 'Vegas Encoder',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [ref.watch(desktopInteractionProvider)],
      theme: buildVeTheme(VeTokens.light),
      darkTheme: buildVeTheme(VeTokens.dark),
      themeMode: themeMode,
      themeAnimationDuration: reducedMotion ? Duration.zero : const Duration(milliseconds: 200),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: media.disableAnimations || reducedMotion),
          child: VeSurface(child: child!),
        );
      },
      home: switch (mode) {
        DesktopLaunch() => const DesktopShell(),
        EditSessionLaunch() => const PopupWindow(),
        RenderMonitorLaunch() => const MonitorWindow(),
        LaunchError(:final message, :final window) =>
          window == LaunchWindow.editSession ? PopupWindow(launchError: message) : MonitorWindow(launchError: message),
      },
    );
  }
}

/// Default text style and a transparent Material for text fields, without any
/// Material surface showing.
class VeSurface extends StatelessWidget {
  const VeSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(style: t.text.body, child: child),
    );
  }
}
