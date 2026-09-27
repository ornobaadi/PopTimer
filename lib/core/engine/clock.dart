/// The only source of "now" in the app. Everything that touches time takes a
/// [Clock] so tests can drive time with [FakeClock] instead of sleeping.
abstract interface class Clock {
  /// Current wall-clock time in UTC.
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// A clock that only moves when told to.
class FakeClock implements Clock {
  DateTime current;

  FakeClock([DateTime? start])
    : current = (start ?? DateTime.utc(2026, 1, 1, 12)).toUtc();

  void advance(Duration d) => current = current.add(d);

  @override
  DateTime now() => current;
}
