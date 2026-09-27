import '../../../core/engine/session.dart';
import '../../../core/engine/session_math.dart';
import '../../../core/theme/skin.dart';

enum Mode {
  browse,
  timerRunning,
  timerPaused,
  timerDone,
  stopwatchRunning,
  stopwatchPaused;

  bool get isTimer => this == timerRunning || this == timerPaused || this == timerDone;
  bool get isStopwatch => this == stopwatchRunning || this == stopwatchPaused;
  bool get isPaused => this == timerPaused || this == stopwatchPaused;
}

/// UI-facing state. Display values (numeral, countdown line) are not stored
/// here: the UI derives them from [session] and the clock every frame.
class SessionState {
  final Mode mode;
  final Session? session;
  final int selectedPresetIndex;

  /// Minutes; the `+` stopwatch page is implicit after the last one.
  final List<int> presets;
  final bool notificationsGranted;

  const SessionState({
    required this.mode,
    required this.session,
    required this.selectedPresetIndex,
    required this.presets,
    this.notificationsGranted = true,
  });

  /// Night for Browse and the timer, Paper for the stopwatch and time's up.
  Surface get surface =>
      mode == Mode.timerDone || mode.isStopwatch ? Surface.paper : Surface.night;

  bool get isStopwatchPageSelected => selectedPresetIndex >= presets.length;

  SessionState copyWith({
    Mode? mode,
    Session? session,
    bool clearSession = false,
    int? selectedPresetIndex,
    List<int>? presets,
    bool? notificationsGranted,
  }) => SessionState(
    mode: mode ?? this.mode,
    session: clearSession ? null : (session ?? this.session),
    selectedPresetIndex: selectedPresetIndex ?? this.selectedPresetIndex,
    presets: presets ?? this.presets,
    notificationsGranted: notificationsGranted ?? this.notificationsGranted,
  );

  /// The mode a session is in at [now].
  static Mode modeFor(Session? s, DateTime now) => switch (s) {
    null => Mode.browse,
    TimerSession() when s.isPaused => Mode.timerPaused,
    TimerSession() when isDone(s, now) => Mode.timerDone,
    TimerSession() => Mode.timerRunning,
    StopwatchSession() when s.isPaused => Mode.stopwatchPaused,
    StopwatchSession() => Mode.stopwatchRunning,
  };
}
