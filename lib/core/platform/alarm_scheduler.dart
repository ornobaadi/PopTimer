import '../engine/session.dart';

/// Schedules the "time's up" alarm. The real implementation (exact alarm via
/// `flutter_local_notifications`) lands in Phase 4.
abstract interface class AlarmScheduler {
  /// Schedules (or replaces) the alarm for [session] at [at].
  Future<void> schedule(TimerSession session, DateTime at);

  /// Cancels the pending alarm and removes a showing alarm notification.
  Future<void> cancel();
}

class NoopAlarmScheduler implements AlarmScheduler {
  const NoopAlarmScheduler();

  @override
  Future<void> schedule(TimerSession session, DateTime at) async {}

  @override
  Future<void> cancel() async {}
}
