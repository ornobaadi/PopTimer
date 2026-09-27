import 'package:flutter/material.dart';

/// Subtle tactile film grain across the whole screen (shared with Pop Calc).
class GrainOverlay extends StatelessWidget {
  final double opacity;

  const GrainOverlay({super.key, this.opacity = 0.045});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Image.asset(
          'assets/textures/noise.png',
          repeat: ImageRepeat.repeat,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.none,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
