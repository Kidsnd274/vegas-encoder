import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ve_core/ve_core.dart';

void main() {
  test('built core reports the central version and compatibility fields', () {
    final manifest = jsonDecode(File('../version.json').readAsStringSync()) as Map<String, dynamic>;
    final expected = manifest['core'] as Map<String, dynamic>;
    final actual = NativeVeCore().version;
    expect(actual.core, expected['version']);
    expect(actual.abi, expected['abi']);
    expect(actual.schemaMax, expected['schemaMax']);
    expect(actual.contracts, expected['contracts']);
    expect(actual.isFake, isFalse);
  });
}
