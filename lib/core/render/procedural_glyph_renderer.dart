import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/animation.dart' show Curves;
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
/// Every pass is plain path filling except the shadow's one blur layer, and
/// the finished glyph is cached as a [Picture], so a static numeral (most of
/// a running timer) is a single picture replay.
class ProceduralGlyphRenderer implements GlyphRenderer {
  ProceduralGlyphRenderer({this.cacheSize = 24});

  final int cacheSize;
  // Map literals keep insertion order, so the first key is the oldest.
  final _cache = <String, ui.Picture>{};

  /// Share of the box width a numeral may use before it shrinks.
  static const double maxWidthFraction = 0.84;

  @override
  void paint(
    Canvas canvas,
    Size size, {
    required String text,
    required GlyphMaterial material,
    required double depth,
    Offset lightDir = defaultLightDir,
    bool lite = false,
  }) {
    if (text.isEmpty || size.isEmpty) return;
    final key = [
      text,
      size.width.round(),
      size.height.round(),
      material.hashCode,
      (depth * 100).round(),
      lightDir.dx.toStringAsFixed(2),
      lightDir.dy.toStringAsFixed(2),
      lite,
    ].join('|');

    var picture = _cache.remove(key);
    if (picture == null) {
      final recorder = ui.PictureRecorder();
      _draw(Canvas(recorder), size, text, material, depth, lightDir, lite);
      picture = recorder.endRecording();
      if (_cache.length >= cacheSize) {
        _cache.remove(_cache.keys.first)?.dispose();
      }
    }
    _cache[key] = picture;
    canvas.drawPicture(picture);
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
    if (text != '+') {
      _drawText(canvas, size, text, m, depth, lightDir, lite);
      return;
    }
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

  /// Bebas Neue digit height as a share of font size.
  static const double _capRatio = 0.7;

  TextPainter _painter(String text, double fontSize, {Color? color, Paint? foreground}) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontFamilyFallback: const ['Antonio'],
            fontSize: fontSize,
            height: 1,
            letterSpacing: fontSize * 0.01,
            color: foreground == null ? color : null,
            foreground: foreground,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  /// Digits the Pop Calc way: the Bebas Neue numeral extruded as a solid
  /// block (stacked layers shaded from the deep side toward the rim), a long
  /// blurred cast shadow, a top-lit face and a catch-light rim.
  void _drawText(
    Canvas canvas,
    Size size,
    String text,
    GlyphMaterial m,
    double depth,
    Offset lightDir,
    bool lite,
  ) {
    var fontSize = size.height / _capRatio;
    var probe = _painter(text, fontSize, color: m.face);
    final maxWidth = size.width * maxWidthFraction;
    if (probe.width > maxWidth) {
      fontSize *= maxWidth / probe.width;
      probe = _painter(text, fontSize, color: m.face);
    }
    final glyphH = fontSize * _capRatio;
    // Width-fitted numbers (two or three digits) are stretched back up to
    // the full height: tall, condensed Bebas, like the references.
    final stretch = (size.height / glyphH).clamp(1.0, maxStretch);
    final light = _normalize(lightDir);
    // Offsets are drawn in the stretched space, so undo the stretch on y to
    // keep the extrusion and shadow the same length in every direction.
    Offset unstretched(Offset o) => Offset(o.dx, o.dy / stretch);
    final extrude = unstretched(_normalize(-light) * glyphH * stretch * 0.06 * depth);
    final shadow = unstretched(
      _normalize(Offset(-light.dx * 0.78, -light.dy)) * glyphH * stretch * 0.2 * depth,
    );

    final baseline = probe.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final inkTop = baseline - glyphH;
    canvas.save();
    canvas.translate(0, size.height / 2);
    canvas.scale(1, stretch);
    canvas.translate(0, -size.height / 2);
    final origin = Offset(
      (size.width - probe.width) / 2 - extrude.dx / 2,
      (size.height - glyphH) / 2 - inkTop - extrude.dy / 2,
    );

    // 1. Long cast shadow: the glyph stamped along [shadow], one layer.
    if (depth > 0.01) {
      final alpha = lite ? 0.3 : m.castShadow.a;
      final layer = Paint()..color = Color.fromRGBO(0, 0, 0, alpha);
      if (!lite) {
        final sigma = glyphH * 0.02;
        layer.imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
      }
      canvas.saveLayer(null, layer);
      final stamp = _painter(text, fontSize, color: m.castShadow.withValues(alpha: 1));
      const stamps = 10;
      for (var i = 0; i <= stamps; i++) {
        stamp.paint(canvas, origin + shadow * (i / stamps));
      }
      canvas.restore();
    }

    // 2. Side walls: stacked layers from the far end to the face, darkest at
    //    the back, catching a little light near the rim. Colors are grouped
    //    so only a handful of paragraphs are laid out.
    final dist = extrude.distance;
    if (dist > 0.5) {
      final steps = lite ? 8 : (dist / 0.6).clamp(24, 64).round();
      const groups = 8;
      final rim = Color.lerp(m.side, m.face, 0.28)!;
      final deep = Color.lerp(m.side, const Color(0xFF000000), 0.35)!;
      TextPainter? layer;
      var layerGroup = -1;
      for (var i = 0; i < steps; i++) {
        final t = i / (steps - 1);
        final group = (t * (groups - 1)).round();
        if (group != layerGroup) {
          layerGroup = group;
          final c = Color.lerp(deep, rim, Curves.easeInCubic.transform(group / (groups - 1)))!;
          layer = _painter(text, fontSize, color: c);
        }
        layer!.paint(canvas, origin + extrude * (1 - t));
      }
    }

    // 3. Face, a touch lighter at the top.
    final faceRect = Rect.fromLTWH(origin.dx, origin.dy + inkTop, probe.width, glyphH);
    _painter(
      text,
      fontSize,
      foreground: Paint()
        ..shader = ui.Gradient.linear(faceRect.topCenter, faceRect.bottomCenter, [
          Color.lerp(m.face, const Color(0xFFFFFFFF), 0.05)!,
          m.face,
        ]),
    ).paint(canvas, origin);

    // 4. Catch-light rim (Pop Calc's chamfer), plus a faint shaded rim offset
    //    away from the light so edges read even on dark-on-dark.
    if (!lite) {
      final w = math.max(1.0, glyphH * 0.004);
      _painter(
        text,
        fontSize,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = m.bevelLight,
      ).paint(canvas, origin + light * (w * 0.5));
    }
    canvas.restore();
  }

  /// Most a width-fitted number is stretched vertically.
  static const double maxStretch = 1.8;

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
