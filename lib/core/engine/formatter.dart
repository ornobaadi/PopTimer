/// Countdown line: `m:ss` under an hour, `h:mm:ss` from an hour up.
/// [seconds] is already rounded (see `displaySeconds`).
String formatCountdown(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = _two(s % 60);
  return h > 0 ? '$h:${_two(m)}:$sec' : '$m:$sec';
}

/// Stopwatch and overtime line: `+HH:MM:SS`, truncated to whole seconds.
/// Hours keep counting past 99 rather than wrapping.
String formatElapsed(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  return '+${_two(s ~/ 3600)}:${_two((s % 3600) ~/ 60)}:${_two(s % 60)}';
}

String _two(int n) => n.toString().padLeft(2, '0');
