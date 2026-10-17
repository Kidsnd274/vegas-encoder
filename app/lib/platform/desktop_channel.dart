import 'dart:async';

import 'package:flutter/services.dart';
import 'package:ve_services/ve_services.dart' show DesktopRoute;

/// A separate channel keeps desktop navigation independent of window placement.
/// start drains requests queued before Dart was ready; changes carries later ones.
abstract interface class DesktopRouteSource {
  Stream<DesktopRoute> get changes;
  Future<List<DesktopRoute>> start();
  void dispose();
}

class MethodChannelDesktopRouteSource implements DesktopRouteSource {
  MethodChannelDesktopRouteSource() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'route') {
        if (_parse(call.arguments) case final route?) {
          if (_started) {
            _changes.add(route);
          } else {
            _early.add(route);
          }
        }
      }
    });
  }

  static const _channel = MethodChannel('vegas_encoder/desktop');
  final _changes = StreamController<DesktopRoute>.broadcast();
  final List<DesktopRoute> _early = [];
  bool _started = false;

  static DesktopRoute? _parse(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    if (id is! String || !DesktopRoute.validId(id)) return null;
    return switch (value['kind']) {
      'preset' => DesktopRoute.preset(id),
      'job' => DesktopRoute.job(id),
      _ => null,
    };
  }

  @override
  Stream<DesktopRoute> get changes => _changes.stream;
  @override
  Future<List<DesktopRoute>> start() async {
    List<Object?> pending;
    try {
      pending = await _channel.invokeListMethod<Object?>('ready') ?? const [];
    } on MissingPluginException {
      pending = const [];
    }
    final routes = [...pending.map(_parse).whereType<DesktopRoute>(), ..._early];
    _early.clear();
    _started = true;
    return routes;
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_changes.close());
  }
}
