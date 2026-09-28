import 'dart:math' as math;
import 'dart:ui';

/// Hand-built outlines for `0`–`9` and `+`, drawn on a 100-unit-tall grid in
/// an ultra-condensed, chiseled face. Flutter can't hand us a font glyph's
/// outline, and the chamfer pass needs real polygons to light each facet, so
/// the shapes live here as the single source of truth for every render pass.

/// Grid height every glyph is drawn on.
const double glyphUnitHeight = 100;

/// Gap between glyphs in a number, in grid units.
const double glyphGap = 5;

class GlyphContour {
  final List<Offset> points;

  /// True for counters (the hole in `0`, `6`, `8`, `9`).
  final bool isHole;

  const GlyphContour(this.points, {this.isHole = false});

  GlyphContour shift(Offset by) =>
      GlyphContour([for (final p in points) p + by], isHole: isHole);

  GlyphContour scale(double s) =>
      GlyphContour([for (final p in points) p * s], isHole: isHole);
}

class GlyphShape {
  final List<GlyphContour> contours;
  final double advance;

  /// Chamfer width in grid units.
  final double bevel;

  const GlyphShape(this.contours, {required this.advance, required this.bevel});
}

/// A laid-out string of glyphs, still in grid units.
class GlyphRun {
  final List<GlyphContour> contours;
  final List<double> bevels;
  final double width;

  const GlyphRun(this.contours, this.bevels, this.width);
}

const double _w = 28; // digit advance
const double _h = glyphUnitHeight;
const double _digitBevel = 2.0;

List<Offset> _pts(List<double> xy) => [
  for (var i = 0; i < xy.length; i += 2) Offset(xy[i], xy[i + 1]),
];

GlyphShape _digit(List<List<double>> outlines, {List<List<double>> holes = const []}) =>
    GlyphShape(
      [
        for (final o in outlines) GlyphContour(_pts(o)),
        for (final h in holes) GlyphContour(_pts(h), isHole: true),
      ],
      advance: _w,
      bevel: _digitBevel,
    );

/// `9` is `6` turned half a revolution.
GlyphShape _rotated(GlyphShape s) => GlyphShape(
  [
    for (final c in s.contours)
      GlyphContour([for (final p in c.points) Offset(_w - p.dx, _h - p.dy)], isHole: c.isHole),
  ],
  advance: s.advance,
  bevel: s.bevel,
);

final GlyphShape _six = _digit(
  [
    [6, 0, 22, 0, 28, 6, 28, 28, 18, 28, 18, 10, 10, 10, 10, 40, 22, 40, 28, 46, 28, 94, 22, 100, 6, 100, 0, 94, 0, 6],
  ],
  holes: [
    [10, 50, 18, 50, 18, 90, 10, 90],
  ],
);

