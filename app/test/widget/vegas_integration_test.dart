import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/design/components/button.dart';
import 'package:vegas_encoder/features/settings/vegas_integration.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';
import '../vegas_installation_fixtures.dart';

class _Deferred implements VegasInstallations {
  Completer<VegasInstallationSnapshot> pending = Completer();
  int calls = 0;
  @override
  Future<VegasInstallationSnapshot> inspect() {
    calls++;
    return pending.future;
  }
}

Future<void> openSettings(WidgetTester tester, VegasInstallations service, {bool settle = true}) async {
  await pumpApp(
    tester,
    overrides: [
      windowControllerProvider.overrideWithValue(FakeWindowController()),
      vegasInstallationsProvider.overrideWithValue(service),
    ],
  );
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  await tester.ensureVisible(find.byType(VegasIntegrationCard));
  await tester.pump();
}

void main() {
  testWidgets('Settings shows hosts independently, paths and precise verification scope', (tester) async {
    final service = FakeVegasInstallations(
      snapshot: VegasInstallationSnapshot(
        hosts: [
          vegasHostFixture(VegasInstallationState.verified),
          vegasHostFixture(VegasInstallationState.unverified, older: true),
        ],
        errors: const ['Cannot open registry key (Windows error 5): HKCU\\Software'],
      ),
    );
    await openSettings(tester, service);
    expect(service.inspections, 1);
    expect(find.text('Installed, verified'), findsOneWidget);
    expect(find.text('Installed, unverified'), findsOneWidget);
    expect(find.textContaining('This host is not qualified'), findsOneWidget);
    expect(find.textContaining('Shared app/runtime integrity'), findsOneWidget);
    expect(find.textContaining('Discovery could not complete'), findsOneWidget);
    await tester.ensureVisible(find.text('Show paths and details').first);
    await tester.tap(find.text('Show paths and details').first);
    await tester.pumpAndSettle();
    expect(find.text(vegasHostFixture(VegasInstallationState.verified).manifestPath), findsOneWidget);
    expect(find.textContaining('bytes match the installed manifest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh loading and failure remove stale verified status; retry recovers', (tester) async {
    final service = _Deferred();
    await openSettings(tester, service, settle: false);
    expect(find.text('Checking VEGAS installations…'), findsOneWidget);
    final refresh = find.byWidgetPredicate((w) => w is VeButton && w.semanticLabel == 'Refresh VEGAS installations');
    expect(tester.widget<VeButton>(refresh).onPressed, isNull);
    service.pending.complete(VegasInstallationSnapshot(hosts: [vegasHostFixture(VegasInstallationState.verified)]));
    await tester.pumpAndSettle();
    expect(find.text('Installed, verified'), findsOneWidget);
    service.pending = Completer();
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await tester.pump();
    expect(find.text('Installed, verified'), findsNothing);
    expect(find.text('Checking VEGAS installations…'), findsOneWidget);
    service.pending.completeError(const ServiceException('VEGAS-STATUS', 'Access denied to host registration.'));
    await tester.pumpAndSettle();
    expect(find.text('Could not check VEGAS installations.'), findsOneWidget);
    expect(find.text('Access denied to host registration.'), findsOneWidget);
    service.pending = Completer();
    await tester.tap(refresh);
    await tester.pump();
    service.pending.complete(const VegasInstallationSnapshot());
    await tester.pumpAndSettle();
    expect(find.text('No registered VEGAS installations found.'), findsOneWidget);
    expect(find.text('Could not check VEGAS installations.'), findsNothing);
    expect(service.calls, 3);
  });

  testWidgets('changed and unreadable installations expose actionable details', (tester) async {
    for (final state in [VegasInstallationState.changed, VegasInstallationState.unreadable]) {
      final host = vegasHostFixture(state);
      await openSettings(tester, FakeVegasInstallations(snapshot: VegasInstallationSnapshot(hosts: [host])));
      await tester.ensureVisible(find.text('Show paths and details'));
      await tester.tap(find.text('Show paths and details'));
      await tester.pumpAndSettle();
      expect(find.text(host.details.single), findsOneWidget);
      expect(find.text(host.exporterPath), findsOneWidget);
      expect(find.text('Installed, verified'), findsNothing);
      // Dispose the prior provider container before the next fixture.
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
