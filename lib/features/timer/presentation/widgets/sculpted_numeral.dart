import 'package:flutter/material.dart';

import '../../../../core/render/glyph_renderer.dart';
import '../../../../core/render/procedural_glyph_renderer.dart';

/// One renderer for the whole app so its picture cache is shared by the
/// pager pages and the session view.
final GlyphRenderer _sharedRenderer = ProceduralGlyphRenderer();

/// A giant sculpted numeral (`0`–`999` or `+`) filling its box's height.
/// Decorative: callers expose the value through Semantics.
class SculptedNumeral extends StatelessWidget {
  final String text;
  final GlyphMaterial material;
  final double depth;
  final bool lite;
  final Offset lightDir;

  const SculptedNumeral({
    super.key,
    required this.text,
    required this.material,
    this.depth = 1,
    this.lite = false,
    this.lightDir = defaultLightDir,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _NumeralPainter(
            renderer: _sharedRenderer,
            text: text,
            material: material,
            depth: depth,
            lite: lite,
            lightDir: lightDir,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
        ),
      ),
    );
  }
}

class _NumeralPainter extends CustomPainter {
  final GlyphRenderer renderer;
  final String text;
  final GlyphMaterial material;
  final double depth;
  final bool lite;
  final Offset lightDir;
  final double devicePixelRatio;

  _NumeralPainter({
    required this.renderer,
    required this.text,
    required this.material,
    required this.depth,
    required this.lite,
    required this.lightDir,
    required this.devicePixelRatio,
  });

  @override
  void paint(Canvas canvas, Size size) => renderer.paint(
    canvas,
    size,
    text: text,
    material: material,
    depth: depth,
    lite: lite,
    lightDir: lightDir,
    devicePixelRatio: devicePixelRatio,
  );

  @override
  bool shouldRepaint(covariant _NumeralPainter old) =>
      old.text != text ||
      old.material != material ||
      old.depth != depth ||
      old.lite != lite ||
      old.devicePixelRatio != devicePixelRatio ||
      old.lightDir != lightDir;
}
