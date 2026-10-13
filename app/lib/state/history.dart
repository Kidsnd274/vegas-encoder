import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import 'services.dart';

/// History's status filter (UI_SPEC §6).
enum HistoryFilter {
  all('All', null),
  succeeded('Succeeded', 'succeeded'),
  failed('Failed', 'failed'),
  cancelled('Cancelled', 'cancelled');

  const HistoryFilter(this.label, this.status);
  final String label;

  /// The C6 status this filter keeps; null keeps every job.
  final String? status;

  bool keeps(JobIndexEntry e) => status == null || e.status == status;
}

/// The History screen's own state. Jobs come from [jobsProvider].
@immutable
class HistoryState {
  const HistoryState({this.filter = HistoryFilter.all, this.selectedId});
  final HistoryFilter filter;

  /// The job the user picked; null until they pick one.
  final String? selectedId;

  HistoryState copyWith({HistoryFilter? filter, String? selectedId}) =>
      HistoryState(filter: filter ?? this.filter, selectedId: selectedId ?? this.selectedId);
}

final historyControllerProvider = NotifierProvider<HistoryController, HistoryState>(HistoryController.new);

class HistoryController extends Notifier<HistoryState> {
  @override
  HistoryState build() => const HistoryState();

  void setFilter(HistoryFilter filter) => state = state.copyWith(filter: filter);
  void select(String id) => state = state.copyWith(selectedId: id);
}

/// What the list shows: the jobs the filter keeps, newest first as the index
/// gives them, and the job whose detail shows (the picked one while the
/// filter keeps it, else the first). Null while the index is being read.
typedef HistoryView = ({List<JobIndexEntry> all, List<JobIndexEntry> shown, String? selectedId});

final historyViewProvider = Provider<AsyncValue<HistoryView>>((ref) {
  final state = ref.watch(historyControllerProvider);
  return ref.watch(jobsProvider).whenData((all) {
    final shown = all.where(state.filter.keeps).toList();
    final picked = state.selectedId;
    final selected = shown.any((e) => e.id == picked) ? picked : shown.firstOrNull?.id;
    return (all: all, shown: shown, selectedId: selected);
  });
});