final Map<String, GlyphShape> glyphShapes = {
  '0': _digit(
    [
      [6, 0, 22, 0, 28, 6, 28, 94, 22, 100, 6, 100, 0, 94, 0, 6],
    ],
    holes: [
      [13, 10, 15, 10, 18, 13, 18, 87, 15, 90, 13, 90, 10, 87, 10, 13],
    ],
  ),
  '1': _digit([
    [11, 0, 21, 0, 21, 100, 11, 100, 11, 22, 3, 27, 3, 14],
  ]),
  '2': _digit([
    [0, 6, 6, 0, 22, 0, 28, 6, 28, 46, 11, 90, 28, 90, 28, 100, 0, 100, 0, 89, 18, 42, 18, 10, 10, 10, 10, 28, 0, 28],
  ]),
  '3': _digit([
    [0, 6, 6, 0, 22, 0, 28, 6, 28, 45, 25, 50, 28, 55, 28, 94, 22, 100, 6, 100, 0, 94, 0, 70, 10, 70, 10, 90, 18, 90, 18, 55, 12, 55, 12, 45, 18, 45, 18, 10, 10, 10, 10, 30, 0, 30],
  ]),
  '4': _digit([
    [0, 0, 10, 0, 10, 56, 18, 56, 18, 0, 28, 0, 28, 100, 18, 100, 18, 66, 0, 66],
  ]),
  '5': _digit([
    [0, 0, 28, 0, 28, 10, 10, 10, 10, 40, 22, 40, 28, 46, 28, 94, 22, 100, 6, 100, 0, 94, 0, 70, 10, 70, 10, 90, 18, 90, 18, 50, 0, 50],
  ]),
  '6': _six,
  '7': _digit([
    [0, 0, 28, 0, 28, 12, 17, 100, 7, 100, 18, 10, 10, 10, 10, 26, 0, 26],
  ]),
  '8': _digit(
    [
      [6, 0, 22, 0, 28, 6, 28, 45, 25, 49, 28, 53, 28, 94, 22, 100, 6, 100, 0, 94, 0, 53, 3, 49, 0, 45, 0, 6],
    ],
    holes: [
      [10, 10, 18, 10, 18, 43, 10, 43],
      [10, 55, 18, 55, 18, 90, 10, 90],
    ],
  ),
  '9': _rotated(_six),
  // Small, centred in a wide cell, with a bevel of half the arm width so the
  // facets meet in ridges: each arm is a hip roof ending in a pyramid, as in
  // the stopwatch references.
  '+': GlyphShape(
    [
      GlyphContour(_pts([
        25.5, 37, 34.5, 37, 34.5, 45.5, 43, 45.5, 43, 54.5, 34.5, 54.5, //
        34.5, 63, 25.5, 63, 25.5, 54.5, 17, 54.5, 17, 45.5, 25.5, 45.5,
      ])),
    ],
    advance: 60,
    bevel: 4.5,
  ),
};

/// Lays [text] out left to right. Characters without a shape are skipped.
GlyphRun layoutGlyphs(String text) {
  final contours = <GlyphContour>[];
  final bevels = <double>[];
  var x = 0.0;
  var first = true;
  for (final char in text.split('')) {
    final shape = glyphShapes[char];
    if (shape == null) continue;
    if (!first) x += glyphGap;
    first = false;
    for (final c in shape.contours) {
      contours.add(c.shift(Offset(x, 0)));
      bevels.add(shape.bevel);
    }
    x += shape.advance;
  }
  return GlyphRun(contours, bevels, x);
}

/// Twice the signed area. Positive means clockwise on screen (y down).
double signedArea2(List<Offset> pts) {
  var a = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final p = pts[i];
    final q = pts[(i + 1) % pts.length];
    a += p.dx * q.dy - q.dx * p.dy;
  }
  return a;
}

/// Unit normal of edge i (from point i to i+1) pointing into the glyph's
/// material: into the polygon for outlines, out of it for holes.
List<Offset> materialNormals(GlyphContour c) {
  final clockwise = signedArea2(c.points) > 0;
  final intoPolygon = clockwise != c.isHole;
  final n = c.points.length;
  return [
    for (var i = 0; i < n; i++)
      () {
        final d = c.points[(i + 1) % n] - c.points[i];
        final len = d.distance;
        final right = Offset(-d.dy / len, d.dx / len);
        return intoPolygon ? right : -right;
      }(),
  ];
}

/// The contour moved [inset] units into the material with mitered corners.
/// Vertex i of the result matches vertex i of [c], so edge i of both forms
/// one chamfer facet.
List<Offset> insetContour(GlyphContour c, double inset) {
  final normals = materialNormals(c);
  final n = c.points.length;
  return [
    for (var i = 0; i < n; i++)
      () {
        final a = normals[(i - 1 + n) % n];
        final b = normals[i];
        final sum = a + b;
        final denom = 1 + (a.dx * b.dx + a.dy * b.dy);
        // Miter limit keeps very sharp corners from shooting out.
        final scale = math.min(inset / math.max(denom, 0.25), inset * 2.5);
        return c.points[i] + sum * scale;
      }(),
  ];
}

Path contoursToPath(Iterable<GlyphContour> contours, {Offset shift = Offset.zero}) {
  final path = Path()..fillType = PathFillType.evenOdd;
  for (final c in contours) {
    path.addPolygon([for (final p in c.points) p + shift], true);
  }
  return path;
}
