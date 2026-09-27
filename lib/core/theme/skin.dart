import 'package:flutter/material.dart';

/// Night hosts Browse and the running timer; Paper hosts the stopwatch and
/// the done state. They invert each other.
enum Surface { night, paper }

/// Colors for one surface (`design.md` section 2).
class SurfaceTokens {
  final Color bg;
  final Color bgShade;
  final Color glyphFace;
  final Color glyphBevelLight;
  final Color glyphBevelDark;
  final Color glyphSide;
  final Color castShadow;

  /// Running numeral. Paper numerals never light up, so Paper reuses its
  /// idle face and side here.
  final Color litFace;
  final Color litSide;
  final Color speedLine;
  final Color ink;
  final Color inkSoft;

  const SurfaceTokens({
    required this.bg,
    required this.bgShade,
    required this.glyphFace,
    required this.glyphBevelLight,
    required this.glyphBevelDark,
    required this.glyphSide,
    required this.castShadow,
    required this.litFace,
    required this.litSide,
    required this.speedLine,
    required this.ink,
    required this.inkSoft,
  });

  Brightness get brightness =>
      ThemeData.estimateBrightnessForColor(bg);
}

/// A skin defines both surfaces.
class Skin {
  final String id;
  final String label;
  final SurfaceTokens night;
  final SurfaceTokens paper;

  const Skin({
    required this.id,
    required this.label,
    required this.night,
    required this.paper,
  });

  SurfaceTokens surface(Surface s) => s == Surface.night ? night : paper;
}
