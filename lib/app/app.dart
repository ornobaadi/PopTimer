import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/skin.dart';
import '../core/theme/skin_provider.dart';
import '../core/theme/typography.dart';
import '../features/timer/presentation/timer_screen.dart';

class PopTimerApp extends ConsumerWidget {
  const PopTimerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final night = ref.watch(skinProvider).surface(Surface.night);
    return MaterialApp(
      title: 'Pop Timer',
      debugShowCheckedModeBanner: false,
      theme: _theme(night),
      home: const TimerScreen(),
    );
  }

  static ThemeData _theme(SurfaceTokens t) {
    final brightness = t.brightness;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: t.bg,
      fontFamily: AppType.labelFamily,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: t.ink,
        onPrimary: t.bg,
        secondary: t.ink,
        onSecondary: t.bg,
        error: t.ink,
        onError: t.bg,
        surface: t.bg,
        onSurface: t.ink,
      ),
    );
  }
}
