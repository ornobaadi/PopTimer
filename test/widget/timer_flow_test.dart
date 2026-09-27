import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poptimer/core/engine/presets.dart';
import 'package:poptimer/core/engine/session.dart';
import 'package:poptimer/features/timer/presentation/browse_view.dart';
import 'package:poptimer/features/timer/presentation/session_view.dart';
import 'package:poptimer/features/timer/presentation/widgets/speed_lines.dart';

import 'app_harness.dart';

void main() {
  testWidgets('tap starts the 5 minute timer: lit, speed lines, 5:00', (tester) async {
    final app = AppHarness(tester);
    await app.pumpApp();
    await app.tap();

    expect(find.byType(BrowseView), findsNothing);
    expect(find.byType(SpeedLines), findsOneWidget);
    expect(app.numeral, '5');
    expect(find.text('5:00'), findsOneWidget);
    expect(app.haptics.events, contains('start'));
    expect(app.alarm.scheduledAt, app.clock.now().add(const Duration(minutes: 5)));
  });

  testWidgets('the numeral follows the clock, minute by minute then by second', (tester) async {
    final app = AppHarness(tester, lastPreset: 2);
    await app.pumpApp();
    await app.tap();

    await app.advance(const Duration(seconds: 1));
    expect((app.numeral, find.text('1:59').evaluate().length), ('2', 1));

    await app.advance(const Duration(seconds: 59));
    expect(app.numeral, '1');
    expect(app.haptics.events, contains('minuteTick'));

    await app.advance(const Duration(seconds: 1));
    expect(app.numeral, '59');

    await app.advance(const Duration(seconds: 50));
    expect(app.numeral, '9');
    expect(app.haptics.events, contains('secondTick'));
  });

  testWidgets("reaching zero inverts to Paper and rings; tap dismisses", (tester) async {
    final app = AppHarness(tester, lastPreset: 1);
    await app.pumpApp();
    await app.tap();

    await app.advance(const Duration(minutes: 1));
    expect(app.numeral, '0');
    expect(app.sound.ringing, isTrue);
    expect(app.haptics.events, contains('timeUp'));

    await app.advance(const Duration(seconds: 12));
    expect(find.text('+00:00:12'), findsOneWidget);

    await app.tap();
    expect(find.byType(BrowseView), findsOneWidget);
    expect(app.sound.ringing, isFalse);
  });

  testWidgets('tap pauses (blinking, dimmed), time stands still, tap resumes', (tester) async {
    final app = AppHarness(tester);
    await app.pumpApp();
    await app.tap();
    await app.advance(const Duration(seconds: 18));
    await app.tap();

    expect(tester.widget<SessionView>(find.byType(SessionView)).blinkLine, isTrue);
    expect(tester.widget<SpeedLines>(find.byType(SpeedLines)).paused, isTrue);
    await app.advance(const Duration(minutes: 10));
    expect(find.text('4:42'), findsOneWidget);

    await app.tap();
    await app.advance(const Duration(seconds: 2));
    expect(find.text('4:40'), findsOneWidget);
  });

  testWidgets('a full hold cancels; releasing early does nothing', (tester) async {
    final app = AppHarness(tester);
    await app.pumpApp();
    await app.tap();

    await app.press(const Duration(milliseconds: 400));
    expect(find.byType(SessionView), findsOneWidget, reason: 'released early');
    expect(app.store.loadSession(), isNotNull);

    await app.press(const Duration(milliseconds: 700));
    expect(find.byType(BrowseView), findsOneWidget);
    expect(app.store.loadSession(), isNull);
    expect(app.haptics.events.last, 'holdComplete');
  });

  testWidgets('+ page starts the stopwatch on Paper; hold resets', (tester) async {
    final app = AppHarness(tester, lastPreset: 90);
    await app.pumpApp();
    await tester.fling(find.byType(PageView), const Offset(0, -300), 1500);
    await app.settle();
    await app.tap();

    expect(app.numeral, '+');
    expect(find.text('+00:00:00'), findsOneWidget);
    await app.advance(const Duration(minutes: 3, seconds: 16));
    expect((app.numeral, find.text('+00:03:16').evaluate().length), ('3', 1));

    await app.press(const Duration(milliseconds: 700));
    expect(find.byType(BrowseView), findsOneWidget);
  });

  testWidgets('Reduce Motion: static speed lines, still works', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final app = AppHarness(tester);
    await app.pumpApp();
    await app.tap();

    expect(tester.widget<SpeedLines>(find.byType(SpeedLines)).reduceMotion, isTrue);
    await app.advance(const Duration(minutes: 1));
    expect(app.numeral, '4');
  });

  testWidgets('a timer restored after process death picks up where it was', (tester) async {
    final app = AppHarness(
      tester,
      session: TimerSession.start(
        now: DateTime.utc(2026, 1, 1, 11, 57),
        duration: const Duration(minutes: 10),
        presetMinutes: 10,
      ),
    );
    await app.pumpApp(); // FakeClock starts at 12:00, 3 minutes in
    expect(app.numeral, '7');
    expect(find.text('7:00'), findsOneWidget);
    // Resume on launch re-asserts the alarm.
    expect(app.alarm.scheduledAt, DateTime.utc(2026, 1, 1, 12, 7));
    expect(defaultPresets, contains(10));
  });
}
