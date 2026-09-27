import 'package:flutter/material.dart';

import '../../../core/render/glyph_renderer.dart';
import '../../../core/theme/skin.dart';
import 'widgets/preset_pager.dart';
import 'widgets/settings_ring.dart';
import 'widgets/surface_background.dart';
import 'widgets/tap_hint.dart';
import 'widgets/timer_layout.dart';

/// Browse (idle): dark-on-dark numerals on Night, TAP TO START, settings.
class BrowseView extends StatelessWidget {
  final SurfaceTokens night;
  final List<int> presets;
  final int initialIndex;
  final bool lite;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onSettings;

  const BrowseView({
    super.key,
    required this.night,
    required this.presets,
    required this.initialIndex,
    this.lite = false,
    this.onPageChanged,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SurfaceBackground(tokens: night, lite: lite),
        PresetPager(
          presets: presets,
          initialIndex: initialIndex,
          material: GlyphMaterial.idle(night),
          lite: lite,
          onPageChanged: onPageChanged,
        ),
        Align(
          alignment: const Alignment(0, TimerLayout.hintAlignY),
          child: TapHint(ink: night.ink),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SettingsRing(color: night.inkSoft, onTap: onSettings),
            ),
          ),
        ),
      ],
    );
  }
}
