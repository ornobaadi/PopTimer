import 'package:poptimer/core/engine/session.dart';
import 'package:poptimer/core/platform/alarm_scheduler.dart';
import 'package:poptimer/core/platform/haptics_service.dart';
import 'package:poptimer/core/platform/ongoing_notifier.dart';
import 'package:poptimer/core/platform/sound_service.dart';
import 'package:poptimer/core/storage/session_store.dart';

/// Every fake writes to one shared log, so tests can check the order of
/// side effects as well as the calls themselves.
class EffectLog {
  final entries = <String>[];

  void add(String e) => entries.add(e);
  void clear() => entries.clear();
}

class LoggingStore extends InMemorySessionStore {
  LoggingStore(this.log, {super.session, super.lastPresetMinutes});

  final EffectLog log;

  @override
  Future<void> saveSession(Session session) async {
    log.add('save');
    await super.saveSession(session);
  }

  @override
  Future<void> clearSession() async {
    log.add('clear');
    await super.clearSession();
  }
}

class FakeAlarmScheduler implements AlarmScheduler {
  FakeAlarmScheduler(this.log);

  final EffectLog log;
  DateTime? scheduledAt;

  @override
  Future<void> schedule(TimerSession session, DateTime at) async {
    scheduledAt = at;
    log.add('schedule');
  }

  @override
  Future<void> cancel() async {
    scheduledAt = null;
    log.add('cancelAlarm');
  }
}

class FakeOngoingNotifier implements OngoingNotifier {
  FakeOngoingNotifier(this.log);

  final EffectLog log;
  Session? showing;

  @override
  Future<void> show(Session session, DateTime now) async {
    showing = session;
    log.add('notify');
  }

  @override
  Future<void> clear() async {
    showing = null;
    log.add('clearNotification');
  }
}

class FakeSoundService implements SoundService {
  FakeSoundService(this.log);

  final EffectLog log;
  bool ringing = false;

  @override
  Future<void> startAlarm() async {
    ringing = true;
    log.add('ring');
  }

  @override
  Future<void> stopAlarm() async {
    ringing = false;
    log.add('silence');
  }
}

class FakeHaptics implements HapticsService {
  final events = <String>[];

  @override
  void pageSnap() => events.add('pageSnap');
  @override
  void start() => events.add('start');
  @override
  void pauseToggle() => events.add('pauseToggle');
  @override
  void minuteTick() => events.add('minuteTick');
  @override
  void secondTick() => events.add('secondTick');
  @override
  void holdComplete() => events.add('holdComplete');
  @override
  void timeUp() => events.add('timeUp');
}
