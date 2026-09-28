import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The start "swoosh": a radial burst behind the numeral when a timer
/// starts, which drifts out and fades away. Plays once per mount, then its
/// ticker stops for good.
///
/// One painter, one [Ticker], a fixed pool of lines: nothing is allocated
/// per frame. Capped at 12 lines in [lite]; skipped with [reduceMotion].
class SpeedLines extends StatefulWidget {
  final Color color;
  final bool lite;
  final bool reduceMotion;

  const SpeedLines({
    super.key,
    required this.color,
    this.lite = false,
    this.reduceMotion = false,
  });

  static const int poolSize = 32;
  static const int maxLines = 28;
  static const int liteLines = 12;

  /// Full density for this long, then a fade over [fade].
  static const Duration hold = Duration(milliseconds: 600);
  static const Duration fade = Duration(milliseconds: 700);

  @override
  State<SpeedLines> createState() => _SpeedLinesState();
}

class _Line {
  double angle = 0;
  double inner = 0; // start radius, as a share of the half-diagonal
  double length = 0; // as a share of the half-diagonal
  double speed = 0; // half-diagonals per second
  double age = 0; // seconds
  double life = 1; // seconds
  double width = 2;
}

class _SpeedLinesState extends State<SpeedLines> with SingleTickerProviderStateMixin {
  final _random = math.Random(7);
  final _lines = List.generate(SpeedLines.poolSize, (_) => _Line());
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_onTick);

  Duration _last = Duration.zero;
  Duration _elapsed = Duration.zero;

  bool get isPlaying => _ticker.isActive;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) return;
    for (final line in _lines) {
      _spawn(line, staggered: true);
    }
    _ticker.start();
  }

  void _spawn(_Line l, {bool staggered = false}) {
    l
      ..angle = _random.nextDouble() * math.pi * 2
      ..inner = 0.12 + _random.nextDouble() * 0.2
      ..length = 0.35 + _random.nextDouble() * 0.6
      ..speed = 0.4 + _random.nextDouble() * 0.5
      ..life = 0.5 + _random.nextDouble() * 0.4
      ..age = staggered ? _random.nextDouble() * 0.3 : 0
      // An occasional thicker "hero" line.
      ..width = _random.nextDouble() < 0.1 ? 4.5 : 1.5 + _random.nextDouble() * 1.5;
  }

  /// 1 during the burst, fading to 0.
  double get _level {
    final faded = (_elapsed - SpeedLines.hold).inMicroseconds / SpeedLines.fade.inMicroseconds;
    return 1 - Curves.easeInCubic.transform(faded.clamp(0.0, 1.0));
  }

  int get _visibleCount => widget.lite ? SpeedLines.liteLines : SpeedLines.maxLines;

  void _onTick(Duration elapsed) {
    final dt = elapsed - _last;
    _last = elapsed;
    _elapsed += dt;
    final seconds = dt.inMicroseconds / Duration.microsecondsPerSecond;
    for (var i = 0; i < _visibleCount; i++) {
      final l = _lines[i];
      l.age += seconds;
      if (l.age > l.life) _spawn(l);
    }
    if (_level <= 0) _ticker.stop();
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _SpeedLinesPainter(
            lines: _lines,
            count: () => _level > 0 ? _visibleCount : 0,
            level: () => _level,
            color: widget.color,
            repaint: _frame,
          ),
        ),
      ),
    );
  }
}

class _SpeedLinesPainter extends CustomPainter {
  _SpeedLinesPainter({
    required this.lines,
    required this.count,
    required this.level,
    required this.color,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<_Line> lines;
  final int Function() count;
  final double Function() level;
  final Color color;
  final _paint = Paint()..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final reach = size.longestSide / 2 * 1.2;
    final n = count();
    final fade = level();
    for (var i = 0; i < n; i++) {
      final l = lines[i];
      final progress = (l.age / l.life).clamp(0.0, 1.0);
      final alpha = math.sin(math.pi * progress) * 0.85 * fade;
      if (alpha <= 0.01) continue;
      final dir = Offset(math.cos(l.angle), math.sin(l.angle));
      final r0 = (l.inner + l.speed * l.age) * reach;
      _paint
        ..color = color.withValues(alpha: color.a * alpha)
        ..strokeWidth = l.width;
      canvas.drawLine(centre + dir * r0, centre + dir * (r0 + l.length * reach), _paint);
    }
  }

  @override
  bool shouldRepaint(_SpeedLinesPainter old) => old.color != color;
}
