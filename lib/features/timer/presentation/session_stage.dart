import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/engine/session.dart';
import '../../../core/engine/session_math.dart';
import '../../../core/platform/device_tilt.dart';
import '../../../core/platform/platform_providers.dart';
import '../../../core/render/glyph_renderer.dart';
import '../../../core/theme/skin.dart';
import '../application/session_controller.dart';
import '../application/session_state.dart';
import '../application/tick_provider.dart';
import 'session_view.dart';
import 'widgets/speed_lines.dart';

/// Drives a [SessionView] from the clock. Owns the frame ticker: each frame
/// derives the numeral and line from the stored timestamps, rebuilds only
/// when either changes, and fires the per-change haptics.
///
/// Takes the session as a parameter (instead of watching the controller) so
/// a copy kept on screen during a surface reveal keeps showing its own state.
class SessionStage extends ConsumerStatefulWidget {
  final Session session;
  final Mode mode;
  final Skin skin;
  final bool lite;
  final bool reduceMotion;
  final VoidCallback? onSettings;

  const SessionStage({
    super.key,
    required this.session,
    required this.mode,
    required this.skin,
    this.lite = false,
    this.reduceMotion = false,
    this.onSettings,
  });

  /// A session younger than this gets the start swoosh; older ones (resumed,
  /// restored after the app was killed) don't.
  static const freshStart = Duration(seconds: 2);

  @override
  ConsumerState<SessionStage> createState() => _SessionStageState();
}

class _SessionStageState extends ConsumerState<SessionStage> with TickerProviderStateMixin {
  late final FrameClock _frameClock = FrameClock(
    vsync: this,
    clock: ref.read(clockProvider),
    onTick: _onTick,
  );

  late String _numeral;
  late String _line;
  late bool _swoosh;
  bool _reportedZero = false;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    _swoosh = now.difference(widget.session.startedAt) < SessionStage.freshStart;
    _derive(now, initial: true);
    _syncTicker();
  }

  @override
  void didUpdateWidget(SessionStage old) {
    super.didUpdateWidget(old);
    if (old.session.startedAt != widget.session.startedAt) {
      // A new session (restart): swoosh again.
      _swoosh = true;
      _reportedZero = false;
    }
    if (old.session != widget.session) {
      _reportedZero = false;
      _derive(ref.read(clockProvider).now(), initial: true);
    }
    _syncTicker();
  }

  void _syncTicker() {
    if (widget.session.isPaused) {
      _frameClock.stop();
    } else {
      _frameClock.start();
    }
  }

  void _onTick(DateTime now) {
    if (_derive(now)) setState(() {});
    final s = widget.session;
    if (!_reportedZero && widget.mode == Mode.timerRunning && s is TimerSession && isDone(s, now)) {
      _reportedZero = true;
      ref.read(sessionControllerProvider.notifier).onTimerReachedZero();
    }
  }

  /// Updates the display values; true if anything visible changed.
  bool _derive(DateTime now, {bool initial = false}) {
    final s = widget.session;
    final numeral = bigNumeral(s, now);
    final line = countdownText(s, now);
    if (initial) {
      _numeral = numeral;
      _line = line;
      return true;
    }
    final numeralChanged = numeral != _numeral;
    if (numeralChanged) _hapticFor(s, now);
    final changed = numeralChanged || line != _line;
    _numeral = numeral;
    _line = line;
    return changed;
  }

  /// `design.md` section 8: a tick per minute, a click per last-10 second.
  void _hapticFor(Session s, DateTime now) {
    final haptics = ref.read(hapticsServiceProvider);
    if (s is TimerSession) {
      final secs = displaySeconds(remaining(s, now));
      if (secs <= 0) return; // time's up is the controller's
      if (secs <= 10) {
        haptics.secondTick();
      } else if (secs >= 59) {
        haptics.minuteTick();
      }
    } else {
      haptics.minuteTick();
    }
  }

  @override
  void dispose() {
    _frameClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final night = widget.skin.night;
    final paper = widget.skin.paper;
    final onPaper = mode == Mode.timerDone || mode.isStopwatch;
    final tokens = onPaper ? paper : night;
    final material = switch (mode) {
      Mode.timerRunning => GlyphMaterial.lit(night),
      _ => GlyphMaterial.idle(tokens),
    };

    return SessionView(
      tokens: tokens,
      numeral: _numeral,
      material: material,
      line: _line,
      semanticsLabel: _semanticsLabel(mode),
      deviceTilt: ref.watch(deviceTiltProvider),
      backdrop: _swoosh && widget.session is TimerSession
          ? SpeedLines(
              // Keyed by start so a restart plays a fresh swoosh.
              key: ValueKey(widget.session.startedAt),
              color: night.speedLine,
              lite: widget.lite,
              reduceMotion: widget.reduceMotion,
            )
          : null,
      blinkLine: mode.isPaused,
      showSettings: mode.isPaused,
      lite: widget.lite,
      reduceMotion: widget.reduceMotion,
      onSettings: widget.onSettings,
    );
  }

  String _semanticsLabel(Mode mode) => switch (mode) {
    Mode.timerRunning => 'Timer running, $_line left. Tap to pause.',
    Mode.timerPaused => 'Timer paused, $_line left. Tap to resume.',
    Mode.timerDone => "Time's up. Tap to dismiss.",
    Mode.stopwatchRunning => 'Stopwatch running, ${_line.substring(1)}. Tap to pause.',
    Mode.stopwatchPaused => 'Stopwatch paused, ${_line.substring(1)}. Tap to resume.',
    Mode.browse => '',
  };
}
