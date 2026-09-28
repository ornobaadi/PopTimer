import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/settings_providers.dart';
import '../engine/clock.dart';
import '../storage/session_store.dart';
import 'alarm_scheduler.dart';
import 'haptics_service.dart';
import 'ongoing_notifier.dart';
import 'sound_service.dart';

/// Every side effect the app has, as overridable providers. Tests override
/// them with fakes; `main()` overrides [sessionStoreProvider] with the store
/// loaded before `runApp`.

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => throw UnimplementedError('Override with the store loaded in main()'),
);

final alarmSchedulerProvider = Provider<AlarmScheduler>((ref) => const NoopAlarmScheduler());

final ongoingNotifierProvider = Provider<OngoingNotifier>((ref) => const NoopOngoingNotifier());

final soundServiceProvider = Provider<SoundService>((ref) => const NoopSoundService());

final hapticsServiceProvider = Provider<HapticsService>(
  (ref) => AppHapticsService(enabled: ref.watch(settingsProvider).hapticsEnabled),
);
