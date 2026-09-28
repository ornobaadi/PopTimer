import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';

import 'glyph_paths.dart';
import 'glyph_renderer.dart';

/// Paints sculpted numerals from the polygons in `glyph_paths.dart`, grown
/// out of Pop Calc's `ExtrudedNumberPainter` with a real light model
/// (`design.md` section 5):
///
/// 1. long cast shadow swept toward the bottom-left, blurred
/// 2. extruded side walls, one quad per outline edge, shaded by normal
/// 3. front face with a faint top-lit gradient
/// 4. chamfer facets, lit or shaded by which way each edge faces the light
///
/// Each finished glyph (shadow, blur and all) is rasterised once into a GPU
/// image at device resolution and cached, so every later frame, whether
/// paging, animating, dragging or tilting, is a single image blit. Motion
/// happens in widget transforms, never by re-rendering.
class ProceduralGlyphRenderer implements GlyphRenderer {
  ProceduralGlyphRenderer({this.cacheSize = 12});

  final int cacheSize;
  // Map literals keep insertion order, so the first key is the oldest.
  final _cache = <String, _Baked>{};

  /// Share of the box width a numeral may use before it shrinks.
  static const double maxWidthFraction = 0.84;

  /// Rasterisation cap: sharper than this is invisible at numeral sizes and
  /// just costs memory.
  static const double maxPixelRatio = 2.5;

