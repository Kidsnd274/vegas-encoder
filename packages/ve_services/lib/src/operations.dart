import 'dart:async';
import 'process_runner.dart';

class ServiceOperation {
  final token = CancellationToken();
  final done = Completer<void>();
}

class OperationRegistry {
  final Map<String, Set<ServiceOperation>> _operations = {};
  ServiceOperation begin(String id) {
    final op = ServiceOperation();
    _operations.putIfAbsent(id, () => {}).add(op);
    return op;
  }

  void finish(String id, ServiceOperation op) {
    _operations[id]?.remove(op);
    if (_operations[id]?.isEmpty == true) _operations.remove(id);
    if (!op.done.isCompleted) op.done.complete();
  }

  Future<void> cancel(String id) async {
    final operations = _operations[id]?.toList() ?? [];
    for (final op in operations) {
      op.token.cancel();
    }
    await Future.wait(operations.map((op) => op.done.future));
  }
}
