import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/engine/clock.dart';
import 'core/platform/local_notifications_impl.dart';
import 'core/platform/notification_actions.dart';
import 'core/platform/platform_providers.dart';
import 'core/storage/session_store.dart';
import 'core/storage/settings_store.dart';
import 'features/settings/application/settings_providers.dart';
import 'features/timer/application/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loaded before runApp so the session is restored before the first frame.
  final prefs = await SharedPreferences.getInstance();
  final sessionStore = PrefsSessionStore(prefs);
  final notifications = LocalNotifications(FlutterLocalNotificationsPlugin());

  final container = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(sessionStore),
      settingsStoreProvider.overrideWithValue(PrefsSettingsStore(prefs)),
      alarmSchedulerProvider.overrideWithValue(notifications),
      ongoingNotifierProvider.overrideWithValue(notifications),
      notificationPermissionsProvider.overrideWithValue(notifications),
    ],
  );

  await notifications.init(
    // A notification action while the app is alive: apply it, then let the
    // controller pick up the stored result.
    onAction: (response) async {
      final action = response.actionId;
      if (action == null) return; // plain tap just opens the app
      await applyNotificationAction(
        action,
        store: sessionStore,
        alarm: notifications,
        ongoing: notifications,
        clock: const SystemClock(),
      );
      await container.read(sessionControllerProvider.notifier).onAppResumed();
    },
    onBackgroundAction: onBackgroundNotificationAction,
  );

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Edge to edge: the surface and glyphs run under the system bars.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(UncontrolledProviderScope(container: container, child: const PopTimerApp()));
}

/// Notification actions while the app is dead run here, in a background
/// isolate: no UI, just the store, the engine and the plugin.
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationAction(NotificationResponse response) async {
  final action = response.actionId;
  if (action == null) return;
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final notifications = LocalNotifications(FlutterLocalNotificationsPlugin());
  await applyNotificationAction(
    action,
    store: PrefsSessionStore(prefs),
    alarm: notifications,
    ongoing: notifications,
    clock: const SystemClock(),
  );
}