  @override
  void paint(
    Canvas canvas,
    Size size, {
    required String text,
    required GlyphMaterial material,
    required double depth,
    Offset lightDir = defaultLightDir,
    bool lite = false,
    double devicePixelRatio = 1,
  }) {
    if (text.isEmpty || size.isEmpty) return;
    final ratio = math.min(devicePixelRatio, maxPixelRatio);
    final key = [
      text,
      size.width.round(),
      size.height.round(),
      ratio,
      material.hashCode,
      (depth * 20).round(), // 5% steps: depth is only animated rarely
      lightDir.dx.toStringAsFixed(2),
      lightDir.dy.toStringAsFixed(2),
      lite,
    ].join('|');

    var baked = _cache.remove(key);
    if (baked == null) {
      baked = _bake(size, ratio, text, material, (depth * 20).round() / 20, lightDir, lite);
      if (_cache.length >= cacheSize) {
        _cache.remove(_cache.keys.first)?.image.dispose();
      }
    }
    _cache[key] = baked;
    canvas.drawImageRect(
      baked.image,
      Rect.fromLTWH(0, 0, baked.image.width.toDouble(), baked.image.height.toDouble()),
      baked.bounds,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  /// Renders into an image large enough for the shadow spilling past [size].
  _Baked _bake(
    Size size,
    double ratio,
    String text,
    GlyphMaterial m,
    double depth,
    Offset lightDir,
    bool lite,
  ) {
    final h = size.height;
    final light = _normalize(lightDir);
    final shadow = _normalize(Offset(-light.dx * 0.78, -light.dy)) * h * 0.3;
    final pad = h * 0.08;
    final left = pad + math.max(0.0, -shadow.dx);
    final right = pad + math.max(0.0, shadow.dx);
    final top = pad + math.max(0.0, -shadow.dy);
    final bottom = pad + math.max(0.0, shadow.dy);
    final bounds = Rect.fromLTWH(-left, -top, size.width + left + right, h + top + bottom);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(ratio)
      ..translate(left, top);
    _draw(canvas, size, text, m, depth, lightDir, lite);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (bounds.width * ratio).ceil(),
      (bounds.height * ratio).ceil(),
    );
    picture.dispose();
    return _Baked(image, bounds);
  }

  void _draw(
    Canvas canvas,
    Size size,
    String text,
    GlyphMaterial m,
    double depth,
    Offset lightDir,
    bool lite,
  ) {
    final run = layoutGlyphs(text);
    if (run.contours.isEmpty) return;

    final scale = math.min(
      size.height / glyphUnitHeight,
      size.width * maxWidthFraction / run.width,
    );
    final glyphH = glyphUnitHeight * scale;
    final light = _normalize(lightDir);

    // Extrusion and shadow fall away from the light; the shadow a little
    // steeper, matching the references' (-0.35, 0.45).
    final extrude = _normalize(-light) * glyphH * 0.045 * depth;
    final shadow = _normalize(Offset(-light.dx * 0.78, -light.dy)) * glyphH * 0.28 * depth;

    // Center the glyph, nudged against the extrusion so the whole block
    // reads as centered.
    final origin = Offset(
      (size.width - run.width * scale) / 2 - extrude.dx / 2,
      (size.height - glyphH) / 2 - extrude.dy / 2,
    );
    final contours = [for (final c in run.contours) c.scale(scale).shift(origin)];
    final facePath = contoursToPath(contours);
    final normals = [for (final c in contours) materialNormals(c)];

    // 1. Cast shadow: the outline swept along [shadow], as one opaque union
    //    inside a single translucent (and, outside Lite, blurred) layer.
    if (depth > 0.01) {
      final alpha = lite ? 0.3 : m.castShadow.a;
      final layer = Paint()..color = Color.fromRGBO(0, 0, 0, alpha);
      if (!lite) {
        final sigma = glyphH * 0.018;
        layer.imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
      }
      canvas.saveLayer(null, layer);
      final solid = Paint()..color = m.castShadow.withValues(alpha: 1);
      canvas.drawPath(contoursToPath(contours, shift: shadow), solid);
      for (final c in contours) {
        _sweep(canvas, c.points, shadow, solid);
      }
      canvas.restore();
    }

    // 2. Side walls: only edges facing the extrusion direction are visible.
    if (extrude.distance > 0.1) {
      final dir = _normalize(extrude);
      for (var ci = 0; ci < contours.length; ci++) {
        final pts = contours[ci].points;
        for (var i = 0; i < pts.length; i++) {
          final outward = -normals[ci][i];
          if (_dot(outward, dir) <= 0) continue;
          final a = pts[i];
          final b = pts[(i + 1) % pts.length];
          // Walls facing the light catch a little of it.
          final lit = _dot(outward, light).clamp(-1.0, 1.0);
          final color = lit > 0
              ? Color.lerp(m.side, m.face, lit * 0.18)!
              : Color.lerp(m.side, const Color(0xFF000000), -lit * 0.35)!;
          canvas.drawPath(
            Path()..addPolygon([a, b, b + extrude, a + extrude], true),
            Paint()..color = color,
          );
        }
      }
    }

    // 3. Front face, a touch lighter at the top.
    final bounds = facePath.getBounds();
    canvas.drawPath(
      facePath,
      Paint()
        ..shader = ui.Gradient.linear(bounds.topCenter, bounds.bottomCenter, [
          Color.lerp(m.face, const Color(0xFFFFFFFF), 0.035)!,
          m.face,
        ]),
    );

    // 4. Chamfer facets between each outline and its inset copy.
    for (var ci = 0; ci < contours.length; ci++) {
      final c = contours[ci];
      final inner = insetContour(c, run.bevels[ci] * scale);
      final pts = c.points;
      for (var i = 0; i < pts.length; i++) {
        final j = (i + 1) % pts.length;
        final facing = _dot(-normals[ci][i], light);
        final Color color;
        if (facing > 0.05) {
          color = m.bevelLight.withValues(alpha: m.bevelLight.a * math.min(1, facing * 1.25));
        } else if (facing < -0.05) {
          color = m.bevelDark.withValues(alpha: m.bevelDark.a * math.min(1, -facing * 1.25));
        } else {
          continue;
        }
        canvas.drawPath(
          Path()..addPolygon([pts[i], pts[j], inner[j], inner[i]], true),
          Paint()..color = color,
        );
      }
    }
  }

  /// Fills the band each edge of [pts] sweeps when moved by [by]. Every band
  /// is wound the same way so the non-zero fill is a clean union.
  static void _sweep(Canvas canvas, List<Offset> pts, Offset by, Paint paint) {
    final path = Path()..fillType = PathFillType.nonZero;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final quad = [a, b, b + by, a + by];
      path.addPolygon(signedArea2(quad) >= 0 ? quad : quad.reversed.toList(), true);
    }
    canvas.drawPath(path, paint);
  }

  static Offset _normalize(Offset o) {
    final d = o.distance;
    return d == 0 ? Offset.zero : o / d;
  }

  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
}

class _Baked {
  const _Baked(this.image, this.bounds);

  final ui.Image image;

  /// Where the image goes, relative to the numeral's box.
  final Rect bounds;
}
