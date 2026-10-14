import 'package:flutter/widgets.dart';
import 'package:ve_services/ve_services.dart' show CoreException;

import '../../design/icons.dart';
import '../../design/tokens.dart';

/// Shown in place of the desktop's screens when the product core didn't load
/// (`NATIVE-LOAD`, `ABI-MISMATCH`, …). Every screen builds on the core's
/// profiles and results, and nothing falls back to the fake core.
class CoreUnavailable extends StatelessWidget {
  const CoreUnavailable({super.key, required this.error});
  final CoreException error;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VeSpace.s5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(VeRadius.xl),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: VeIcon(VeIcons.error, color: c.error),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vegas Encoder couldn’t load its core', style: t.text.panelTitle),
                        const SizedBox(height: 6),
                        Text(
                          'The core builds the FFmpeg command, checks settings and works out sizes, so presets '
                          'can’t open without it. Reinstalling Vegas Encoder restores it.',
                          style: t.text.body.copyWith(color: c.text2),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${error.code}: ${error.message}',
                          style: t.text.mono.copyWith(fontSize: 12.5, height: 1.4, color: c.text2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
