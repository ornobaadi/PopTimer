import '../engine/session.dart';

/// The ongoing countdown/stopwatch notification (system chronometer). The
/// real implementation lands in Phase 4.
abstract interface class OngoingNotifier {
  /// Shows or updates the notification for [session] as of [now]: a live
  /// chronometer while running, a static "Paused" line while paused.
  Future<void> show(Session session, DateTime now);

  Future<void> clear();
}

class NoopOngoingNotifier implements OngoingNotifier {
  const NoopOngoingNotifier();

  @override
  Future<void> show(Session session, DateTime now) async {}

  @override
  Future<void> clear() async {}
}
