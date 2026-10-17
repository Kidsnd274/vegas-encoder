import 'package:flutter/widgets.dart';

import '../../design/components/message.dart';
import '../../state/popup_version.dart';

/// A mismatch warns without changing Apply or the native prelaunch check.
class PopupVersionWarning extends StatelessWidget {
  const PopupVersionWarning({super.key, required this.status});

  final PopupVersionStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.match == PopupVersionMatch.matching) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: VeMessage(
        level: VeLevel.warning,
        text:
            '${status.match == PopupVersionMatch.mismatched ? 'Vegas Encoder versions don’t match.' : 'Vegas Encoder couldn’t verify the versions.'} '
            '${status.details}',
        fix: 'Install the app and plug-in from the same release before rendering.',
      ),
    );
  }
}
