import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../design/format.dart';
import 'presets.dart';
import 'services.dart';
import 'settings.dart';

/// Writes the app's own UI state (C7 `uiState`: window bounds, the size card's
/// length text). Each write copies the latest machine settings and changes only
/// `uiState`, so another window's FFmpeg choice or pin survives; a revision
/// conflict re-reads and reapplies.
class UiStateWriter {
  UiStateWriter(this._writer);
  final MachineSettingsWriter _writer;
  Timer? _pending;

  Future<void> update(AppUiState Function(AppUiState current) change) async {
    try {
      await _writer.update((s) => s.copyWith(uiState: change(s.uiState ?? AppUiState())));
    } on ServiceException catch (e) {
      // UI state is a convenience: losing three conflicts in a row drops it.
      if (e.code != 'REVISION-CONFLICT') rethrow;
    }
  }

  /// [update] after typing pauses, so each keystroke doesn't write the file.
  void later(AppUiState Function(AppUiState current) change) {
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 600), () => unawaited(update(change)));
  }

  void dispose() => _pending?.cancel();
}

final uiStateWriterProvider = Provider<UiStateWriter>((ref) {
  final writer = UiStateWriter(ref.watch(machineSettingsWriterProvider));
  ref.onDispose(writer.dispose);
  return writer;
});

/// The size card's length text (UI_SPEC §2: "starts at the last length used,
/// 10:00 the first time"): typed this session, else remembered, else 10:00.
final sizeLengthTextProvider = Provider<String>((ref) {
  final typed = ref.watch(presetsControllerProvider.select((s) => s.lengthText));
  return typed ?? ref.watch(machineSettingsProvider).value?.uiState?.lastSizeLengthText ?? '10:00';
});

/// The typed length in seconds, or null when the text isn't a length. The
/// core gets this number; the text is display only.
final sizeLengthSecProvider = Provider<int?>((ref) => VeFormat.parseLength(ref.watch(sizeLengthTextProvider)));
