import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/design/components/message.dart';
import 'package:vegas_encoder/features/popup/popup_version.dart';
import 'package:vegas_encoder/state/popup_version.dart';

import '../helpers.dart';

void main() {
  const mismatched = PopupVersionStatus(
    dllVersion: '0.1.7-recipe-proof',
    coreVersion: '0.2.0-b2',
    appVersion: '0.1.8+1',
    appCoreVersion: '0.2.0-b3',
  );

  for (final brightness in themes) {
    testWidgets('popup_version_${themeName(brightness)}', (tester) async {
      await pumpThemed(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [PopupVersionWarning(status: mismatched)],
        ),
        width: 928,
        brightness: brightness,
      );
      expect(find.textContaining('Vegas Encoder versions don’t match.'), findsOneWidget);
      expect(find.text('Install the app and plug-in from the same release before rendering.'), findsOneWidget);
      await expectGolden('popup_version_${themeName(brightness)}');
    });
  }

  testWidgets('matching versions have no warning, and unavailable stamps explain the uncertainty', (tester) async {
    await pumpThemed(
      tester,
      const PopupVersionWarning(
        status: PopupVersionStatus(
          dllVersion: '0.1.7-recipe-proof',
          coreVersion: '0.2.0-b2',
          appVersion: '0.1.7+1',
          appCoreVersion: '0.2.0-b2',
        ),
      ),
    );
    expect(find.byType(VeMessage), findsNothing);
    await pumpThemed(
      tester,
      const PopupVersionWarning(
        status: PopupVersionStatus(
          dllVersion: '0.1.7-recipe-proof',
          coreVersion: '0.2.0-b2',
          appVersion: null,
          appCoreVersion: '0.2.0-b2',
        ),
      ),
    );
    expect(find.textContaining('couldn’t verify the versions.'), findsOneWidget);
    expect(find.textContaining('app: unavailable'), findsOneWidget);
  });
}
