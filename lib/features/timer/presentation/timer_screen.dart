import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/engine/presets.dart';
import '../../../core/theme/skin.dart';
import '../../../core/theme/skin_provider.dart';
import 'browse_view.dart';

/// The one screen. Phase 2 shows Browse only; the controller (Phase 3)
/// switches to [SessionView] for running, paused, done and stopwatch.
class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinProvider);
    final night = skin.surface(Surface.night);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: night.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: night.bg,
        body: BrowseView(
          night: night,
          presets: defaultPresets,
          initialIndex: presetIndexOf(defaultPresets, defaultPresetMinutes),
        ),
      ),
    );
  }
}
