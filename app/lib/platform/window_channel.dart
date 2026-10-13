import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// State the runner reports about the window.
@immutable
class WindowState {
  const WindowState({this.maximized = false, this.active = true, this.reducedMotion = false, this.keepOnTop = false});

  final bool maximized;
  final bool active;

  /// Windows "Animation effects" is off. Flutter's Windows embedder does not
  /// report it, so the runner does (SPI_GETCLIENTAREAANIMATION).
  final bool reducedMotion;
  final bool keepOnTop;

  WindowState copyWith({bool? maximized, bool? active, bool? reducedMotion, bool? keepOnTop}) => WindowState(
    maximized: maximized ?? this.maximized,
    active: active ?? this.active,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    keepOnTop: keepOnTop ?? this.keepOnTop,
  );

  @override
  bool operator ==(Object other) =>
      other is WindowState &&
      other.maximized == maximized &&
      other.active == active &&
      other.reducedMotion == reducedMotion &&
      other.keepOnTop == keepOnTop;

  @override
  int get hashCode => Object.hash(maximized, active, reducedMotion, keepOnTop);
}

/// A window's outer rectangle in physical screen pixels (C7
/// `DesktopWindowBounds`).
typedef WindowBounds = ({int x, int y, int width, int height});

/// The app's own window: chrome actions, ownership and state. The Windows
/// runner implements it (windows/runner/flutter_window.cpp); tests use
/// [FakeWindowController].
abstract interface class WindowController {
  /// Applies placement before the first frame. [ownerHwnd] makes the popup an
  /// owned window centred on VEGAS's dialog. [bounds] and [maximized] restore
  /// the desktop window where it was (clamped to a current monitor; ignored if
  /// that monitor is gone). Returns whether the owner was set.
  Future<bool> configure({int? ownerHwnd, bool? keepOnTop, WindowBounds? bounds, bool? maximized});

  /// Where the window is when restored, and whether it is maximized; null
  /// outside the Windows runner.
  Future<({WindowBounds bounds, bool maximized})?> restoredBounds();
  Future<WindowState> state();
  Stream<WindowState> get changes;
  Future<void> startDrag();
  Future<void> minimize();
  Future<void> toggleMaximize();

  /// Asks to close; the framework's exit request runs first, so unsaved
  /// changes can still ask.
  Future<void> close();
  Future<void> setKeepOnTop(bool value);

  /// The Windows Open dialog for one existing file, modal to this window.
  /// Returns the chosen path, or null if cancelled. The app only passes the
  /// path on to ve_services; it reads no file itself.
  Future<String?> pickFile({required String title, required String filterName, required String filterPattern});

  /// Adds a line to the startup trace (VEGAS_ENCODER_STARTUP_TRACE).
  Future<void> trace(String label);
}

class MethodChannelWindowController implements WindowController {
  MethodChannelWindowController() {
    _channel.setMethodCallHandler(_onCall);
  }

  static const MethodChannel _channel = MethodChannel('vegas_encoder/window');

  final StreamController<WindowState> _changes = StreamController<WindowState>.broadcast();
  WindowState _last = const WindowState();

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method != 'windowEvent') return;
    final args = (call.arguments as Map).cast<String, Object?>();
    final value = args['value'] == true;
    _last = switch (args['type']) {
      'maximized' => _last.copyWith(maximized: value),
      'active' => _last.copyWith(active: value),
      'reducedMotion' => _last.copyWith(reducedMotion: value),
      _ => _last,
    };
    _changes.add(_last);
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // not running in the Windows runner (tests, tools)
    }
  }

  @override
  Future<bool> configure({int? ownerHwnd, bool? keepOnTop, WindowBounds? bounds, bool? maximized}) async {
    final result = await _invoke<Map<Object?, Object?>>('configure', {
      'ownerHwnd': ?ownerHwnd,
      'keepOnTop': ?keepOnTop,
      if (bounds != null) 'bounds': {'x': bounds.x, 'y': bounds.y, 'width': bounds.width, 'height': bounds.height},
      'maximized': ?maximized,
    });
    return result?['ownerSet'] == true;
  }

  @override
  Future<({WindowBounds bounds, bool maximized})?> restoredBounds() async {
    final m = await _invoke<Map<Object?, Object?>>('getBounds');
    if (m == null) return null;
    final (x, y, w, h) = (m['x'], m['y'], m['width'], m['height']);
    if (x is! int || y is! int || w is! int || h is! int || w <= 0 || h <= 0) return null;
    return (bounds: (x: x, y: y, width: w, height: h), maximized: m['maximized'] == true);
  }

  @override
  Future<WindowState> state() async {
    final m = await _invoke<Map<Object?, Object?>>('getState');
    if (m == null) return _last;
    _last = WindowState(
      maximized: m['maximized'] == true,
      active: m['active'] == true,
      reducedMotion: m['reducedMotion'] == true,
      keepOnTop: m['keepOnTop'] == true,
    );
    return _last;
  }

  @override
  Stream<WindowState> get changes => _changes.stream;

  @override
  Future<void> startDrag() => _invoke<void>('startDrag');

  @override
  Future<void> minimize() => _invoke<void>('minimize');

  @override
  Future<void> toggleMaximize() => _invoke<void>('toggleMaximize');

  @override
  Future<void> close() => _invoke<void>('close');

  @override
  Future<void> setKeepOnTop(bool value) async {
    await _invoke<void>('setKeepOnTop', {'value': value});
    _last = _last.copyWith(keepOnTop: value);
    _changes.add(_last);
  }

  @override
  Future<String?> pickFile({required String title, required String filterName, required String filterPattern}) =>
      _invoke<String>('pickFile', {'title': title, 'filterName': filterName, 'filterPattern': filterPattern});

  @override
  Future<void> trace(String label) => _invoke<void>('trace', {'label': label});
}

/// Records calls; used by widget tests.
class FakeWindowController implements WindowController {
  FakeWindowController([this._state = const WindowState(), this.restored]);

  WindowState _state;
  final List<String> calls = [];

  /// What [restoredBounds] reports.
  ({WindowBounds bounds, bool maximized})? restored;

  /// What [pickFile] returns: the path "chosen" in the Open dialog.
  String? pickedFile;
  final StreamController<WindowState> _changes = StreamController<WindowState>.broadcast();

  void emit(WindowState state) {
    _state = state;
    _changes.add(state);
  }

  @override
  Future<bool> configure({int? ownerHwnd, bool? keepOnTop, WindowBounds? bounds, bool? maximized}) async {
    calls.add(
      'configure(owner: $ownerHwnd, keepOnTop: $keepOnTop'
      '${bounds == null ? '' : ', bounds: $bounds, maximized: $maximized'})',
    );
    return ownerHwnd != null;
  }

  @override
  Future<({WindowBounds bounds, bool maximized})?> restoredBounds() async => restored;

  @override
  Future<WindowState> state() async => _state;

  @override
  Stream<WindowState> get changes => _changes.stream;

  @override
  Future<void> startDrag() async => calls.add('startDrag');

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<void> toggleMaximize() async {
    calls.add('toggleMaximize');
    emit(_state.copyWith(maximized: !_state.maximized));
  }

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> setKeepOnTop(bool value) async {
    calls.add('setKeepOnTop($value)');
    emit(_state.copyWith(keepOnTop: value));
  }

  @override
  Future<String?> pickFile({required String title, required String filterName, required String filterPattern}) async {
    calls.add('pickFile($filterPattern)');
    return pickedFile;
  }

  @override
  Future<void> trace(String label) async => calls.add('trace($label)');
}
