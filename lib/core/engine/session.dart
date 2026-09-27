/// An active timer or stopwatch.
///
/// A session stores *when* things happened, never *how much* is left. Every
/// value on screen is derived from these timestamps and `Clock.now()`
/// (see `session_math.dart`), so backgrounding, process death and reboots are
/// handled by persisting this object and recomputing.
sealed class Session {
  /// UTC wall-clock time the session started.
  final DateTime startedAt;

  /// Sum of all completed pauses.
  final Duration pausedTotal;

  /// Non-null while paused.
  final DateTime? pausedAt;

  const Session({
    required this.startedAt,
    this.pausedTotal = Duration.zero,
    this.pausedAt,
  });

  bool get isPaused => pausedAt != null;

  /// Freezes the session at [now]. No-op if already paused.
  Session pause(DateTime now);

  /// Folds the current pause into [pausedTotal]. No-op if running.
  Session resume(DateTime now);

  Map<String, Object?> toJson();

  static Session fromJson(Map<String, Object?> json) {
    final startedAt = _readTime(json['startedAt'])!;
    final pausedTotal = Duration(microseconds: json['pausedTotal']! as int);
    final pausedAt = _readTime(json['pausedAt']);
    return switch (json['type']) {
      'timer' => TimerSession(
        startedAt: startedAt,
        pausedTotal: pausedTotal,
        pausedAt: pausedAt,
        duration: Duration(microseconds: json['duration']! as int),
        presetMinutes: json['presetMinutes']! as int,
      ),
      'stopwatch' => StopwatchSession(
        startedAt: startedAt,
        pausedTotal: pausedTotal,
        pausedAt: pausedAt,
        laps: [
          for (final lap in (json['laps'] as List? ?? const []))
            Duration(microseconds: lap as int),
        ],
      ),
      final type => throw FormatException('Unknown session type: $type'),
    };
  }

  Map<String, Object?> _baseJson(String type) => {
    'type': type,
    'startedAt': startedAt.microsecondsSinceEpoch,
    'pausedTotal': pausedTotal.inMicroseconds,
    'pausedAt': pausedAt?.microsecondsSinceEpoch,
  };

  static DateTime? _readTime(Object? value) => value == null
      ? null
      : DateTime.fromMicrosecondsSinceEpoch(value as int, isUtc: true);
}

final class TimerSession extends Session {
  final Duration duration;

  /// What the user picked, for "restart" and the pager position.
  final int presetMinutes;

  const TimerSession({
    required super.startedAt,
    super.pausedTotal,
    super.pausedAt,
    required this.duration,
    required this.presetMinutes,
  });

  factory TimerSession.start({
    required DateTime now,
    required Duration duration,
    required int presetMinutes,
  }) => TimerSession(
    startedAt: now.toUtc(),
    duration: duration,
    presetMinutes: presetMinutes,
  );

  TimerSession copyWith({
    Duration? pausedTotal,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    Duration? duration,
  }) => TimerSession(
    startedAt: startedAt,
    pausedTotal: pausedTotal ?? this.pausedTotal,
    pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
    duration: duration ?? this.duration,
    presetMinutes: presetMinutes,
  );

  @override
  TimerSession pause(DateTime now) =>
      isPaused ? this : copyWith(pausedAt: now.toUtc());

  @override
  TimerSession resume(DateTime now) => isPaused
      ? copyWith(
          pausedTotal: pausedTotal + now.toUtc().difference(pausedAt!),
          clearPausedAt: true,
        )
      : this;

  @override
  Map<String, Object?> toJson() => {
    ..._baseJson('timer'),
    'duration': duration.inMicroseconds,
    'presetMinutes': presetMinutes,
  };

  @override
  bool operator ==(Object other) =>
      other is TimerSession &&
      other.startedAt == startedAt &&
      other.pausedTotal == pausedTotal &&
      other.pausedAt == pausedAt &&
      other.duration == duration &&
      other.presetMinutes == presetMinutes;

  @override
  int get hashCode =>
      Object.hash(startedAt, pausedTotal, pausedAt, duration, presetMinutes);
}

final class StopwatchSession extends Session {
  final List<Duration> laps;

  const StopwatchSession({
    required super.startedAt,
    super.pausedTotal,
    super.pausedAt,
    this.laps = const [],
  });

  factory StopwatchSession.start(DateTime now) =>
      StopwatchSession(startedAt: now.toUtc());

  StopwatchSession copyWith({
    Duration? pausedTotal,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    List<Duration>? laps,
  }) => StopwatchSession(
    startedAt: startedAt,
    pausedTotal: pausedTotal ?? this.pausedTotal,
    pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
    laps: laps ?? this.laps,
  );

  @override
  StopwatchSession pause(DateTime now) =>
      isPaused ? this : copyWith(pausedAt: now.toUtc());

  @override
  StopwatchSession resume(DateTime now) => isPaused
      ? copyWith(
          pausedTotal: pausedTotal + now.toUtc().difference(pausedAt!),
          clearPausedAt: true,
        )
      : this;

  @override
  Map<String, Object?> toJson() => {
    ..._baseJson('stopwatch'),
    'laps': [for (final lap in laps) lap.inMicroseconds],
  };

  @override
  bool operator ==(Object other) =>
      other is StopwatchSession &&
      other.startedAt == startedAt &&
      other.pausedTotal == pausedTotal &&
      other.pausedAt == pausedAt &&
      _listEquals(other.laps, laps);

  @override
  int get hashCode =>
      Object.hash(startedAt, pausedTotal, pausedAt, Object.hashAll(laps));
}

bool _listEquals(List<Duration> a, List<Duration> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
