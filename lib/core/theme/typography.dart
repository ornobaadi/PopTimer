import 'package:flutter/painting.dart';

/// Text styles shared with Pop Calc: Bebas Neue for labels and hints,
/// Antonio for descriptions and the countdown line (`architecture.md` 12).
class AppType {
  static const labelFamily = 'BebasNeue';
  static const bodyFamily = 'Antonio';

  /// `TAP TO START`.
  static TextStyle hint(Color color) => TextStyle(
    fontFamily: labelFamily,
    fontSize: 20,
    letterSpacing: 0.5,
    height: 1,
    color: color,
  );

  /// `10:00`, `+00:03:16`. Tabular so the line never jiggles.
  static TextStyle countdown(Color color) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    fontVariations: const [FontVariation('wght', 500)],
    fontFeatures: const [FontFeature.tabularFigures()],
    letterSpacing: 0.5,
    height: 1.1,
    color: color,
  );
}
