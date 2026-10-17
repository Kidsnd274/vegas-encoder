import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// External navigation waits for both modal dismissal and the complete action
/// that opened it (including a later revision-conflict/save continuation).
class DesktopInteractionGate extends NavigatorObserver {
  final Set<PopupRoute<dynamic>> _modals = {};
  int _operations = 0;
  bool _disposed = false;
  Completer<void>? _changed;

  bool get _idle => _operations == 0 && _modals.isEmpty;

  void _notify() {
    final changed = _changed;
    _changed = null;
    changed?.complete();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PopupRoute<dynamic>) return;
    _modals.add(route);
    // A dialog's result completes before its closing animation. Its final
    // completion also gives the caller time to enter its guarded write.
    unawaited(
      route.completed.then((_) {
        _modals.remove(route);
        _notify();
      }),
    );
  }

  Future<T> run<T>(Future<T> Function() action) async {
    _operations++;
    try {
      return await action();
    } finally {
      _operations--;
      _notify();
    }
  }

  /// Nonpolling wait. A shell's cancellation completes its pending wait when
  /// unmounted; provider disposal releases all remaining waiters too.
  Future<bool> waitUntilIdle({Future<void>? cancelled}) async {
    while (!_disposed && !_idle) {
      final changed = (_changed ??= Completer<void>()).future;
      if (cancelled == null) {
        await changed;
      } else if (!await Future.any<bool>([changed.then((_) => true), cancelled.then((_) => false)])) {
        return false;
      }
    }
    return !_disposed;
  }

  void dispose() {
    _disposed = true;
    _notify();
  }
}

final desktopInteractionProvider = Provider<DesktopInteractionGate>((ref) {
  final gate = DesktopInteractionGate();
  ref.onDispose(gate.dispose);
  return gate;
});
