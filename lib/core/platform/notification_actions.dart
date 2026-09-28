import '../engine/clock.dart';
import '../engine/session.dart';
import '../engine/session_math.dart';
import '../storage/session_store.dart';
import 'alarm_scheduler.dart';
import 'ongoing_notifier.dart';

/// Action ids on the notifications (`design.md` section 9).
abstract final class NotificationAction {
  static const pause = 'pause';
  static const resume = 'resume';
  static const cancel = 'cancel';
  static const reset = 'reset';
  static const dismiss = 'dismiss';
  static const addMinute = 'add_minute';
}

/// Applies a notification action to the stored session with the same pure
/// engine functions the app uses. Runs in the main isolate or, when the app
/// is dead, in the plugin's background isolate; the app just restores from
/// the store next time it opens.
///
/// Same order as the controller: persist, then alarm, then notification.
Future<void> applyNotificationAction(
  String actionId, {
  required SessionStore store,
  required AlarmScheduler alarm,
  required OngoingNotifier ongoing,
  required Clock clock,
}) async {
  await store.reload();
  final session = store.loadSession();
  if (session == null) {
    // Stale notification from a session that no longer exists.
    await alarm.cancel();
    await ongoing.clear();
    return;
  }
  final now = clock.now();

  Future<void> commit(Session next) async {
    await store.saveSession(next);
    if (next is TimerSession && !next.isPaused && !isDone(next, now)) {
      await alarm.schedule(next, fireAt(next)!);
    } else {
      await alarm.cancel();
    }
    await ongoing.show(next, now);
  }

  switch (actionId) {
    case NotificationAction.pause:
      await commit(session.pause(now));
    case NotificationAction.resume:
      await commit(session.resume(now));
    case NotificationAction.addMinute when session is TimerSession:
      await commit(addMinute(session, now));
    case NotificationAction.cancel || NotificationAction.reset || NotificationAction.dismiss:
      await store.clearSession();
      await alarm.cancel();
      await ongoing.clear();
  }
}
