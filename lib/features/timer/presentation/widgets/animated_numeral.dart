import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/render/glyph_renderer.dart';
import 'sculpted_numeral.dart';

/// A [SculptedNumeral] with Pop Calc's motion:
///
/// * material light-up / dim-down when the state changes
/// * Pop Calc's "type-up" when the number changes: the new numeral rises
///   from below with a squash-and-stretch while its depth springs back
/// * interactive 3D: drag to tilt the block in perspective (the extrusion
///   and light follow), elastic spring back on release, plus device-tilt
///   parallax from [deviceTilt]
///
/// All animation state lives here, never in the controller.
class AnimatedNumeral extends StatefulWidget {
  final String text;
  final GlyphMaterial material;
  final bool lite;
  final bool reduceMotion;

  /// Drag to tilt. Off in Browse, where vertical drags page.
  final bool interactive;

  /// Raw device tilt (-1..1 per axis); smoothed here.
  final Stream<Offset>? deviceTilt;

  const AnimatedNumeral({
    super.key,
    required this.text,
    required this.material,
    this.lite = false,
    this.reduceMotion = false,
    this.interactive = false,
    this.deviceTilt,
  });

  static const lightUp = Duration(milliseconds: 380);
  static const dimDown = Duration(milliseconds: 260);
  static const typeUp = Duration(milliseconds: 280);

  @override
  State<AnimatedNumeral> createState() => _AnimatedNumeralState();
}

class _AnimatedNumeralState extends State<AnimatedNumeral> with TickerProviderStateMixin {
  late final AnimationController _material = AnimationController(vsync: this, value: 1);
  late final AnimationController _type = AnimationController(
    vsync: this,
    duration: AnimatedNumeral.typeUp,
    value: 1,
  );
  late final AnimationController _depth = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  late final AnimationController _springBack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  late GlyphMaterial _from = widget.material;
  Curve _materialCurve = Curves.easeOutCubic;

  Offset _drag = Offset.zero; // -1..1
  Offset _dragAtRelease = Offset.zero;
  Offset _accumulated = Offset.zero;
  Offset _sensor = Offset.zero; // smoothed
  StreamSubscription<Offset>? _tiltSub;

  @override
  void initState() {
    super.initState();
    _subscribeTilt();
    _springBack.addStatusListener((s) {
      if (s == AnimationStatus.completed) _drag = Offset.zero;
    });
  }

  void _subscribeTilt() {
    _tiltSub?.cancel();
    _tiltSub = widget.deviceTilt?.listen((raw) {
      // Exponential smoothing for jitter-free parallax.
      final next = _sensor * 0.86 + raw * 0.14;
      if ((next - _sensor).distance > 0.002 && mounted) setState(() => _sensor = next);
    }, onError: (Object _) {});
  }

  @override
  void didUpdateWidget(AnimatedNumeral old) {
    super.didUpdateWidget(old);
    if (old.deviceTilt != widget.deviceTilt) _subscribeTilt();
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
      _type.forward(from: 0);
      _depth.forward(from: 0.15);
    }
  }

  // ─── Drag to tilt ─────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails _) {
    _springBack.stop();
    _accumulated = _drag * 110;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _accumulated += d.delta;
    setState(() {
      _drag = Offset(
        (_accumulated.dx / 110).clamp(-1.0, 1.0),
        (_accumulated.dy / 110).clamp(-1.0, 1.0),
      );
    });
  }

  void _release([Object? _]) {
    _dragAtRelease = _drag;
    _springBack.forward(from: 0);
  }

  Offset get _activeDrag => _springBack.isAnimating
      ? _dragAtRelease * (1 - Curves.elasticOut.transform(_springBack.value))
      : _drag;

  @override
  void dispose() {
    _tiltSub?.cancel();
    _material.dispose();
    _type.dispose();
    _depth.dispose();
    _springBack.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final numeral = AnimatedBuilder(
      animation: Listenable.merge([_material, _type, _depth, _springBack]),
      builder: (context, _) {
        final material = GlyphMaterial.lerp(
          _from,
          widget.material,
          _materialCurve.transform(_material.value),
        );

        // Drag and device tilt combined, as in Pop Calc.
        final drag = _activeDrag;
        final tilt = Offset(
          (drag.dx + _sensor.dx * 0.45).clamp(-1.2, 1.2),
          (drag.dy + _sensor.dy * 0.45).clamp(-1.2, 1.2),
        );
        // The light swings with the tilt, so the extrusion shifts naturally.
        final light = defaultLightDir - tilt * 0.6;

        // Type-up: rise, squash and stretch.
        final t = _type.value;
        final ease = Curves.easeOutBack.transform(t);
        final rise = (1 - ease) * 26;
        final scaleY = 0.86 + 0.14 * ease;
        final scaleX = 1.06 - 0.06 * ease;
        final depth = Curves.easeOutBack.transform(_depth.value).clamp(0.0, 1.15);

        return Transform.translate(
          offset: Offset(0, rise),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0010) // camera perspective
                ..rotateX(-tilt.dy * 0.28)
                ..rotateY(tilt.dx * 0.28),
              child: SculptedNumeral(
                text: widget.text,
                material: material,
                depth: depth,
                lite: widget.lite,
                lightDir: Offset(light.dx, light.dy) / math.max(light.distance, 0.001),
              ),
            ),
          ),
        );
      },
    );
    if (!widget.interactive) return numeral;
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _release,
      onPanCancel: _release,
      child: numeral,
    );
  }
}
