import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Radial burst behind the lit numeral (`design.md` section 6).
///
/// One painter, one [Ticker], a fixed pool of lines: nothing is allocated
/// per frame. Bursts to full density on start and on [burstKey] changes,
/// then settles to ~40% and a slower drift. Frozen and faded while
/// [paused]; static with [reduceMotion]; capped at 12 lines in [lite].
class SpeedLines extends StatefulWidget {
  final Color color;
  final bool paused;
  final bool lite;
  final bool reduceMotion;

  /// Change to trigger a re-burst (minute change, last-10-seconds tick).
  final int burstKey;

  const SpeedLines({
    super.key,
    required this.color,
    this.paused = false,
    this.lite = false,
    this.reduceMotion = false,
    this.burstKey = 0,
  });

  static const int poolSize = 32;
  static const int maxLines = 28;
  static const int liteLines = 12;
  static const Duration burst = Duration(milliseconds: 600);

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
  Duration _burstAt = Duration.zero;

  @override
  void initState() {
    super.initState();
    for (final line in _lines) {
      _spawn(line, staggered: true);
    }
    _syncTicker();
  }

  @override
  void didUpdateWidget(SpeedLines old) {
    super.didUpdateWidget(old);
    if (old.burstKey != widget.burstKey) _burstAt = _elapsed;
    _syncTicker();
  }

  void _syncTicker() {
    final run = !widget.paused && !widget.reduceMotion;
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _spawn(_Line l, {bool staggered = false}) {
    l
      ..angle = _random.nextDouble() * math.pi * 2
      ..inner = 0.12 + _random.nextDouble() * 0.2
      ..length = 0.35 + _random.nextDouble() * 0.6
      ..speed = 0.25 + _random.nextDouble() * 0.35
      ..life = 0.5 + _random.nextDouble() * 0.4
      ..age = staggered ? _random.nextDouble() * 0.9 : 0
      // An occasional thicker "hero" line.
      ..width = _random.nextDouble() < 0.1 ? 4.5 : 1.5 + _random.nextDouble() * 1.5;
  }

  /// 1 right after a burst, easing to 0 over [SpeedLines.burst].
  double get _burstLevel {
    final since = (_elapsed - _burstAt).inMicroseconds / SpeedLines.burst.inMicroseconds;
    return 1 - Curves.easeOutCubic.transform(since.clamp(0.0, 1.0));
  }

  int get _visibleCount {
    if (widget.lite) return SpeedLines.liteLines;
    if (widget.reduceMotion) return (SpeedLines.maxLines * 0.4).round();
    return (SpeedLines.maxLines * (0.4 + 0.6 * _burstLevel)).round();
  }

  void _onTick(Duration elapsed) {
    // Ticker elapsed restarts at zero after a stop; track our own clock.
    final dt = _last == Duration.zero ? Duration.zero : elapsed - _last;
    _last = elapsed;
    _elapsed += dt;
    final seconds = dt.inMicroseconds / Duration.microsecondsPerSecond;
    final speedFactor = 0.6 + 0.8 * _burstLevel;
    for (var i = 0; i < _visibleCount; i++) {
      final l = _lines[i];
      l.age += seconds * speedFactor;
      if (l.age > l.life) _spawn(l);
    }
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
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.paused ? 0.2 : 1,
        duration: const Duration(milliseconds: 260),
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _SpeedLinesPainter(
              lines: _lines,
              count: () => _visibleCount,
              color: widget.color,
              repaint: _frame,
            ),
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
    required this.color,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<_Line> lines;
  final int Function() count;
  final Color color;
  final _paint = Paint()..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final reach = size.longestSide / 2 * 1.2;
    final n = count();
    for (var i = 0; i < n; i++) {
      final l = lines[i];
      final progress = (l.age / l.life).clamp(0.0, 1.0);
      final alpha = math.sin(math.pi * progress) * 0.85;
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
