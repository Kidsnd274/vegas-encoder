import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import 'app_state.dart';
import 'popup.dart';
import 'services.dart';

enum PopupVersionMatch { matching, mismatched, unknown }

/// The plug-in and app have independent suffixes/build numbers (for example,
/// 0.1.7-recipe-proof and 0.1.7+1). Compare their release triplets, and compare
/// the independently versioned static/dynamic core stamps exactly.
@immutable
class PopupVersionStatus {
  const PopupVersionStatus({
    required this.dllVersion,
    required this.coreVersion,
    required this.appVersion,
    required this.appCoreVersion,
  });

  final String dllVersion;
  final String coreVersion;
  final String? appVersion;
  final String? appCoreVersion;

  PopupVersionMatch get match {
    final dll = _release(dllVersion);
    final app = _release(appVersion);
    final knownCore = coreVersion.trim().isNotEmpty && (appCoreVersion?.trim().isNotEmpty ?? false);
    if ((dll != null && app != null && dll != app) || (knownCore && coreVersion != appCoreVersion)) {
      return PopupVersionMatch.mismatched;
    }
    if (dll == null || app == null || !knownCore) return PopupVersionMatch.unknown;
    return PopupVersionMatch.matching;
  }

  String get details =>
      'Plug-in: ${_stamp(dllVersion)}; app: ${_stamp(appVersion)}. '
      'Plug-in core: ${_stamp(coreVersion)}; app core: ${_stamp(appCoreVersion)}.';
}

String _stamp(String? value) => value == null || value.trim().isEmpty ? 'unavailable' : value;

(int, int, int)? _release(String? version) {
  if (version == null) return null;
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$').firstMatch(version.trim());
  if (match == null) return null;
  final parts = [for (var i = 1; i <= 3; i++) int.tryParse(match.group(i)!)];
  if (parts.any((part) => part == null)) return null;
  return (parts[0]!, parts[1]!, parts[2]!);
}

/// Read-only version facts. A missing runner method/stamp is unknown; it is
/// never replaced by a hardcoded pubspec or candidate version.
final popupVersionsProvider = FutureProvider<PopupVersionStatus>((ref) async {
  final request = await ref.watch(editSessionRequestProvider.future);
  final window = ref.watch(windowControllerProvider);
  final core = ref.watch(veCoreProvider);
  String? appVersion;
  try {
    appVersion = await window.appVersion();
  } catch (_) {
    // A stamp that could not be read remains explicitly unverified.
  }
  String? appCoreVersion;
  try {
    appCoreVersion = core.version.core;
  } on CoreException {
    // The popup's existing core-unavailable view supplies the load error.
  }
  return PopupVersionStatus(
    dllVersion: request.dllVersion,
    coreVersion: request.coreVersion,
    appVersion: appVersion,
    appCoreVersion: appCoreVersion,
  );
});
