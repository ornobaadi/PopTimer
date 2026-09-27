import 'package:flutter_test/flutter_test.dart';
import 'package:poptimer/core/render/glyph_paths.dart';

void main() {
  const glyphs = '0123456789+';

  test('every digit and + has a shape', () {
    for (final g in glyphs.split('')) {
      expect(glyphShapes[g], isNotNull, reason: g);
    }
  });

  test('outlines stay inside the grid cell', () {
    for (final g in glyphs.split('')) {
      final shape = glyphShapes[g]!;
      for (final c in shape.contours) {
        for (final p in c.points) {
          expect(p.dx, inInclusiveRange(0, shape.advance), reason: g);
          expect(p.dy, inInclusiveRange(0, glyphUnitHeight), reason: g);
        }
      }
    }
  });

  test('material normals point into the glyph', () {
    for (final g in glyphs.split('')) {
      final shape = glyphShapes[g]!;
      final path = contoursToPath(shape.contours);
      for (final c in shape.contours) {
        final normals = materialNormals(c);
        for (var i = 0; i < c.points.length; i++) {
          final mid = (c.points[i] + c.points[(i + 1) % c.points.length]) / 2;
          expect(path.contains(mid + normals[i] * 0.5), isTrue, reason: '$g edge $i');
          expect(path.contains(mid - normals[i] * 0.5), isFalse, reason: '$g edge $i');
        }
      }
    }
  });

  test('chamfer inset lands inside the material', () {
    for (final g in glyphs.split('')) {
      final shape = glyphShapes[g]!;
      final path = contoursToPath(shape.contours);
      for (final c in shape.contours) {
        for (final p in insetContour(c, shape.bevel)) {
          expect(path.contains(p), isTrue, reason: '$g inset $p');
        }
      }
    }
  });

  test('top edge of 0 faces up, so the key light catches it', () {
    final outline = glyphShapes['0']!.contours.first;
    // Edge 0 runs along the top from (6, 0) to (22, 0).
    expect(-materialNormals(outline)[0], const Offset(0, -1));
  });

  test('layout adds a gap between glyphs', () {
    expect(layoutGlyphs('1').width, 28);
    expect(layoutGlyphs('10').width, 28 + glyphGap + 28);
    expect(layoutGlyphs('+').width, 60);
    expect(layoutGlyphs('1:0').width, layoutGlyphs('10').width);
  });
}
