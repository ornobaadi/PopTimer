import 'package:flutter/material.dart';

import '../../../core/render/glyph_renderer.dart';
import '../../../core/theme/skin.dart';
import '../../../core/theme/typography.dart';
import 'widgets/animated_numeral.dart';
import 'widgets/countdown_line.dart';
import 'widgets/settings_ring.dart';
import 'widgets/surface_background.dart';
import 'widgets/timer_layout.dart';

/// A running, paused or finished session: one numeral in the same spot as
/// the pager's centred page, with the countdown line underneath.
///
/// Purely presentational: `SessionStage` feeds it from the clock.
class SessionView extends StatelessWidget {
  final SurfaceTokens tokens;
  final String numeral;
  final GlyphMaterial material;
  final String line;
  final String semanticsLabel;
  /// Device tilt for the numeral parallax.
  final Stream<Offset>? deviceTilt;

  /// Painted between the surface and the numeral (speed lines).
  final Widget? backdrop;
  /// Small note under the countdown line (notifications denied).
  final String? footnote;
  final bool blinkLine;
  final bool showSettings;
  final bool lite;
  final bool reduceMotion;
  final VoidCallback? onSettings;

  const SessionView({
    super.key,
    required this.tokens,
    required this.numeral,
    required this.material,
    required this.line,
    required this.semanticsLabel,
    this.deviceTilt,
    this.backdrop,
    this.footnote,
    this.blinkLine = false,
    this.showSettings = false,
    this.lite = false,
    this.reduceMotion = false,
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
            ?backdrop,
            // Not a live region: the label holds the countdown, and TalkBack
            // must not announce every second (`design.md` 11). State-change
            // announcements come with the accessibility pass (Phase 5).
            Semantics(
              label: semanticsLabel,
              child: Center(
                child: SizedBox(
                  height: numeralHeight,
                  width: constraints.maxWidth,
                  child: AnimatedNumeral(
                    text: numeral,
                    material: material,
                    interactive: true,
                    deviceTilt: deviceTilt,
                    lite: lite,
                    reduceMotion: reduceMotion,
                  ),
                ),
              ),
            ),
            Positioned(
              top: lineTop,
              left: 0,
              right: 0,
              child: ExcludeSemantics(
                child: CountdownLine(
                  text: line,
                  color: tokens.ink,
                  blinking: blinkLine,
                  reduceMotion: reduceMotion,
                ),
              ),
            ),
            if (footnote != null)
              Positioned(
                top: lineTop + 40,
                left: 32,
                right: 32,
                child: Text(
                  footnote!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: AppType.bodyFamily, fontSize: 13, color: tokens.inkSoft),
                ),
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
