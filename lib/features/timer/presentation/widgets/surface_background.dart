import 'package:flutter/material.dart';

import '../../../../core/render/grain_overlay.dart';
import '../../../../core/theme/skin.dart';

/// Full-bleed surface: flat color, a vignette falling off toward the edges
/// away from the key light, and the grain on top.
class SurfaceBackground extends StatelessWidget {
  final SurfaceTokens tokens;
  final bool lite;

  const SurfaceBackground({super.key, required this.tokens, this.lite = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.2, -0.3),
                radius: 1.3,
                colors: [tokens.bg, tokens.bgShade],
              ),
            ),
          ),
        ),
        if (!lite) const GrainOverlay(),
      ],
    );
  }
}
