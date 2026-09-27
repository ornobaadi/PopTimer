import 'package:flutter_test/flutter_test.dart';
import 'package:poptimer/core/engine/clock.dart';
import 'package:poptimer/core/engine/formatter.dart';
import 'package:poptimer/core/engine/presets.dart';
import 'package:poptimer/core/engine/session.dart';
import 'package:poptimer/core/engine/session_math.dart';

void main() {
  late FakeClock clock;

  setUp(() => clock = FakeClock());

  TimerSession startTimer(Duration d) =>
      TimerSession.start(now: clock.now(), duration: d, presetMinutes: d.inMinutes);

  /// Moves the clock so exactly [left] remains on [s].
  void setRemaining(TimerSession s, Duration left) =>
      clock.current = fireAt(s)!.subtract(left);

  String numeral(Session s) => bigNumeral(s, clock.now());
  String line(Session s) => countdownText(s, clock.now());

  group('basics', () {
    test('10 min timer', () {
      final s = startTimer(const Duration(minutes: 10));
      expect((numeral(s), line(s)), ('10', '10:00'));
      clock.advance(const Duration(seconds: 1));
      expect((numeral(s), line(s)), ('10', '9:59'));
      clock.advance(const Duration(seconds: 59));
      expect((numeral(s), line(s)), ('9', '9:00'));
    });

    test('minutes round up: 599 s -> 10, 540 s -> 9', () {
      final s = startTimer(const Duration(minutes: 10));
      setRemaining(s, const Duration(seconds: 599));
      expect(numeral(s), '10');
      setRemaining(s, const Duration(seconds: 541));
      expect(numeral(s), '10');
      setRemaining(s, const Duration(seconds: 540));
      expect(numeral(s), '9');
    });
  });

  group('under a minute', () {
    test('60.0 s, 59.5 s, 59.0 s', () {
      final s = startTimer(const Duration(minutes: 2));
      setRemaining(s, const Duration(seconds: 60));
      expect((numeral(s), line(s)), ('1', '1:00'));
      setRemaining(s, const Duration(milliseconds: 59500));
      expect((numeral(s), line(s)), ('1', '1:00'));
      setRemaining(s, const Duration(seconds: 59));
      expect((numeral(s), line(s)), ('59', '0:59'));
    });

    test('numeral never shows 60', () {
      final s = startTimer(const Duration(minutes: 2));
      for (var ms = 0; ms <= 120000; ms += 250) {
        setRemaining(s, Duration(milliseconds: ms));
        expect(numeral(s), isNot('60'));
      }
    });

    test('last stretch sequence: 2, 1, 59 ... 1, 0', () {
      final s = startTimer(const Duration(minutes: 3));
      final seen = <String>[];
      setRemaining(s, const Duration(seconds: 61));
      for (var i = 0; i <= 61 * 10; i++) {
        final n = numeral(s);
        if (seen.isEmpty || seen.last != n) seen.add(n);
        clock.advance(const Duration(milliseconds: 100));
      }
      expect(seen, [
        '2',
        '1',
        for (var i = 59; i >= 1; i--) '$i',
        '0',
      ]);
    });
  });

  group('last seconds', () {
    test('0.4 s left shows 1, zero shows 0 and done', () {
      final s = startTimer(const Duration(minutes: 1));
      setRemaining(s, const Duration(milliseconds: 400));
      expect((numeral(s), line(s)), ('1', '0:01'));
      expect(isDone(s, clock.now()), isFalse);
      setRemaining(s, Duration.zero);
      expect(numeral(s), '0');
      expect(isDone(s, clock.now()), isTrue);
    });
  });

  group('pause', () {
    test('paused time does not count', () {
      var s = startTimer(const Duration(minutes: 5));
      clock.advance(const Duration(minutes: 2));
      s = s.pause(clock.now());
      expect(line(s), '3:00');
      clock.advance(const Duration(minutes: 10));
      expect(line(s), '3:00');
      s = s.resume(clock.now());
      clock.advance(const Duration(minutes: 1));
      expect(line(s), '2:00');
    });

    test('pause and resume are idempotent', () {
      var s = startTimer(const Duration(minutes: 5));
      expect(s.resume(clock.now()), same(s));
      s = s.pause(clock.now());
      clock.advance(const Duration(seconds: 5));
      expect(s.pause(clock.now()), same(s));
    });

    test('pausedTotal accumulates over 3 cycles', () {
      var s = startTimer(const Duration(minutes: 10));
      for (var i = 1; i <= 3; i++) {
        clock.advance(const Duration(seconds: 30));
        s = s.pause(clock.now());
        clock.advance(Duration(seconds: 10 * i));
        s = s.resume(clock.now());
      }
      expect(s.pausedTotal, const Duration(seconds: 60));
      expect(elapsed(s, clock.now()), const Duration(seconds: 90));
    });
  });

  group('fireAt', () {
    test('shifts later by each pause length, null while paused', () {
      var s = startTimer(const Duration(minutes: 5));
      final original = fireAt(s)!;
      expect(original, clock.now().add(const Duration(minutes: 5)));

      clock.advance(const Duration(minutes: 1));
      s = s.pause(clock.now());
      expect(fireAt(s), isNull);
      clock.advance(const Duration(seconds: 42));
      s = s.resume(clock.now());
      expect(fireAt(s), original.add(const Duration(seconds: 42)));
    });
  });

  group('overtime', () {
    test('-12 s shows 0 and +00:00:12', () {
      final s = startTimer(const Duration(minutes: 1));
      setRemaining(s, const Duration(seconds: -12));
      expect((numeral(s), line(s)), ('0', '+00:00:12'));
    });

    test('+1 min while running extends, after done rings a minute from now', () {
      var s = startTimer(const Duration(minutes: 5));
      clock.advance(const Duration(minutes: 1));
      s = addMinute(s, clock.now());
      expect(line(s), '5:00');

      setRemaining(s, const Duration(seconds: -30));
      s = addMinute(s, clock.now());
      expect(line(s), '1:00');
      expect(fireAt(s), clock.now().add(const Duration(minutes: 1)));
    });
  });

  group('stopwatch', () {
    test('+ under a minute, then elapsed minutes', () {
      final s = StopwatchSession.start(clock.now());
      expect((numeral(s), line(s)), ('+', '+00:00:00'));
      clock.advance(const Duration(seconds: 59));
      expect(numeral(s), '+');
      clock.advance(const Duration(seconds: 1));
      expect(numeral(s), '1');
      clock.advance(const Duration(minutes: 2, seconds: 16));
      expect((numeral(s), line(s)), ('3', '+00:03:16'));
    });

    test('100 min shows 100, capped at 999', () {
      final s = StopwatchSession.start(clock.now());
      clock.advance(const Duration(minutes: 100));
      expect(numeral(s), '100');
      clock.advance(const Duration(minutes: 1000));
      expect(numeral(s), '999');
      expect(nextBoundary(s, clock.now()), isNull);
    });

    test('pause freezes elapsed', () {
      var s = StopwatchSession.start(clock.now());
      clock.advance(const Duration(seconds: 20));
      s = s.pause(clock.now());
      clock.advance(const Duration(hours: 1));
      expect(line(s), '+00:00:20');
      s = s.resume(clock.now());
      clock.advance(const Duration(seconds: 5));
      expect(line(s), '+00:00:25');
    });
  });

  group('nextBoundary', () {
    test('timer above a minute points at the next minute change', () {
      final s = startTimer(const Duration(minutes: 10));
      final b = nextBoundary(s, clock.now())!;
      expect(b, clock.now().add(const Duration(minutes: 1)));
      clock.current = b.subtract(const Duration(microseconds: 1));
      expect(numeral(s), '10');
      clock.current = b;
      expect(numeral(s), '9');
    });

    test('the 1:00 -> 59 step and each second after', () {
      final s = startTimer(const Duration(minutes: 2));
      setRemaining(s, const Duration(seconds: 90));
      expect(nextBoundary(s, clock.now()), fireAt(s)!.subtract(const Duration(seconds: 60)));
      setRemaining(s, const Duration(seconds: 60));
      expect(nextBoundary(s, clock.now()), fireAt(s)!.subtract(const Duration(seconds: 59)));
      setRemaining(s, const Duration(milliseconds: 700));
      expect(nextBoundary(s, clock.now()), fireAt(s));
    });

    test('null when paused or done', () {
      final s = startTimer(const Duration(minutes: 1));
      expect(nextBoundary(s.pause(clock.now()), clock.now()), isNull);
      setRemaining(s, const Duration(seconds: -1));
      expect(nextBoundary(s, clock.now()), isNull);
      final stopwatch = StopwatchSession.start(clock.now()).pause(clock.now());
      expect(nextBoundary(stopwatch, clock.now()), isNull);
    });

    test('stopwatch points at the next whole minute', () {
      final s = StopwatchSession.start(clock.now());
      clock.advance(const Duration(seconds: 75));
      expect(nextBoundary(s, clock.now()), clock.now().add(const Duration(seconds: 45)));
    });
  });

  group('serialization', () {
    test('round-trips every variant', () {
      final timer = startTimer(const Duration(minutes: 10));
      clock.advance(const Duration(seconds: 30));
      final pausedTimer = timer.pause(clock.now());
      clock.advance(const Duration(seconds: 30));
      final resumedTimer = pausedTimer.resume(clock.now());
      final stopwatch = StopwatchSession.start(clock.now());
      final withLaps = stopwatch
          .copyWith(laps: const [Duration(seconds: 12), Duration(seconds: 40)])
          .pause(clock.now());

      for (final s in <Session>[timer, pausedTimer, resumedTimer, stopwatch, withLaps]) {
        expect(Session.fromJson(s.toJson()), s);
      }
    });

    test('unknown type throws', () {
      expect(
        () => Session.fromJson({'type': 'egg', 'startedAt': 0, 'pausedTotal': 0}),
        throwsFormatException,
      );
    });
  });

  group('restore', () {
    test('persisted timer restored 2 h later is done with overtime', () {
      final s = startTimer(const Duration(minutes: 10));
      final json = s.toJson();
      clock.advance(const Duration(hours: 2));
      final restored = Session.fromJson(json) as TimerSession;
      expect(isDone(restored, clock.now()), isTrue);
      expect((numeral(restored), line(restored)), ('0', '+01:50:00'));
    });
  });

  group('formatting', () {
    test('countdown switches to h:mm:ss at an hour', () {
      expect(formatCountdown(59 * 60 + 59), '59:59');
      expect(formatCountdown(3600), '1:00:00');
      expect(formatCountdown(90 * 60), '1:30:00');
      expect(formatCountdown(-5), '0:00');
    });

    test('90 min preset shows 90 and 1:30:00', () {
      final s = startTimer(const Duration(minutes: 90));
      expect((numeral(s), line(s)), ('90', '1:30:00'));
    });

    test('elapsed hours keep counting, no negative zero', () {
      expect(formatElapsed(const Duration(hours: 1, minutes: 2, seconds: 3)), '+01:02:03');
      expect(formatElapsed(const Duration(hours: 123)), '+123:00:00');
      expect(formatElapsed(const Duration(milliseconds: -400)), '+00:00:00');
      expect(formatElapsed(const Duration(milliseconds: 999)), '+00:00:00');
    });
  });

  group('presets', () {
    test('custom value inserts sorted without duplicates', () {
      expect(insertPreset(defaultPresets, 7).sublist(3, 6), [5, 7, 10]);
      expect(insertPreset(defaultPresets, 10), defaultPresets);
      expect(insertPreset(defaultPresets, 120).last, 120);
    });

    test('recents: newest first, deduped, max 3', () {
      var r = <int>[];
      for (final m in [7, 12, 7, 40, 99]) {
        r = addRecent(r, m);
      }
      expect(r, [99, 40, 7]);
    });

    test('preset index falls back to the default', () {
      expect(presetIndexOf(defaultPresets, 10), 4);
      expect(presetIndexOf(defaultPresets, 7), defaultPresets.indexOf(defaultPresetMinutes));
      expect(presetIndexOf(const [1, 2], 7), 0);
    });
  });

  test('SystemClock returns UTC', () {
    expect(const SystemClock().now().isUtc, isTrue);
  });
}
