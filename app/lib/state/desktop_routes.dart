import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../platform/desktop_channel.dart';
import 'app_state.dart';
import 'history.dart';
import 'presets.dart';
import 'services.dart';

final desktopRouteSourceProvider = Provider<DesktopRouteSource>((ref) {
  final source = MethodChannelDesktopRouteSource();
  ref.onDispose(source.dispose);
  return source;
});

/// Applies a navigation request without replacing any existing editor drafts.
/// A removed target returns a message while leaving the current selection alone.
Future<String?> openDesktopRoute(
  ProviderContainer container,
  DesktopRoute route, {
  bool Function()? isMounted,
  Future<bool> Function()? beforeApply,
}) async {
  try {
    if (!route.valid) return 'The requested desktop destination is invalid.';
    if (route.kind == 'preset') {
      final preset = await container.read(presetLibraryProvider).get(route.id);
      if (preset == null) return 'This preset is no longer in the library. It may have been deleted.';
      if (isMounted?.call() == false) return null;
      container.invalidate(presetsProvider);
      final listening = container.listen(presetsProvider, (_, _) {});
      try {
        await container.read(presetsProvider.future);
      } finally {
        listening.close();
      }
      if (isMounted?.call() == false) return null;
      if (beforeApply != null && !await beforeApply()) return null;
      if (isMounted?.call() == false) return null;
      final controller = container.read(presetsControllerProvider.notifier);
      controller.showAll();
      controller.select(preset.recipe.id);
      container.read(desktopSectionProvider.notifier).go(DesktopSection.presets);
    } else {
      final job = await container.read(jobRepositoryProvider).get(route.id);
      if (job == null) return 'This render is no longer in History. Its job record may have been removed.';
      if (isMounted?.call() == false) return null;
      if (beforeApply != null && !await beforeApply()) return null;
      if (isMounted?.call() == false) return null;
      final controller = container.read(historyControllerProvider.notifier);
      controller.setFilter(HistoryFilter.all);
      controller.select(job.id);
      container.invalidate(jobsProvider);
      container.invalidate(jobRecordProvider(job.id));
      container.read(desktopSectionProvider.notifier).go(DesktopSection.history);
    }
    return null;
  } on ServiceException catch (e) {
    return 'Couldn’t open this ${route.kind == 'preset' ? 'preset' : 'render'}: ${e.message}';
  }
}
