import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Whole-screen tap + hold-to-confirm gesture (`design.md` section 7).
///
/// A tap calls [onTap]. Holding fills a ring around the finger over
/// [holdDuration]; when it completes, [onHold] fires. Releasing early
/// springs the ring back and does nothing, and moving past the touch slop
/// (a scroll) cancels, so a hold can never happen by accident.
class HoldGestureArea extends StatefulWidget {
  final Widget child;
  final void Function(Offset position)? onTap;
  final void Function(Offset position)? onHold;
  final Color ringColor;

  /// TalkBack action label for the hold, e.g. "Cancel timer".
  final String? holdLabel;

  const HoldGestureArea({
    super.key,
    required this.child,
    required this.ringColor,
    this.onTap,
    this.onHold,
    this.holdLabel,
  });

  static const holdDuration = Duration(milliseconds: 600);

  /// Presses shorter than this are taps, even if a hold had started.
  static const tapThreshold = Duration(milliseconds: 250);

  static const double ringSize = 56;

  @override
  State<HoldGestureArea> createState() => _HoldGestureAreaState();
}

class _HoldGestureAreaState extends State<HoldGestureArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: HoldGestureArea.holdDuration,
  )..addStatusListener(_onHoldStatus);

  Offset _position = Offset.zero;
  bool _completed = false;

  /// Ring progress below which a release is a tap, not an aborted hold.
  static final double _tapProgress =
      HoldGestureArea.tapThreshold.inMicroseconds /
      HoldGestureArea.holdDuration.inMicroseconds;

  void _onHoldStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _completed) return;
    _completed = true;
    widget.onHold?.call(_position);
    _hold.value = 0;
  }

  /// Starts the ring on the raw pointer, not the tap recognizer's down
  /// callback, which only arrives after the ~100 ms press timeout and would
  /// make a 600 ms hold take 700.
  void _onPointerDown(PointerDownEvent e) {
    if (_hold.isAnimating && _hold.velocity > 0) return; // a second finger
    _position = e.localPosition;
    _completed = false;
    if (widget.onHold != null) _hold.forward(from: 0);
  }

  void _onTapUp(TapUpDetails d) {
    if (_completed) return;
    if (widget.onHold == null || _hold.value < _tapProgress) {
      _hold.value = 0;
      widget.onTap?.call(d.localPosition);
    } else {
      _springBack();
    }
  }

  void _springBack() {
    if (_hold.value == 0) return;
    _hold.animateBack(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final holdLabel = widget.holdLabel;
    return Semantics(
      customSemanticsActions: {
        if (widget.onHold != null && holdLabel != null)
          CustomSemanticsAction(label: holdLabel): () {
            final centre = (context.size ?? Size.zero).center(Offset.zero);
            widget.onHold!(centre);
          },
      },
      child: Listener(
        onPointerDown: _onPointerDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _onTapUp,
          onTapCancel: _springBack,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _hold,
                  builder: (context, _) => CustomPaint(
                    painter: _RingPainter(
                      centre: _position,
                      progress: _hold.value,
                      color: widget.ringColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.centre,
    required this.progress,
    required this.color,
  });

  final Offset centre;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    // Fade in over the first fifth so an ordinary tap never flashes a ring.
    final fade = (progress * 5).clamp(0.0, 1.0);
    final rect = Rect.fromCircle(
      center: centre,
      radius: HoldGestureArea.ringSize / 2,
    );
    canvas.drawCircle(
      centre,
      HoldGestureArea.ringSize / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.25 * fade),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: fade),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.centre != centre || old.color != color;
}
