import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/engine/presets.dart';
import '../../../core/engine/session.dart';
import '../../../core/engine/session_math.dart' as math;
import '../../../core/platform/platform_providers.dart';
import 'session_state.dart';

final sessionControllerProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Owns [SessionState] and every side effect, through injected interfaces.
///
/// Never ticks and never animates: the UI owns a frame ticker and calls
/// [onTimerReachedZero] when it sees the timer hit zero.
///
/// Every intent runs in order: compute the new session, persist it, then
/// schedule or cancel the alarm, update the ongoing notification, and emit.
/// Persisting first means a crash mid-way never leaves an alarm with no
/// session. Intents are queued so they never interleave.
class SessionController extends Notifier<SessionState> {
  Future<void> _queue = Future.value();

  DateTime get _now => ref.read(clockProvider).now();

  @override
  SessionState build() {
    final store = ref.read(sessionStoreProvider);
    final session = store.loadSession();
    const presets = defaultPresets;
    return SessionState(
      mode: SessionState.modeFor(session, _now),
      session: session,
      presets: presets,
      selectedPresetIndex: _indexFor(
        session,
        presets,
        presetIndexOf(presets, store.lastPresetMinutes ?? defaultPresetMinutes),
      ),
    );
  }

  // ─── Browse ──────────────────────────────────────────────────────────────

  Future<void> selectPreset(int index) => _run(() async {
    if (state.mode != Mode.browse || index == state.selectedPresetIndex) return;
    ref.read(hapticsServiceProvider).pageSnap();
    state = state.copyWith(selectedPresetIndex: index);
    if (index < state.presets.length) {
      await ref.read(sessionStoreProvider).saveLastPreset(state.presets[index]);
    }
  });

  /// Tap in Browse: start the centred preset, or the stopwatch on the + page.
  /// Decided inside the queue, so a tap right after a swipe sees the new page.
  Future<void> startSelected() => _run(
    () => state.isStopwatchPageSelected ? _startStopwatch() : _startTimer(),
  );

  Future<void> startTimer() => _run(_startTimer);

  Future<void> startStopwatch() => _run(_startStopwatch);

  Future<void> _startTimer() async {
    if (state.session != null || state.isStopwatchPageSelected) return;
    final minutes = state.presets[state.selectedPresetIndex];
    ref.read(hapticsServiceProvider).start();
    await _commit(
      TimerSession.start(
        now: _now,
        duration: Duration(minutes: minutes),
        presetMinutes: minutes,
      ),
    );
  }

  Future<void> _startStopwatch() async {
    if (state.session != null) return;
    ref.read(hapticsServiceProvider).start();
    await _commit(StopwatchSession.start(_now));
  }

  // ─── Running session ─────────────────────────────────────────────────────

  Future<void> togglePause() => _run(() async {
    final s = state.session;
    if (s == null || state.mode == Mode.timerDone) return;
    final now = _now;
    ref.read(hapticsServiceProvider).pauseToggle();
    await _commit(s.isPaused ? s.resume(now) : s.pause(now));
  });

  /// Hold while a timer runs or is paused.
  Future<void> cancel() => _run(() async {
    if (state.mode != Mode.timerRunning && state.mode != Mode.timerPaused) return;
    ref.read(hapticsServiceProvider).holdComplete();
    await _clear();
  });

  /// Hold on the stopwatch.
  Future<void> reset() => _run(() async {
    if (!state.mode.isStopwatch) return;
    ref.read(hapticsServiceProvider).holdComplete();
    await _clear();
  });

  /// +1 min: extends a running or paused timer; after time's up, rings
  /// again one minute from now.
  Future<void> addMinute() => _run(() async {
    final s = state.session;
    if (s is! TimerSession) return;
    if (state.mode == Mode.timerDone) await ref.read(soundServiceProvider).stopAlarm();
    await _commit(math.addMinute(s, _now));
  });

  // ─── Time's up ───────────────────────────────────────────────────────────

