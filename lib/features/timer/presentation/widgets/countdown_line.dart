import 'package:flutter/material.dart';

import '../../../../core/theme/typography.dart';

/// The small `10:00` / `+00:03:16` line under the numeral. Scales with the
/// system font (up to 200%), unlike the decorative numeral.
class CountdownLine extends StatelessWidget {
  final String text;
  final Color color;

  const CountdownLine({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 2,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppType.countdown(color),
      ),
    );
  }
}
