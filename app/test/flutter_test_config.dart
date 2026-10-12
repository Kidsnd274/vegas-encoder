import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// `flutter test` runs with test fonts only. Load the bundled OFL fonts so
/// golden images show Instrument Sans and JetBrains Mono as the app does.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ui = FontLoader('Instrument Sans')
    ..addFont(rootBundle.load('assets/fonts/InstrumentSans/InstrumentSans-Variable.ttf'));
  final mono = FontLoader('JetBrains Mono')
    ..addFont(rootBundle.load('assets/fonts/JetBrainsMono/JetBrainsMono-Variable.ttf'))
    ..addFont(rootBundle.load('assets/fonts/JetBrainsMono/JetBrainsMono-Italic-Variable.ttf'));
  await Future.wait([ui.load(), mono.load()]);
  await testMain();
}
