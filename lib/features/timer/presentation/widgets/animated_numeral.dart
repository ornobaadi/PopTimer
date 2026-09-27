import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../../core/render/glyph_renderer.dart';
import 'sculpted_numeral.dart';

/// How the numeral reacts when its text changes.
enum NumeralChange {
  /// Minute changes: old sinks, new rises with a spring overshoot.
  riseSink,

  /// Seconds under a minute: a scale punch.
  punch,

  /// Last 10 seconds: a stronger punch.
  strongPunch,
}

/// A [SculptedNumeral] with its motion (`design.md` section 7):
/// material light-up / dim-down, minute sink/rise, and second punches.
/// All animation state lives here, never in the controller.
class AnimatedNumeral extends StatefulWidget {
  final String text;
  final GlyphMaterial material;
  final NumeralChange change;
  final bool lite;
  final bool reduceMotion;

  const AnimatedNumeral({
    super.key,
    required this.text,
    required this.material,
    this.change = NumeralChange.riseSink,
    this.lite = false,
    this.reduceMotion = false,
  });

  static const lightUp = Duration(milliseconds: 380);
  static const dimDown = Duration(milliseconds: 260);
  static const minuteTick = Duration(milliseconds: 320);
  static const secondPunch = Duration(milliseconds: 180);

  @override
  State<AnimatedNumeral> createState() => _AnimatedNumeralState();
}

class _AnimatedNumeralState extends State<AnimatedNumeral> with TickerProviderStateMixin {
  late final AnimationController _material = AnimationController(vsync: this, value: 1);
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: AnimatedNumeral.minuteTick,
    value: 1,
  );
  late final AnimationController _punch = AnimationController(
    vsync: this,
    duration: AnimatedNumeral.secondPunch,
    value: 1,
  );

  late GlyphMaterial _from = widget.material;
  Curve _materialCurve = Curves.easeOutCubic;
  String? _previousText;
  double _punchAmount = 0;

  static final _rise = _SpringCurve(
    const SpringDescription(mass: 1, stiffness: 450, damping: 24),
    AnimatedNumeral.minuteTick,
  );

  GlyphMaterial get _currentMaterial => GlyphMaterial.lerp(
    _from,
    widget.material,
    _materialCurve.transform(_material.value),
  );

  @override
  void didUpdateWidget(AnimatedNumeral old) {
    super.didUpdateWidget(old);
    if (old.material != widget.material) {
      // Start from wherever the last transition got to, so it's interruptible.
      _from = GlyphMaterial.lerp(_from, old.material, _materialCurve.transform(_material.value));
      final lighter = widget.material.face.computeLuminance() > _from.face.computeLuminance();
      _materialCurve = lighter ? Curves.easeOutCubic : Curves.easeInCubic;
      _material.duration = lighter ? AnimatedNumeral.lightUp : AnimatedNumeral.dimDown;
      if (widget.reduceMotion) {
        _material.value = 1;
      } else {
        _material.forward(from: 0);
      }
    }
    if (old.text != widget.text && !widget.reduceMotion) {
      switch (widget.change) {
        case NumeralChange.riseSink:
          _previousText = old.text;
          _swap.forward(from: 0);
        case NumeralChange.punch || NumeralChange.strongPunch:
          _previousText = null;
          _swap.value = 1;
          _punchAmount = widget.change == NumeralChange.strongPunch ? 0.06 : 0.03;
          _punch.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _material.dispose();
    _swap.dispose();
    _punch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_material, _swap, _punch]),
      builder: (context, _) {
        final material = _currentMaterial;
        final t = _swap.value;
        final punch = _punch.isAnimating ? 1 + _punchAmount * math.sin(math.pi * _punch.value) : 1.0;

        final swapping = _swap.isAnimating && _previousText != null;
        final incoming = SculptedNumeral(
          text: widget.text,
          material: material,
          depth: swapping ? _rise.transform(t).clamp(0.0, 1.2) : 1,
          lite: widget.lite,
        );
        if (!swapping) {
          return Transform.scale(scale: punch, child: incoming);
        }

        // Old numeral sinks and fades over the first half; the new one rises
        // with overshoot and fades in quickly.
        final sink = Curves.easeInCubic.transform((t * 2).clamp(0.0, 1.0));
        return Stack(
          fit: StackFit.expand,
          children: [
            if (sink < 1)
              Opacity(
                opacity: 1 - sink,
                child: Transform.scale(
                  scale: 1 - 0.04 * sink,
                  child: SculptedNumeral(
                    text: _previousText!,
                    material: material,
                    depth: 1 - sink,
                    lite: widget.lite,
                  ),
                ),
              ),
            Opacity(
              opacity: (t / 0.3).clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.96 + 0.04 * t, child: incoming),
            ),
          ],
        );
      },
    );
  }
}

/// A spring from 0 to 1 sampled over [duration], overshoot included.
class _SpringCurve extends Curve {
  _SpringCurve(SpringDescription spring, Duration duration)
    : _sim = SpringSimulation(spring, 0, 1, 0),
      _seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;

  final SpringSimulation _sim;
  final double _seconds;

  @override
  double transformInternal(double t) => _sim.x(t * _seconds);
}
