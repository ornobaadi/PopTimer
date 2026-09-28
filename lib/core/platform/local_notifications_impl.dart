import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../engine/formatter.dart';
import '../engine/session.dart';
import '../engine/session_math.dart';
import 'alarm_scheduler.dart';
import 'notification_actions.dart';
import 'notification_permissions.dart';
import 'ongoing_notifier.dart';

/// `flutter_local_notifications` (22.x) implementation of the alarm, the
/// ongoing notification and the permission prompt (`architecture.md` 5).
///
/// * Running countdown / stopwatch: an ongoing notification whose live time
///   is drawn by the system chronometer; the app never updates it.
/// * Time's up: an exact `exactAllowWhileIdle` notification on the alarm
///   channel (system alarm tone, alarm audio stream, insistent so it loops).
///   It also plays the in-app alarm, so there's one path for both.
class LocalNotifications implements AlarmScheduler, OngoingNotifier, NotificationPermissions {
  LocalNotifications(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const ongoingId = 1;
  static const alarmId = 2;

  static const _smallIcon = 'ic_stat_plus';

  /// Android's `Notification.FLAG_INSISTENT`: the sound loops until dismissed.
  static const _flagInsistent = 4;

  /// PRD 7: the alarm rings for up to 2 minutes.
  static const _alarmTimeout = Duration(minutes: 2);

  static const _ongoingChannel = AndroidNotificationChannel(
    'ongoing',
    'Running timer',
    description: 'The live countdown or stopwatch while one is running',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  static final _alarmChannel = AndroidNotificationChannel(
    'alarm_default',
    "Time's up",
    description: 'Rings when a timer reaches zero',
    importance: Importance.max,
    sound: const UriAndroidNotificationSound('content://settings/system/alarm_alert'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    vibrationPattern: Int64List.fromList([0, 400, 200, 400, 200, 400]),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Initialises the plugin and channels. [onAction] runs in the main isolate
  /// for taps while the app is alive; [onBackgroundAction] must be a
  /// top-level `@pragma('vm:entry-point')` function.
  Future<void> init({
    required DidReceiveNotificationResponseCallback onAction,
    required DidReceiveBackgroundNotificationResponseCallback onBackgroundAction,
  }) async {
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings(_smallIcon)),
      onDidReceiveNotificationResponse: onAction,
      onDidReceiveBackgroundNotificationResponse: onBackgroundAction,
    );
    await _android?.createNotificationChannel(_ongoingChannel);
    await _android?.createNotificationChannel(_alarmChannel);
  }

  // ─── Permissions ─────────────────────────────────────────────────────────

  @override
  Future<bool> request() async =>
      await _android?.requestNotificationsPermission() ?? true;

  // ─── Alarm ───────────────────────────────────────────────────────────────

  @override
  Future<void> schedule(TimerSession session, DateTime at) async {
    // Replace, don't stack: also silences one that is ringing right now.
    await _plugin.cancel(id: alarmId);
    final exact = await _android?.canScheduleExactNotifications() ?? true;
    await _plugin.zonedSchedule(
      id: alarmId,
      title: "Time's up",
      body: '${session.presetMinutes} min timer',
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _alarmChannel.id,
          _alarmChannel.name,
          channelDescription: _alarmChannel.description,
          icon: _smallIcon,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          sound: _alarmChannel.sound,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          vibrationPattern: _alarmChannel.vibrationPattern,
          additionalFlags: Int32List.fromList([_flagInsistent]),
          timeoutAfter: _alarmTimeout.inMilliseconds,
          autoCancel: false,
          color: const Color(0xFF1B1B1B),
          actions: const [
            AndroidNotificationAction(NotificationAction.dismiss, 'Dismiss'),
            AndroidNotificationAction(NotificationAction.addMinute, '+1 min'),
          ],
        ),
      ),
    );
  }

  @override
  Future<void> cancel() => _plugin.cancel(id: alarmId);

  // ─── Ongoing ─────────────────────────────────────────────────────────────

  @override
  Future<void> show(Session session, DateTime now) {
    final paused = session.isPaused;
    final (String title, String? body, int? whenMs, bool countDown, int? timeout) = switch (session) {
      TimerSession() when paused => (
        '${session.presetMinutes} min timer',
        'Paused · ${formatCountdown(displaySeconds(remaining(session, now)))} left',
        null,
        false,
        null,
      ),
      TimerSession() => (
        '${session.presetMinutes} min timer',
        null,
        fireAt(session)!.millisecondsSinceEpoch,
        true,
        // Gone at zero, when the alarm notification takes over.
        remaining(session, now).inMilliseconds.clamp(1, 1 << 31),
      ),
      StopwatchSession() when paused => (
        'Stopwatch',
        'Paused · ${formatElapsed(elapsed(session, now))}',
        null,
        false,
        null,
      ),
      StopwatchSession() => (
        'Stopwatch',
        null,
        now.subtract(elapsed(session, now)).millisecondsSinceEpoch,
        false,
        null,
      ),
    };
    final stopwatch = session is StopwatchSession;
    return _plugin.show(
      id: ongoingId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _ongoingChannel.id,
          _ongoingChannel.name,
          channelDescription: _ongoingChannel.description,
          icon: _smallIcon,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
          showWhen: whenMs != null,
          when: whenMs,
          usesChronometer: whenMs != null,
          chronometerCountDown: countDown,
          timeoutAfter: timeout,
          category: AndroidNotificationCategory.stopwatch,
          color: const Color(0xFF1B1B1B),
          actions: [
            AndroidNotificationAction(
              paused ? NotificationAction.resume : NotificationAction.pause,
              paused ? 'Resume' : 'Pause',
              cancelNotification: false,
            ),
            AndroidNotificationAction(
              stopwatch ? NotificationAction.reset : NotificationAction.cancel,
              stopwatch ? 'Reset' : 'Cancel',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Future<void> clear() => _plugin.cancel(id: ongoingId);
}
