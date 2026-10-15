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

/// The part of a job's FFmpeg log the detail shows: its last lines, so a
/// long log (C6 allows megabytes) stays quick to lay out. The whole file is
/// a click away (Show in folder).
@immutable
class JobLogView {
  const JobLogView({required this.text, required this.totalLines, required this.shownLines, required this.complete});

  /// The last [shownLines] lines.
  final String text;

  /// Lines read so far (all of them once [complete]).
  final int totalLines;
  final int shownLines;

  /// The whole log has been read.
  final bool complete;

  bool get truncated => shownLines < totalLines;
}

/// How much of a log [jobLogProvider] keeps: the last lines, at most this
/// many characters of them.
const int jobLogMaxLines = 1000;
const int jobLogMaxChars = 200000;

/// A job's full FFmpeg log (C6 `logFile`, C3 `JobLogs.readLog`), read as it
/// streams in and kept to its last [jobLogMaxLines] lines. Null when the job
/// has no log (FFmpeg never started, or the file was removed: `NOT-FOUND`).
/// Read only when the detail asks for it; a failure isn't retried.
final jobLogProvider = StreamProvider.autoDispose.family<JobLogView?, String>((ref, id) async* {
  final tail = <String>[];
  var total = 0;
  var pending = '';
  JobLogView view({required bool complete}) {
    var lines = [...tail, if (pending.isNotEmpty) pending];
    if (lines.length > jobLogMaxLines) lines = lines.sublist(lines.length - jobLogMaxLines);
    // Whole lines only: drop from the front until the rest fits.
    var length = lines.fold(0, (n, l) => n + l.length + 1);
    var from = 0;
    while (length > jobLogMaxChars && from < lines.length - 1) {
      length -= lines[from++].length + 1;
    }
    lines = lines.sublist(from);
    final text = lines.join('\n');
    final shown = lines.length;
    final all = total + (pending.isNotEmpty ? 1 : 0);
    return JobLogView(text: text, totalLines: all, shownLines: shown, complete: complete);
  }

  try {
    await for (final chunk in ref.watch(jobLogsProvider).readLog(id)) {
      final parts = (pending + chunk.replaceAll('\r\n', '\n')).split('\n');
      pending = parts.removeLast();
      tail.addAll(parts);
      total += parts.length;
      if (tail.length > jobLogMaxLines) tail.removeRange(0, tail.length - jobLogMaxLines);
      yield view(complete: false);
    }
  } on ServiceException catch (e) {
    if (e.code == 'NOT-FOUND') {
      yield null;
      return;
    }
    rethrow;
  }
  yield view(complete: true);
}, retry: (_, _) => null);

/// Where a job's FFmpeg log file is, for Show in folder; null when it has none.
final jobLogLocationProvider = FutureProvider.autoDispose.family<String?, String>((ref, id) async {
  try {
    return await ref.watch(jobLogsProvider).logLocation(id);
  } on ServiceException {
    return null;
  }
}, retry: (_, _) => null);

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
