import 'package:flutter/material.dart';

import 'skin.dart';

class Skins {
  /// Default skin. Pro skins join this list in Phase 6.
  static const graphite = Skin(
    id: 'graphite',
    label: 'GRAPHITE',
    night: SurfaceTokens(
      bg: Color(0xFF1B1B1B),
      bgShade: Color(0xFF141414),
      glyphFace: Color(0xFF1E1E1E),
      glyphBevelLight: Color(0x2EFFFFFF),
      glyphBevelDark: Color(0x66000000),
      glyphSide: Color(0xFF101010),
      castShadow: Color(0xA0000000),
      litFace: Color(0xFFF2F2F2),
      litSide: Color(0xFF9A9A9A),
      speedLine: Color(0xFFFFFFFF),
      ink: Color(0xFFEDEDED),
      inkSoft: Color(0xFF8A8A8A),
    ),
    paper: SurfaceTokens(
      bg: Color(0xFFF4F4F2),
      bgShade: Color(0xFFE6E6E3),
      glyphFace: Color(0xFF1C1C1C),
      glyphBevelLight: Color(0x33FFFFFF),
      glyphBevelDark: Color(0x80000000),
      glyphSide: Color(0xFF0A0A0A),
      castShadow: Color(0x33000000),
      litFace: Color(0xFF1C1C1C),
      litSide: Color(0xFF0A0A0A),
      speedLine: Color(0xFF111111),
      ink: Color(0xFF111111),
      inkSoft: Color(0xFF6B6B6B),
    ),
  );

  /// Pop Calc's Sunny marigold: the running numeral is dark espresso on
  /// gold, idle numerals are gold-on-gold.
  static const andy = Skin(
    id: 'andy',
    label: 'ANDY',
    night: SurfaceTokens(
      bg: Color(0xFFFFAE00),
      bgShade: Color(0xFFF09E00),
      glyphFace: Color(0xFFFFB000),
      glyphBevelLight: Color(0x66FFE6A0),
      glyphBevelDark: Color(0x40000000),
      glyphSide: Color(0xFFD48A00),
      castShadow: Color(0x40502A00),
      litFace: Color(0xFF221A12),
      litSide: Color(0xFF6A4A26),
      speedLine: Color(0xFF221A12),
      ink: Color(0xFF140F0B),
      inkSoft: Color(0xFF2E1C0A),
    ),
    paper: SurfaceTokens(
      bg: Color(0xFFFFF4D6),
      bgShade: Color(0xFFF5E6BC),
      glyphFace: Color(0xFF221A12),
      glyphBevelLight: Color(0x33FFFFFF),
      glyphBevelDark: Color(0x80000000),
      glyphSide: Color(0xFF483220),
      castShadow: Color(0x33502A00),
      litFace: Color(0xFF221A12),
      litSide: Color(0xFF483220),
      speedLine: Color(0xFF221A12),
      ink: Color(0xFF140F0B),
      inkSoft: Color(0xFF6B5030),
    ),
  );

  static const all = [graphite, andy];

  static Skin byId(String? id) => all.firstWhere((s) => s.id == id, orElse: () => graphite);
}
