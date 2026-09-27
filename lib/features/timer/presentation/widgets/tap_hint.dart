import 'package:flutter/material.dart';

import '../../../../core/theme/typography.dart';

/// `TAP TO START` with the 56 dp ring the hold gesture fills later.
class TapHint extends StatelessWidget {
  final Color ink;
  final String label;

  const TapHint({super.key, required this.ink, this.label = 'TAP TO START'});

  static const double ringSize = 56;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppType.hint(ink)),
            const SizedBox(height: 14),
            Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ink.withValues(alpha: 0.85), width: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
