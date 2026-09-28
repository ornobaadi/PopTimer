import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poptimer/core/engine/clock.dart';
import 'package:poptimer/core/engine/presets.dart';
import 'package:poptimer/core/engine/session.dart';
import 'package:poptimer/core/engine/session_math.dart';
import 'package:poptimer/core/platform/platform_providers.dart';
import 'package:poptimer/core/theme/skin.dart';
import 'package:poptimer/features/timer/application/session_controller.dart';
import 'package:poptimer/features/timer/application/session_state.dart';

import 'fakes.dart';

void main() {
  late FakeClock clock;
  late EffectLog log;
  late LoggingStore store;
  late FakeAlarmScheduler alarm;
  late FakeOngoingNotifier ongoing;
  late FakeSoundService sound;
  late FakeHaptics haptics;
  late ProviderContainer container;

  ProviderContainer build({Session? session, int? lastPreset}) {
    store = LoggingStore(log, session: session, lastPresetMinutes: lastPreset);
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        sessionStoreProvider.overrideWithValue(store),
        alarmSchedulerProvider.overrideWithValue(alarm),
        ongoingNotifierProvider.overrideWithValue(ongoing),
        soundServiceProvider.overrideWithValue(sound),
        hapticsServiceProvider.overrideWithValue(haptics),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    clock = FakeClock();
    log = EffectLog();
    alarm = FakeAlarmScheduler(log);
    ongoing = FakeOngoingNotifier(log);
    sound = FakeSoundService(log);
    haptics = FakeHaptics();
    container = build();
  });

  SessionController controller() => container.read(sessionControllerProvider.notifier);
  SessionState state() => container.read(sessionControllerProvider);

  group('browse', () {
    test('first launch opens on 5 in Browse', () {
      expect(state().mode, Mode.browse);
      expect(state().surface, Surface.night);
      expect(state().presets[state().selectedPresetIndex], defaultPresetMinutes);
    });

    test('opens on the last-used preset', () {
      container = build(lastPreset: 25);
      expect(state().presets[state().selectedPresetIndex], 25);
    });

    test('selecting a preset snaps, remembers it, and ignores repeats', () async {
      await controller().selectPreset(4);
      await controller().selectPreset(4);
      expect(state().selectedPresetIndex, 4);
      expect(store.lastPresetMinutes, 10);
      expect(haptics.events, ['pageSnap']);
    });

    test('the + page does not overwrite the last preset', () async {
      await controller().selectPreset(defaultPresets.length);
      expect(state().isStopwatchPageSelected, isTrue);
      expect(store.lastPresetMinutes, isNull);
    });
  });

  group('timer', () {
    test('start persists, then schedules at the exact fireAt, then notifies', () async {
      await controller().selectPreset(4); // 10 min
      log.clear();
      await controller().startSelected();

      expect(state().mode, Mode.timerRunning);
      expect(state().surface, Surface.night);
      expect(log.entries, ['save', 'schedule', 'notify']);
      expect(alarm.scheduledAt, clock.now().add(const Duration(minutes: 10)));
      expect(store.loadSession(), state().session);
      expect(haptics.events.last, 'start');
    });

    test('pause cancels the alarm, resume reschedules later by the pause', () async {
      await controller().startTimer();
      final firstFire = alarm.scheduledAt!;
      clock.advance(const Duration(minutes: 1));
      log.clear();

      await controller().togglePause();
      expect(state().mode, Mode.timerPaused);
      expect(log.entries, ['save', 'cancelAlarm', 'notify']);
      expect(alarm.scheduledAt, isNull);

      clock.advance(const Duration(seconds: 42));
      await controller().togglePause();
      expect(state().mode, Mode.timerRunning);
      expect(alarm.scheduledAt, firstFire.add(const Duration(seconds: 42)));
    });

    test('cancel clears everything and returns to the preset that ran', () async {
      await controller().selectPreset(6); // 20 min
      await controller().startTimer();
      await controller().togglePause();
      log.clear();

      await controller().cancel();
      expect(state().mode, Mode.browse);
      expect(state().session, isNull);
      expect(state().selectedPresetIndex, 6);
      expect(log.entries.first, 'clear');
      expect(log.entries, containsAll(['cancelAlarm', 'clearNotification']));
      expect(store.loadSession(), isNull);
      expect(haptics.events.last, 'holdComplete');
    });

    test('a quick swipe then tap starts what was swiped to', () async {
      // Not awaited: the tap lands while the page change is still queued.
      controller().selectPreset(4);
      await controller().startSelected();
      expect((state().session! as TimerSession).presetMinutes, 10);

      await controller().cancel();
      controller().selectPreset(defaultPresets.length);
      await controller().startSelected();
      expect(state().mode, Mode.stopwatchRunning);
    });

    test('a tap can not start a second session', () async {
      await controller().startTimer();
      final first = state().session;
      await controller().startTimer();
      await controller().startStopwatch();
      expect(state().session, same(first));
    });
  });

  group("time's up", () {
    Future<void> runToZero() async {
      await controller().startTimer(); // 5 min
      clock.advance(const Duration(minutes: 5));
      await controller().onTimerReachedZero();
    }

    test('reaching zero inverts to Paper, rings and buzzes, once', () async {
      await runToZero();
      await controller().onTimerReachedZero();
      expect(state().mode, Mode.timerDone);
      expect(state().surface, Surface.paper);
      expect(sound.ringing, isTrue);
      expect(haptics.events.where((e) => e == 'timeUp'), hasLength(1));
      expect(log.entries.where((e) => e == 'ring'), hasLength(1));
    });

    test('ignored before the timer is actually at zero', () async {
      await controller().startTimer();
      clock.advance(const Duration(minutes: 4));
      await controller().onTimerReachedZero();
      expect(state().mode, Mode.timerRunning);
    });

    test('tap dismisses: silent, cleared, back to Browse', () async {
      await runToZero();
      await controller().dismissAlarm();
      expect(state().mode, Mode.browse);
      expect(sound.ringing, isFalse);
      expect(alarm.scheduledAt, isNull);
      expect(store.loadSession(), isNull);
    });

    test('pause does nothing while ringing', () async {
      await runToZero();
      await controller().togglePause();
      expect(state().mode, Mode.timerDone);
    });

    test('hold restarts the same timer from now', () async {
      await runToZero();
      clock.advance(const Duration(seconds: 12));
      await controller().restartTimer();
      expect(state().mode, Mode.timerRunning);
      expect(sound.ringing, isFalse);
      expect(alarm.scheduledAt, clock.now().add(const Duration(minutes: 5)));
    });

    test('+1 min after time is up rings again in a minute', () async {
      await runToZero();
      clock.advance(const Duration(seconds: 30));
      await controller().addMinute();
      expect(state().mode, Mode.timerRunning);
      expect(sound.ringing, isFalse);
      expect(alarm.scheduledAt, clock.now().add(const Duration(minutes: 1)));
    });
  });

  test('starting asks for notifications; denied still runs', () async {
    final permissions = FakePermissions(grant: false);
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        sessionStoreProvider.overrideWithValue(LoggingStore(log)),
        alarmSchedulerProvider.overrideWithValue(alarm),
        ongoingNotifierProvider.overrideWithValue(ongoing),
        soundServiceProvider.overrideWithValue(sound),
        hapticsServiceProvider.overrideWithValue(haptics),
        notificationPermissionsProvider.overrideWithValue(permissions),
      ],
    );
    addTearDown(container.dispose);
    await controller().startTimer();
    expect(permissions.asked, 1);
    expect(state().mode, Mode.timerRunning);
    expect(state().notificationsGranted, isFalse);
  });

  group('stopwatch', () {
    test('+ page starts a stopwatch on Paper', () async {
      await controller().selectPreset(defaultPresets.length);
      log.clear();
      await controller().startSelected();
      expect(state().mode, Mode.stopwatchRunning);
      expect(state().surface, Surface.paper);
      expect(log.entries, ['save', 'notify']);
      expect(alarm.scheduledAt, isNull);
    });

    test('pause, resume and reset back to the + page', () async {
      await controller().startStopwatch();
      await controller().togglePause();
      expect(state().mode, Mode.stopwatchPaused);
      await controller().togglePause();
      expect(state().mode, Mode.stopwatchRunning);

      await controller().cancel(); // not a timer: ignored
      expect(state().mode, Mode.stopwatchRunning);
      await controller().reset();
      expect(state().mode, Mode.browse);
      expect(state().isStopwatchPageSelected, isTrue);
    });
  });

  group('restore', () {
    test('a running timer survives process death', () async {
      final session = TimerSession.start(
        now: clock.now(),
        duration: const Duration(minutes: 10),
        presetMinutes: 10,
      );
      clock.advance(const Duration(minutes: 3));
      container = build(session: session);

      expect(state().mode, Mode.timerRunning);
      expect(state().presets[state().selectedPresetIndex], 10);
      expect(countdownText(state().session!, clock.now()), '7:00');
    });

    test('resume re-asserts the alarm and notification', () async {
      container = build(
        session: TimerSession.start(now: clock.now(), duration: const Duration(minutes: 10), presetMinutes: 10),
      );
      await controller().onAppResumed();
      expect(log.entries, ['schedule', 'notify']);
      expect(ongoing.showing, isNotNull);
    });

    test('resumed 2 h later: done with overtime, no in-app ringing', () async {
      final session = TimerSession.start(
        now: clock.now(),
        duration: const Duration(minutes: 10),
        presetMinutes: 10,
      );
      container = build(session: session);
      clock.advance(const Duration(hours: 2));
      await controller().onAppResumed();

      expect(state().mode, Mode.timerDone);
      expect(countdownText(state().session!, clock.now()), '+01:50:00');
      expect(sound.ringing, isFalse);
      expect(log.entries, isNot(contains('schedule')));
    });

    test('resume picks up a session cleared in the background', () async {
      container = build(session: StopwatchSession.start(clock.now()));
      expect(state().mode, Mode.stopwatchRunning);
      await store.clearSession();
      await controller().onAppResumed();
      expect(state().mode, Mode.browse);
    });
  });
}
