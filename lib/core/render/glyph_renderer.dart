import 'dart:ui';

import '../theme/skin.dart';

/// Colors for one sculpted numeral. Animations lerp between the idle and lit
/// materials of a surface.
class GlyphMaterial {
  final Color face;
  final Color side;
  final Color bevelLight;
  final Color bevelDark;
  final Color castShadow;

  const GlyphMaterial({
    required this.face,
    required this.side,
    required this.bevelLight,
    required this.bevelDark,
    required this.castShadow,
  });

  factory GlyphMaterial.idle(SurfaceTokens t) => GlyphMaterial(
    face: t.glyphFace,
    side: t.glyphSide,
    bevelLight: t.glyphBevelLight,
    bevelDark: t.glyphBevelDark,
    castShadow: t.castShadow,
  );

  factory GlyphMaterial.lit(SurfaceTokens t) => GlyphMaterial(
    face: t.litFace,
    side: t.litSide,
    bevelLight: t.glyphBevelLight,
    bevelDark: t.glyphBevelDark,
    castShadow: t.castShadow,
  );

  static GlyphMaterial lerp(GlyphMaterial a, GlyphMaterial b, double t) =>
      GlyphMaterial(
        face: Color.lerp(a.face, b.face, t)!,
        side: Color.lerp(a.side, b.side, t)!,
        bevelLight: Color.lerp(a.bevelLight, b.bevelLight, t)!,
        bevelDark: Color.lerp(a.bevelDark, b.bevelDark, t)!,
        castShadow: Color.lerp(a.castShadow, b.castShadow, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is GlyphMaterial &&
      other.face == face &&
      other.side == side &&
      other.bevelLight == bevelLight &&
      other.bevelDark == bevelDark &&
      other.castShadow == castShadow;

  @override
  int get hashCode => Object.hash(face, side, bevelLight, bevelDark, castShadow);
}

/// Default key light: top-left, so the block and shadow fall toward the
/// bottom-right, as in Pop Calc.
const Offset defaultLightDir = Offset(-0.5571, -0.8305);

abstract interface class GlyphRenderer {
  void paint(
    Canvas canvas,
    Size size, {
    required String text,
    required GlyphMaterial material,
    required double depth,
    Offset lightDir,
    bool lite,
  });
}
