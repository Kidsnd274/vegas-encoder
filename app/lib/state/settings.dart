import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import 'services.dart';

/// Writes machine settings (C7) the way CONTRACTS asks: copy the latest
/// settings, change only what this write is about, save at that revision, and
/// on a revision conflict read again and reapply the change. Another window's
/// FFmpeg choice or pin survives. Other service failures reach the caller.
class MachineSettingsWriter {
  MachineSettingsWriter(this._repository);
  final MachineSettingsRepository _repository;

  /// Returns the saved settings. Gives up after three conflicts in a row and
  /// rethrows the last one.
  Future<MachineSettings> update(MachineSettings Function(MachineSettings current) change) async {
    for (var attempt = 0; ; attempt++) {
      final current = await _repository.read();
      try {
        return await _repository.save(change(current), expectedRevision: current.revision);
      } on ServiceException catch (e) {
        if (e.code != 'REVISION-CONFLICT' || attempt >= 2) rethrow;
      }
    }
  }
}

final machineSettingsWriterProvider = Provider<MachineSettingsWriter>(
  (ref) => MachineSettingsWriter(ref.watch(machineSettingsRepositoryProvider)),
);
