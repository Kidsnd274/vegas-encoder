import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/features/settings/vegas_integration.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';
import '../vegas_installation_fixtures.dart';

class _Loading implements VegasInstallations {
  final pending = Completer<VegasInstallationSnapshot>();
  @override
  Future<VegasInstallationSnapshot> inspect() => pending.future;
}

void main() {
  for (final brightness in themes) {
    for (final name in [
      'verified',
      'unverified',
      'changed',
      'unreadable',
      'notInstalled',
      'empty',
      'partial',
      'error',
      'loading',
    ]) {
      testWidgets('VEGAS $name ${themeName(brightness)}', (tester) async {
        VegasInstallations service;
        final state = VegasInstallationState.values.where((s) => s.name == name).firstOrNull;
        if (name == 'loading') {
          service = _Loading();
        } else {
          final fake = FakeVegasInstallations(
            snapshot: VegasInstallationSnapshot(
              hosts: state == null ? const [] : [vegasHostFixture(state, older: name == 'unverified')],
              errors: name == 'partial' ? const ['Cannot inspect directory (Windows error 5): D:\\VEGAS'] : const [],
            ),
          );
          if (name == 'error') {
            fake.error = const ServiceException('VEGAS-STATUS', 'Cannot inspect VEGAS registration (Windows error 5).');
          }
          service = fake;
        }
        await pumpThemed(
          tester,
          ProviderScope(
            overrides: [vegasInstallationStatusProvider.overrideWith((ref) => service.inspect())],
            child: const VegasIntegrationCard(),
          ),
          brightness: brightness,
          width: 720,
          view: const Size(800, 1100),
        );
        if (state != null) {
          await tester.tap(find.text('Show paths and details'));
          await tester.pumpAndSettle();
        }
        await expectGolden('vegas_${name}_${themeName(brightness)}');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
