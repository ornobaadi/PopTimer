import 'package:flutter/material.dart';

import '../../../core/render/glyph_renderer.dart';
import '../../../core/theme/skin.dart';
import 'widgets/countdown_line.dart';
import 'widgets/sculpted_numeral.dart';
import 'widgets/settings_ring.dart';
import 'widgets/surface_background.dart';
import 'widgets/timer_layout.dart';

/// A running, paused or finished session: one numeral in the same spot as
/// the pager's centred page, with the countdown line underneath.
///
/// Purely presentational; the controller (Phase 3) decides what to show.
class SessionView extends StatelessWidget {
  final SurfaceTokens tokens;
  final String numeral;
  final GlyphMaterial material;
  final String line;
  final String semanticsLabel;
  final bool showSettings;
  final bool lite;
  final VoidCallback? onSettings;

  const SessionView({
    super.key,
    required this.tokens,
    required this.numeral,
    required this.material,
    required this.line,
    required this.semanticsLabel,
    this.showSettings = false,
    this.lite = false,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final numeralHeight = constraints.maxHeight * TimerLayout.numeralFraction;
        final lineTop = (constraints.maxHeight + numeralHeight) / 2 + TimerLayout.lineGap;
        return Stack(
          fit: StackFit.expand,
          children: [
            SurfaceBackground(tokens: tokens, lite: lite),
            Semantics(
              label: semanticsLabel,
              child: Center(
                child: SizedBox(
                  height: numeralHeight,
                  width: constraints.maxWidth,
                  child: SculptedNumeral(text: numeral, material: material, lite: lite),
                ),
              ),
            ),
            Positioned(
              top: lineTop,
              left: 0,
              right: 0,
              child: CountdownLine(text: line, color: tokens.ink),
            ),
            if (showSettings)
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SettingsRing(color: tokens.inkSoft, onTap: onSettings),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
