import 'package:flutter_test/flutter_test.dart';
import 'package:poptimer/core/engine/clock.dart';
import 'package:poptimer/core/engine/session.dart';
import 'package:poptimer/core/engine/session_math.dart';
import 'package:poptimer/core/platform/notification_actions.dart';

import 'fakes.dart';

/// The handler that runs in the background isolate while the app is dead:
/// only the store, the engine and the platform interfaces.
void main() {
  late FakeClock clock;
  late EffectLog log;
  late LoggingStore store;
  late FakeAlarmScheduler alarm;
  late FakeOngoingNotifier ongoing;

  setUp(() {
    clock = FakeClock();
    log = EffectLog();
    alarm = FakeAlarmScheduler(log);
    ongoing = FakeOngoingNotifier(log);
  });

  Future<void> act(String action) => applyNotificationAction(
    action,
    store: store,
    alarm: alarm,
    ongoing: ongoing,
    clock: clock,
  );

  TimerSession tenMinutes() =>
      TimerSession.start(now: clock.now(), duration: const Duration(minutes: 10), presetMinutes: 10);

  test('Pause: persisted first, alarm cancelled, notification shows paused', () async {
    store = LoggingStore(log, session: tenMinutes());
    clock.advance(const Duration(minutes: 3));
    await act(NotificationAction.pause);

    final s = store.loadSession()!;
    expect(s.isPaused, isTrue);
    expect(log.entries, ['save', 'cancelAlarm', 'notify']);
    clock.advance(const Duration(hours: 1));
    expect(countdownText(s, clock.now()), '7:00');
  });

  test('Resume reschedules at the shifted fireAt', () async {
    store = LoggingStore(log, session: tenMinutes().pause(clock.now()));
    clock.advance(const Duration(minutes: 5));
    await act(NotificationAction.resume);
    expect(alarm.scheduledAt, clock.now().add(const Duration(minutes: 10)));
    expect(ongoing.showing!.isPaused, isFalse);
  });

  test('Cancel clears the session, alarm and notification', () async {
    store = LoggingStore(log, session: tenMinutes());
    await act(NotificationAction.cancel);
    expect(store.loadSession(), isNull);
    expect(log.entries, ['clear', 'cancelAlarm', 'clearNotification']);
  });

  test('+1 min on time\'s up rings again a minute from now', () async {
    store = LoggingStore(log, session: tenMinutes());
    clock.advance(const Duration(minutes: 12));
    await act(NotificationAction.addMinute);
    expect(alarm.scheduledAt, clock.now().add(const Duration(minutes: 1)));
    expect(countdownText(store.loadSession()!, clock.now()), '1:00');
  });

  test('Reset on a stopwatch clears it', () async {
    store = LoggingStore(log, session: StopwatchSession.start(clock.now()));
    await act(NotificationAction.reset);
    expect(store.loadSession(), isNull);
  });

  test('a stale action with no session just tidies up', () async {
    store = LoggingStore(log);
    await act(NotificationAction.pause);
    expect(log.entries, ['cancelAlarm', 'clearNotification']);
  });
}
