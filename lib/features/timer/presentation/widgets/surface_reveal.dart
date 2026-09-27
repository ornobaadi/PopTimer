import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Night ↔ Paper transition (`design.md` section 6.4): the new surface is
/// painted in a circle growing from [origin] to the far corner, on top of
/// the old one. No route change.
///
/// Only a change of [child]'s key counts as a surface change; key the child
/// by surface so Browse → running timer (both Night) swaps in place.
/// With [reduceMotion] it's a quick cross-fade instead.
class SurfaceReveal extends StatelessWidget {
  final Widget child;

  /// Local position the circle grows from; null means the centre.
  final Offset? origin;
  final bool reduceMotion;

  const SurfaceReveal({
    super.key,
    required this.child,
    this.origin,
    this.reduceMotion = false,
  });

  static const invert = Duration(milliseconds: 450);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: reduceMotion ? const Duration(milliseconds: 150) : invert,
      switchInCurve: Curves.easeInOutCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      transitionBuilder: (incoming, animation) {
        // The outgoing surface stays fully drawn underneath.
        if (incoming.key != child.key) return incoming;
        if (reduceMotion) return FadeTransition(opacity: animation, child: incoming);
        return AnimatedBuilder(
          animation: animation,
          child: incoming,
          builder: (context, revealed) => ClipPath(
            clipper: _CircleClipper(origin: origin, progress: animation.value),
            child: revealed,
          ),
        );
      },
      child: child,
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  _CircleClipper({required this.origin, required this.progress});

  final Offset? origin;
  final double progress;

  @override
  Path getClip(Size size) {
    final centre = origin ?? size.center(Offset.zero);
    // Far enough to cover the farthest corner.
    final radius = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((c) => (c - centre).distance).reduce(math.max);
    return Path()..addOval(Rect.fromCircle(center: centre, radius: radius * progress));
  }

  @override
  bool shouldReclip(_CircleClipper old) => old.progress != progress || old.origin != origin;
}
