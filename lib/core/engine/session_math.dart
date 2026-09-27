import 'formatter.dart';
import 'session.dart';

/// The stopwatch numeral stops growing here (PRD 5.4).
const int maxStopwatchNumeral = 999;

/// Running time of [s], excluding pauses.
Duration elapsed(Session s, DateTime now) {
  final end = s.pausedAt ?? now.toUtc();
  return end.difference(s.startedAt) - s.pausedTotal;
}

/// Time left on a timer. Negative means overtime.
Duration remaining(TimerSession s, DateTime now) =>
    s.duration - elapsed(s, now);

/// When the alarm should ring, or null while paused.
DateTime? fireAt(TimerSession s) =>
    s.isPaused ? null : s.startedAt.add(s.duration + s.pausedTotal);

bool isDone(TimerSession s, DateTime now) =>
    remaining(s, now) <= Duration.zero;

/// Remaining time rounded UP to whole seconds. The big numeral and the
/// countdown line both use this, so they can never disagree, and the numeral
/// never shows `0` while time remains.
int displaySeconds(Duration r) =>
    r <= Duration.zero ? 0 : (r.inMicroseconds / Duration.microsecondsPerSecond).ceil();

/// Big numeral text for the current state (PRD 5.4).
String bigNumeral(Session s, DateTime now) {
  switch (s) {
    case TimerSession():
      final secs = displaySeconds(remaining(s, now));
      if (secs <= 0) return '0';
      if (secs >= 60) return '${(secs / 60).ceil()}';
      return '$secs';
    case StopwatchSession():
      final e = elapsed(s, now);
      if (e < const Duration(minutes: 1)) return '+';
      final minutes = e.inMinutes;
      return '${minutes > maxStopwatchNumeral ? maxStopwatchNumeral : minutes}';
  }
}

/// Small line under the numeral: countdown, overtime or stopwatch elapsed.
String countdownText(Session s, DateTime now) {
  switch (s) {
    case TimerSession():
      final r = remaining(s, now);
      final secs = displaySeconds(r);
      return secs > 0 ? formatCountdown(secs) : formatElapsed(-r);
    case StopwatchSession():
      return formatElapsed(elapsed(s, now));
  }
}

/// The instant [bigNumeral] will next change, or null if it won't change
/// on its own (paused, timer done, stopwatch at its cap). The UI uses this to
/// fire the tick/rise animation exactly once per change.
DateTime? nextBoundary(Session s, DateTime now) {
  if (s.isPaused) return null;
  final utcNow = now.toUtc();
  switch (s) {
    case TimerSession():
      final r = remaining(s, utcNow);
      final secs = displaySeconds(r);
      if (secs <= 0) return null;
      // The numeral changes when remaining drops to exactly `threshold`
      // seconds: the next lower minute above 60 s, the next second below.
      final threshold = secs > 60 ? ((secs / 60).ceil() - 1) * 60 : secs - 1;
      return utcNow.add(r - Duration(seconds: threshold));
    case StopwatchSession():
      final e = elapsed(s, utcNow);
      if (e.inMinutes >= maxStopwatchNumeral) return null;
      return utcNow.add(Duration(minutes: e.inMinutes + 1) - e);
  }
}

/// +1 min: extends a running timer, or after time's up rings again one
/// minute from [now].
TimerSession addMinute(TimerSession s, DateTime now) {
  const minute = Duration(minutes: 1);
  final base = isDone(s, now) ? elapsed(s, now) : s.duration;
  return s.copyWith(duration: base + minute);
}