  /// Called by the UI's frame ticker when it sees the timer reach zero.
  /// Idempotent.
  Future<void> onTimerReachedZero() => _run(() async {
    final s = state.session;
    if (state.mode != Mode.timerRunning || s is! TimerSession || !math.isDone(s, _now)) {
      return;
    }
    state = state.copyWith(mode: Mode.timerDone);
    ref.read(hapticsServiceProvider).timeUp();
    await ref.read(soundServiceProvider).startAlarm();
  });

  /// Tap on time's up: silence and return to Browse.
  Future<void> dismissAlarm() => _run(() async {
    if (state.mode != Mode.timerDone) return;
    await _clear();
  });

  /// Hold on time's up: run the same timer again.
  Future<void> restartTimer() => _run(() async {
    final s = state.session;
    if (state.mode != Mode.timerDone || s is! TimerSession) return;
    ref.read(hapticsServiceProvider).holdComplete();
    await ref.read(soundServiceProvider).stopAlarm();
    await _commit(
      TimerSession.start(
        now: _now,
        duration: Duration(minutes: s.presetMinutes),
        presetMinutes: s.presetMinutes,
      ),
    );
  });

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  /// Launch and resume: reload (a notification action may have changed the
  /// session in the background), recompute, and re-assert the alarm and the
  /// ongoing notification in case either was lost.
  Future<void> onAppResumed() => _run(() async {
    final store = ref.read(sessionStoreProvider);
    await store.reload();
    final session = store.loadSession();
    final now = _now;
    final mode = SessionState.modeFor(session, now);
    if (session == null) {
      state = state.copyWith(mode: Mode.browse, clearSession: true);
      return;
    }
    await _applyEffects(session, mode, now);
    state = state.copyWith(
      mode: mode,
      session: session,
      selectedPresetIndex: _indexFor(session, state.presets, state.selectedPresetIndex),
    );
  });

  // ─── Internals ───────────────────────────────────────────────────────────

  Future<void> _commit(Session session) async {
    final now = _now;
    final mode = SessionState.modeFor(session, now);
    await ref.read(sessionStoreProvider).saveSession(session);
    await _applyEffects(session, mode, now);
    state = state.copyWith(
      mode: mode,
      session: session,
      selectedPresetIndex: _indexFor(session, state.presets, state.selectedPresetIndex),
    );
  }

  /// Alarm and ongoing notification for [session] in [mode]. Time's up
  /// keeps the alarm notification the system is already showing.
  Future<void> _applyEffects(Session session, Mode mode, DateTime now) async {
    final alarm = ref.read(alarmSchedulerProvider);
    final ongoing = ref.read(ongoingNotifierProvider);
    switch (mode) {
      case Mode.timerRunning:
        await alarm.schedule(session as TimerSession, math.fireAt(session)!);
        await ongoing.show(session, now);
      case Mode.timerPaused:
        await alarm.cancel();
        await ongoing.show(session, now);
      case Mode.stopwatchRunning || Mode.stopwatchPaused:
        await ongoing.show(session, now);
      case Mode.timerDone:
        await ongoing.clear();
      case Mode.browse:
        break;
    }
  }

  /// Back to Browse on the page that was running.
  Future<void> _clear() async {
    final session = state.session;
    await ref.read(sessionStoreProvider).clearSession();
    await ref.read(alarmSchedulerProvider).cancel();
    await ref.read(ongoingNotifierProvider).clear();
    await ref.read(soundServiceProvider).stopAlarm();
    state = state.copyWith(
      mode: Mode.browse,
      clearSession: true,
      selectedPresetIndex: _indexFor(session, state.presets, state.selectedPresetIndex),
    );
  }

  /// Pager page for [session]; [fallback] when there is none.
  static int _indexFor(Session? session, List<int> presets, int fallback) =>
      switch (session) {
        StopwatchSession() => presets.length,
        TimerSession(:final presetMinutes) => presetIndexOf(presets, presetMinutes),
        null => fallback,
      };

  Future<void> _run(Future<void> Function() intent) {
    final next = _queue.then((_) => intent()).catchError((Object e, StackTrace st) {
      debugPrint('SessionController intent failed: $e\n$st');
    });
    _queue = next;
    return next;
  }
}
