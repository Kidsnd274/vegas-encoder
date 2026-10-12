import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/segmented.dart';
import '../../design/components/signal_path/signal_path.dart';
import '../../design/tokens.dart';
import '../../state/app_state.dart';
import 'gallery_sections.dart';
import 'samples.dart';

/// The design system on one page (F1). Uses local sample data only; the
/// Presets screen replaces it in F2.
class GalleryPage extends ConsumerWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VeTokens.of(context);
    final c = t.colors;
    const gap = SizedBox(height: VeSpace.s4);
    return ColoredBox(
      color: c.paper,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Design system', style: t.text.headline),
                    const SizedBox(height: 3),
                    Text(
                      'Signal Flow components with sample data. The Presets screen replaces this page in F2.',
                      style: t.text.small.copyWith(color: c.text2),
                    ),
                  ],
                ),
              ),
              Text('Theme', style: t.text.small.copyWith(color: c.text2)),
              const SizedBox(width: 10),
              VeSegmented<ThemePreference>(
                semanticLabel: 'Theme',
                segments: [for (final p in ThemePreference.values) VeSegment(p, p.label)],
                selected: ref.watch(themePreferenceProvider),
                onChanged: (p) => ref.read(themePreferenceProvider.notifier).set(p),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SignalPathSection(),
          gap,
          const FileAndCommandSection(),
          gap,
          const StripSection(),
          gap,
          const PickersSection(),
          gap,
          const SlidersSection(),
          gap,
          const ChoicesSection(),
          gap,
          const InputsSection(),
          gap,
          const ButtonsSection(),
          gap,
          const MessagesSection(),
          gap,
          const SignalPathSection(
            model: Samples.hevcMaster,
            title: 'Signal path: no video conversion, failed hardware encoder',
            note: 'A 10-bit encode keeps the wire thick. FLAC stores integers, so the audio wire gets a pip.',
            initial: SignalNode.video,
          ),
          gap,
          const SignalPathSection(
            model: Samples.audioOffBadMux,
            title: 'Signal path: audio off, container can’t hold the codec',
            note: 'The audio path is gone; the wire into WebM turns red and dashed.',
            initial: SignalNode.container,
          ),
          gap,
          const SignalPathSection(
            model: Samples.fromCommand,
            title: 'Signal path: Advanced mode',
            note: 'Nodes are read back from the command and drawn dashed.',
            initial: SignalNode.video,
          ),
          gap,
          const TokensSection(),
        ],
      ),
    );
  }
}
