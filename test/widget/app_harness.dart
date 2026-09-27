import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poptimer/app/app.dart';
import 'package:poptimer/core/engine/clock.dart';
import 'package:poptimer/core/engine/session.dart';
import 'package:poptimer/core/platform/platform_providers.dart';
import 'package:poptimer/core/storage/session_store.dart';
import 'package:poptimer/features/timer/presentation/widgets/animated_numeral.dart';

import '../controller/fakes.dart';

/// The whole app on a 360 x 800 dp phone, with a fake clock and fake
/// platform services.
class AppHarness {
  AppHarness(this.tester, {Session? session, int? lastPreset})
    : store = InMemorySessionStore(session: session, lastPresetMinutes: lastPreset);

  final WidgetTester tester;
  final clock = FakeClock();
  final log = EffectLog();
  final haptics = FakeHaptics();
  late final alarm = FakeAlarmScheduler(log);
  late final sound = FakeSoundService(log);
  final InMemorySessionStore store;

  Future<void> pumpApp() async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(clock),
          sessionStoreProvider.overrideWithValue(store),
          alarmSchedulerProvider.overrideWithValue(alarm),
          ongoingNotifierProvider.overrideWithValue(FakeOngoingNotifier(log)),
          soundServiceProvider.overrideWithValue(sound),
          hapticsServiceProvider.overrideWithValue(haptics),
        ],
        child: const PopTimerApp(),
      ),
    );
    await settle();
  }

  /// Lets queued intents finish and a surface reveal play out. Never uses
  /// pumpAndSettle: speed lines and the paused blink animate forever.
  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Moves the fake clock and renders a frame at the new time.
  Future<void> advance(Duration d) async {
    clock.advance(d);
    await settle();
  }

  Future<void> tap() async {
    await tester.tapAt(tester.getCenter(find.byType(Scaffold)));
    await settle();
  }

  /// Presses for [d], then releases. Pumps real-device-sized frames:
  /// animations only start counting on the first frame after they begin.
  Future<void> press(Duration d) async {
    final gesture = await tester.startGesture(tester.getCenter(find.byType(Scaffold)));
    const frame = Duration(milliseconds: 16);
    for (var t = Duration.zero; t < d; t += frame) {
      await tester.pump(frame);
    }
    await gesture.up();
    await settle();
  }

  /// Text of the live (top-most) numeral.
  String get numeral => tester.widgetList<AnimatedNumeral>(find.byType(AnimatedNumeral)).last.text;
}
