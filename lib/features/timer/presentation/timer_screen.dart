import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/platform_providers.dart';
import '../../../core/theme/skin.dart';
import '../../../core/theme/skin_provider.dart';
import '../../settings/application/settings_providers.dart';
import '../application/session_controller.dart';
import '../application/session_state.dart';
import '../../settings/presentation/settings_sheet.dart';
import 'browse_view.dart';
import 'session_stage.dart';
import 'widgets/hold_ring.dart';
import 'widgets/surface_reveal.dart';

/// The one screen. Gestures per PRD 5.2, routed to the controller:
///
/// | | Tap | Hold |
/// |---|---|---|
/// | Browse | start (timer, or stopwatch on +) | custom picker (Phase 5) |
/// | Timer running / paused | pause / resume | cancel |
/// | Time's up | dismiss | restart |
/// | Stopwatch | pause / resume | reset |
class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> with WidgetsBindingObserver {
  /// Where the next surface reveal grows from; null means the centre.
  Offset? _revealOrigin;

  SessionController get _controller => ref.read(sessionControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Re-assert the alarm and notification for a restored session.
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.onAppResumed());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.onAppResumed();
  }

  void _openSettings() {
    ref.read(hapticsServiceProvider).pageSnap();
    SettingsSheet.show(context);
  }

  void _onTap(Offset position) {
    _revealOrigin = position;
    switch (ref.read(sessionControllerProvider).mode) {
      case Mode.browse:
        _controller.startSelected();
      case Mode.timerDone:
        _controller.dismissAlarm();
      case _:
        _controller.togglePause();
    }
  }

  void Function(Offset)? _holdFor(Mode mode) {
    final Future<void> Function()? action = switch (mode) {
      Mode.timerRunning || Mode.timerPaused => _controller.cancel,
      Mode.timerDone => _controller.restartTimer,
      Mode.stopwatchRunning || Mode.stopwatchPaused => _controller.reset,
      Mode.browse => null,
    };
    if (action == null) return null;
    return (position) {
      _revealOrigin = position;
      action();
    };
  }

  static String? _holdLabel(Mode mode) => switch (mode) {
    Mode.timerRunning || Mode.timerPaused => 'Cancel timer',
    Mode.timerDone => 'Restart timer',
    Mode.stopwatchRunning || Mode.stopwatchPaused => 'Reset stopwatch',
    Mode.browse => null,
  };

  @override
  Widget build(BuildContext context) {
    // Time's up comes from the clock, not a tap: reveal from the numeral.
    ref.listen(sessionControllerProvider.select((s) => s.mode), (previous, next) {
      if (next == Mode.timerDone && previous == Mode.timerRunning) _revealOrigin = null;
    });

    final state = ref.watch(sessionControllerProvider);
    final skin = ref.watch(skinProvider);
    final lite = ref.watch(liteEffectsProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final surface = state.surface;
    final tokens = skin.surface(surface);
    final session = state.session;

    final content = session == null
        ? BrowseView(
            night: skin.night,
            presets: state.presets,
            initialIndex: state.selectedPresetIndex,
            lite: lite,
            onPageChanged: _controller.selectPreset,
            onSettings: _openSettings,
          )
        : SessionStage(
            session: session,
            mode: state.mode,
            skin: skin,
            lite: lite,
            reduceMotion: reduceMotion,
            onSettings: _openSettings,
          );

    return PopScope(
      // Back on time's up dismisses; otherwise the app backgrounds and any
      // session keeps running.
      canPop: state.mode != Mode.timerDone,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _controller.dismissAlarm();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: tokens.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: tokens.bg,
          body: HoldGestureArea(
            ringColor: tokens.ink,
            onTap: _onTap,
            onHold: _holdFor(state.mode),
            holdLabel: _holdLabel(state.mode),
            child: SurfaceReveal(
              origin: _revealOrigin,
              reduceMotion: reduceMotion,
              child: KeyedSubtree(key: ValueKey<Surface>(surface), child: content),
            ),
          ),
        ),
      ),
    );
  }
}
