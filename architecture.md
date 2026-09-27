# Architecture: Pop Timer

A small, offline, single-module Flutter app. The guiding rule, carried over from Pop Calc: **keep the time engine pure Dart, keep animation in the UI layer, keep platform side effects (notifications, alarms, sound) behind interfaces.** The one new rule for a timer: **time is derived from timestamps, never from counting ticks.**

> Package names and versions below are starting points. Check pub.dev for current stable versions and read each changelog before pinning. Verify Android notification/alarm APIs against the current plugin docs, since they change often.

---

## 1. Tech stack

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter (current stable), Dart 3 | Same as Pop Calc, Impeller on Android |
| State management | `flutter_riverpod` | Same as Pop Calc, testable, provider overrides for fakes |
| Persistence | `shared_preferences` | Tiny data: active session, settings, recents, Pro cache |
| Notifications + exact alarm | `flutter_local_notifications` (+ `timezone`) | Ongoing chronometer notification, scheduled alarm notification, actions, boot rescheduling |
| Foreground alarm sound | `flutter_soloud` or `audioplayers` | Looped alarm while the app is open, low-latency ticks |
| Keep screen on | `wakelock_plus` | Optional setting while a session runs |
| Purchases | `in_app_purchase` (+ `in_app_purchase_android`) | Same Pro model as Pop Calc |
| Haptics | Flutter `HapticFeedback` + `Vibration` pattern via notification channel | No extra package for UI haptics |
| Tilt (Pro) | `sensors_plus` | Parallax on the numeral |
| Rendering | `CustomPainter`, `Ticker`, `SpringSimulation` | Numerals, speed lines, inversions |
| Fonts | Bundled Antonio (SIL OFL), optionally Big Shoulders Display | Offline |
| Lints | `flutter_lints` or `very_good_analysis` | |
| Tests | `flutter_test`, `mocktail`, `fake_async`, golden tests | Engine correctness with a fake clock, visual regression |

Keep the dependency list short. Every plugin can add permissions and change Data Safety answers; check the merged manifest after adding each one.

## 2. High-level structure

```
lib/
  main.dart                          init: prefs, timezone, notifications, restore session, runApp
  app/
    app.dart                         MaterialApp, theme wiring
  core/
    engine/                          PURE DART, no Flutter imports
      clock.dart                     Clock interface + SystemClock + FakeClock
      session.dart                   Session sealed class: TimerSession, StopwatchSession
      session_math.dart              remaining(), elapsed(), bigNumeral(), countdownText()
      presets.dart                   Default list, insert custom, recents
      formatter.dart                 mm:ss, h:mm:ss, +HH:MM:SS
    platform/
      alarm_scheduler.dart           Interface: schedule/cancel the "time's up" alarm
      ongoing_notifier.dart          Interface: show/update/clear the ongoing notification
      local_notifications_impl.dart  flutter_local_notifications implementation of both
      notification_actions.dart      Top-level background action handler (Pause, Cancel, +1 min)
      sound_service.dart             Foreground alarm loop, ticks
      haptics_service.dart
      wakelock_service.dart
    storage/
      session_store.dart             Persist/restore the active session (JSON in prefs)
      settings_store.dart
    theme/
      skin.dart                      Skin = Night surface + Paper surface tokens
      skins.dart                     Graphite + Pro skins
      typography.dart
    render/                          Shared with Pop Calc (copy, then adapt)
      glyph_renderer.dart            Interface: paint(canvas, glyph, material, depth)
      procedural_glyph_renderer.dart Extrusion + chamfer + cast shadow
      glyph_paths.dart               Paths for 0-9 (from font) and hand-built '+'
      grain_overlay.dart
  features/
    timer/
      application/
        session_controller.dart      Notifier: start/pause/resume/cancel/reset/dismiss
        session_state.dart           UI-facing state (mode, surface, numeral, line, flags)
        tick_provider.dart           Frame-synced "now" while a session is visible
      presentation/
        timer_screen.dart            Pager + overlays
        widgets/
          preset_pager.dart          Vertical snapping PageView
          sculpted_numeral.dart      Widget around GlyphRenderer, animated depth/material
          speed_lines.dart           CustomPainter + particle pool
          countdown_line.dart
          hold_ring.dart             Hold-to-confirm gesture + ring painter
          surface_reveal.dart        Radial Night <-> Paper transition
          tap_hint.dart              TAP TO START + ring
          custom_duration_picker.dart
    stopwatch/
      presentation/widgets/lap_sheet.dart  (P2)
    settings/
      presentation/settings_sheet.dart
    pro/                             Same shape as Pop Calc
      domain/entitlement.dart
      data/purchase_service.dart
      application/pro_controller.dart
      presentation/pro_sheet.dart
assets/
  fonts/
  sounds/alarm_bell.ogg, alarm_pulse.ogg, ...
  textures/noise.png
  licenses/
android/app/src/main/res/raw/       Alarm sounds for notification channels (must live here)
test/
  engine/                            Session math with FakeClock
  controller/                        Controller + fake platform services
  golden/                            Numerals, states, skins
integration_test/
```

Reuse from Pop Calc: `ExtrudedNumberPainter` (becomes `ProceduralGlyphRenderer`), grain overlay, noise texture, font, `PurchaseService`/Pro feature, haptics service, lints and CI workflow.

## 3. Time engine

### 3.1 The core rule

A session stores **when** things happened, never **how much** is left. Every value on screen is computed from `now`:

```dart
sealed class Session {
  final DateTime startedAt;          // UTC wall clock
  final Duration pausedTotal;        // sum of completed pauses
  final DateTime? pausedAt;          // non-null while paused
}

final class TimerSession extends Session {
  final Duration duration;
  final int presetMinutes;           // what the user picked, for "restart" and the pager
}

final class StopwatchSession extends Session {
  final List<Duration> laps;         // P2
}
```

```dart
Duration elapsed(Session s, DateTime now) {
  final end = s.pausedAt ?? now;
  return end.difference(s.startedAt) - s.pausedTotal;
}

Duration remaining(TimerSession s, DateTime now) =>
    s.duration - elapsed(s, now);        // negative = overtime

DateTime? fireAt(TimerSession s) =>
    s.pausedAt == null ? s.startedAt.add(s.duration + s.pausedTotal) : null;
```

Pause sets `pausedAt`. Resume adds `now - pausedAt` to `pausedTotal` and clears `pausedAt`. That's all the state there is, so process death, backgrounding and reboots are handled by persisting this object and recomputing.

### 3.2 Clock

```dart
abstract interface class Clock { DateTime now(); }
class SystemClock implements Clock { DateTime now() => DateTime.now().toUtc(); }
class FakeClock implements Clock { DateTime current; void advance(Duration d) => current = current.add(d); ... }
```

- Everything (engine, controller, tests) takes a `Clock`. Tests never sleep.
- Known edge case: if the user changes the system time while a timer runs, a wall-clock session shifts. Acceptable for v1 (same trade-off as the scheduled alarm, which also uses wall-clock `RTC_WAKEUP`). If it matters later, add a small platform channel for `SystemClock.elapsedRealtime()` and store both anchors.

### 3.3 Display rules (pure functions)

```dart
/// Big numeral text for the current state (see PRD 5.4).
String bigNumeral(Session s, DateTime now) {
  switch (s) {
    case TimerSession():
      final secs = displaySeconds(remaining(s, now));           // ceil to whole seconds
      if (secs <= 0) return '0';                                // done / overtime
      if (secs >= 60) return '${(secs / 60).ceil()}';          // 600 -> 10, 599 -> 10, 540 -> 9
      return '$secs';                                           // 59 ... 1
    case StopwatchSession():
      final e = elapsed(s, now);
      return e < const Duration(minutes: 1) ? '+' : '${e.inMinutes}';
  }
}

/// Remaining time rounded UP to whole seconds. The countdown line uses the
/// same value, so the big numeral and the small line can never disagree.
int displaySeconds(Duration r) => r <= Duration.zero ? 0 : (r.inMilliseconds / 1000).ceil();
```

- One rounding rule for both lines: `displaySeconds` rounds up. At 59.5 s left the line shows `1:00` and the numeral `1`; at 59.0 s the line shows `0:59` and the numeral `59`. Rounding up means the numeral never shows `0` while time remains.
- Countdown line: `m:ss` under an hour, `h:mm:ss` above. Stopwatch and overtime: `+HH:MM:SS`.
- `nextBoundary(Session, now)`: the instant the big numeral will next change. The UI uses it to trigger the tick/rise animation exactly once per change.

### 3.4 Test plan for the engine

Target 100 percent branch coverage on `core/engine`, all with `FakeClock`.

| Category | Examples |
|---|---|
| Basics | 10 min timer at t=0 shows `10` / `10:00`; at t=1 s shows `10` / `9:59`; at t=60 s shows `9` / `9:00` |
| Under a minute | remaining 60.0 s → `1` / `1:00`; 59.5 s → `1` / `1:00`; 59.0 s → `59` / `0:59`. The numeral never shows `60` |
| Last seconds | remaining 0.4 s → `1`; remaining 0 → `0` and state is done |
| Pause | pause at 3:00 left, advance 10 min, still 3:00 left; resume, advance 1 min, 2:00 left |
| Multiple pauses | pausedTotal accumulates correctly across 3 pause/resume cycles |
| fireAt | shifts later by exactly each pause length; null while paused |
| Overtime | remaining −12 s → overtime line `+00:00:12` |
| Stopwatch | 0–59 s → `+`; 60 s → `1`; 3:16 → `3` / `+00:03:16`; 100 min → `100` |
| Serialization | round-trip JSON for every session variant, including paused |
| Restore | session persisted, clock advanced 2 h, restore computes done + overtime correctly |
| Formatting | `1:30:00` above an hour, stopwatch hours roll over, no negative zero |

Sequence for the last stretch of any timer: `2` → `1` → `59` → `58` → … → `1` → `0`.

## 4. State management

```dart
enum Surface { night, paper }
enum Mode { browse, timerRunning, timerPaused, timerDone, stopwatchRunning, stopwatchPaused }

class SessionState {
  final Mode mode;
  final Surface surface;           // night for browse/timer, paper for stopwatch/done
  final Session? session;
  final int selectedPresetIndex;   // pager position
  final List<int> presets;         // minutes, + page is implicit at the end
  final bool notificationsGranted;
}
```

- `SessionController` (Riverpod `Notifier`) owns `SessionState` and all side effects through injected interfaces: `Clock`, `SessionStore`, `AlarmScheduler`, `OngoingNotifier`, `SoundService`, `HapticsService`, `WakelockService`.
- Intent methods: `selectPreset(i)`, `startTimer()`, `startStopwatch()`, `togglePause()`, `cancel()`, `reset()`, `dismissAlarm()`, `restartTimer()`, `addMinute()`, `onAppResumed()`.
- Each intent: compute new session → persist → reschedule/cancel alarm → update ongoing notification → emit state. Order matters: **persist before scheduling**, so a crash mid-way never leaves an alarm with no session.
- The controller does **not** tick. The UI owns a `Ticker` (`tick_provider.dart`) that only runs while a session is visible and the app is resumed; each frame reads `clock.now()` and derives display values. When `now` passes `fireAt` while in the foreground, the UI calls `controller.onTimerReachedZero()` (idempotent).
- Animation state (depth, material lerp, speed-line intensity, reveal radius) lives in widget-level controllers that react to state changes and numeral changes, exactly like Pop Calc's `NumeralAnimator`.

## 5. Background reliability (Android)

This is the part that makes or breaks a timer app. Nothing here runs Dart code periodically in the background.

### 5.1 Timer start

1. Persist session.
2. `AlarmScheduler.schedule(id: 1, at: fireAt)` → `zonedSchedule` with `AndroidScheduleMode.exactAllowWhileIdle` on the **alarm channel**.
3. `OngoingNotifier.showTimer(...)` → ongoing notification with `usesChronometer: true`, `chronometerCountDown: true`, `when: fireAt`. The system draws the live countdown; the app does not update it.

### 5.2 Notification channels

| Channel | Importance | Sound | Notes |
|---|---|---|---|
| `ongoing` | Low | None | Countdown/stopwatch chronometer, `onlyAlertOnce`, `ongoing`, `autoCancel: false` |
| `alarm` | Max | `res/raw/alarm_bell` with alarm audio usage | `insistent` flag so the sound loops, vibration pattern, `category: alarm`, `timeoutAfter` ~2 min |

Channel sound can't change after creation on Android. Create one alarm channel per alarm sound (`alarm_bell`, `alarm_pulse`, …) and pick the channel when scheduling.

### 5.3 Pause / resume / cancel

- Pause: persist, **cancel** the scheduled alarm, replace ongoing notification with a static "Paused · 7:42 left" (no chronometer).
- Resume: persist, schedule a new alarm at the new `fireAt`, show chronometer notification again.
- Cancel/reset: clear session, cancel alarm, clear ongoing notification.

### 5.4 Notification actions while the app is dead

`flutter_local_notifications` runs action taps in a background isolate via a top-level `@pragma('vm:entry-point')` handler (`notification_actions.dart`). The handler:

1. Initializes `shared_preferences` and the notifications plugin in that isolate.
2. Loads the session, applies the same pure engine functions (pause/resume/cancel/+1 min), persists.
3. Reschedules or cancels the alarm and updates the notification.

Because the logic is pure Dart in `core/engine`, the handler reuses it with no Flutter UI. When the app next opens, it just restores from the store.

### 5.5 App launch / resume

`main()` and `onAppResumed()`:

1. Load session. If none, Browse.
2. If a timer's `fireAt` is in the past: mode = done, show overtime, keep the alarm notification as the system shows it.
3. Otherwise re-assert the scheduled alarm (cheap, idempotent) and the ongoing notification, in case either was lost (OEM kill, user swiped the notification away on Android 14+).

### 5.6 Reboot

Add `RECEIVE_BOOT_COMPLETED` and the plugin's boot receiver so scheduled notifications survive reboot. The ongoing chronometer notification is re-posted the next time the app opens (acceptable for v1).

### 5.7 Permissions flow

| Step | Behavior |
|---|---|
| First tap to start | Request `POST_NOTIFICATIONS` (Android 13+). Timer starts regardless |
| Denied | Small inline line under the countdown: "Allow notifications so the alarm can ring in the background" with a button to settings. Foreground alarm still works via `SoundService` |
| Exact alarms | Declare `USE_EXACT_ALARM` (core timer function). If policy review rejects it, fall back to `SCHEDULE_EXACT_ALARM` with a check via `canScheduleExactNotifications()` and a settings deep link, then to inexact scheduling with a warning |

### 5.8 Foreground alarm

If the app is visible when the timer hits zero, the scheduled notification still fires (that's fine and keeps logic single-path), but the in-app screen also plays the looped alarm via `SoundService` and cancels the notification sound on dismiss. Dismissing in-app calls `cancel(id)` on the alarm notification.

## 6. Rendering and animation

### 6.1 Glyph renderer

```dart
abstract interface class GlyphRenderer {
  void paint(Canvas canvas, Size size, {
    required String text,        // '10', '59', '+'
    required GlyphMaterial material, // lerp between idle and lit, on night or paper
    required double depth,       // 0..1
    required Offset lightDir,    // + tilt offset (Pro)
    required bool lite,
  });
}
```

- `ProceduralGlyphRenderer`: Flutter can't hand you a font glyph's outline as a `Path`, so the chamfer pass needs its own outlines. Hand-author `Path`s for `0–9` and `+` in `glyph_paths.dart` (11 glyphs, drawn to match the condensed face). This is the most predictable option and makes per-facet lighting easy. Extrusion layers and the cast shadow can still use the same paths, so there's one source of truth for shape.
- Cache per (text, size, material bucket, depth bucket) as `ui.Picture`/`ui.Image`. While the numeral is static (most of a running timer), the painter only blits a cached image.
- Wrap in `RepaintBoundary`. Speed lines paint in a separate layer behind it.

### 6.2 Pager

- `PageView.builder` vertical, `PageController(viewportFraction: ~0.86)` so neighbors peek, custom `ScrollPhysics` with the `pageSnap` spring.
- Each page renders a cached idle glyph image (cheap to scroll). Only the centered page is "live".
- Pager is disabled (`NeverScrollableScrollPhysics`) while a session exists.

### 6.3 Speed lines

- One `CustomPainter` + one `Ticker`. Fixed pool of 32 line structs (angle, radius, length, speed, alpha, age). No allocations per frame.
- `intensity` (0..1) is an animated value; `burst()` sets it to 1 then eases to 0.4.
- Stops ticking entirely when paused, off-screen, or Reduce Motion is on.

### 6.4 Surface reveal

Night ↔ Paper transition: paint the new surface in a circular clip whose radius animates from 0 to the screen diagonal, centered on the tap point. The numeral inside the clip uses the new material. One `AnimationController`, one clip; no route change.

### 6.5 Performance budget

| Item | Budget |
|---|---|
| Frame time | Under 16 ms, no jank while paging or with speed lines |
| Extrusion layers | 12 default, 4 Lite |
| Blur | One cast-shadow blur per visible glyph, baked into the cached image |
| Per-frame work while running | Blit cached numeral + speed lines + one text line |
| Startup | Under 1 s to interactive, session restored before first frame |
| AAB size | Under 15 MB (fonts + a few short OGG alarm sounds) |

Profile in profile mode on a real low-end device.

## 7. Persistence

| Data | Store | Notes |
|---|---|---|
| Active session | `shared_preferences` JSON | Written on every intent, read at launch and by the background action isolate |
| Settings (haptics, minute tick haptic, alarm sound, keep screen on, Lite) | `shared_preferences` | Loaded before `runApp` |
| Last preset, recent custom durations | `shared_preferences` | |
| Custom preset list (Pro) | `shared_preferences` | |
| Pro entitlement cache | `shared_preferences` | Play Billing is the source of truth |
| Laps (P2) | Inside the stopwatch session JSON | Cleared on reset |

No network, no accounts. Exclude nothing sensitive, so Android Auto Backup can stay default, or disable it to keep the Data Safety story trivial (decide deliberately, same as Pop Calc).

## 8. Monetization

Identical to Pop Calc: `PurchaseService` interface with Play and Fake implementations, `pro_unlock` non-consumable, `proProvider` gates cosmetics at the UI layer only. Copy the Pop Calc feature folder and rename strings. Never gate timing, background reliability, custom durations, or the stopwatch.

## 9. Platform configuration (Android)

| Item | Setting |
|---|---|
| `minSdk` | 24 or 26 (check plugin minimums) |
| `targetSdk` | 36 (Android 16) |
| Orientation | Portrait, locked in `AndroidManifest.xml` |
| Permissions | `POST_NOTIFICATIONS`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `WAKE_LOCK`. Confirm the merged manifest has **no** `INTERNET` (billing plugin may add its own; verify and document) |
| Receivers | Plugin's scheduled-notification receiver, boot receiver, action receiver |
| Core library desugaring | Required by `flutter_local_notifications`; enable in `build.gradle` |
| Sounds | Alarm sounds in `android/app/src/main/res/raw/`, keep them from being shrunk (`res/raw/keep.xml`) |
| Signing | Play App Signing, upload keystore backed up in two places, never in git |
| Build | `flutter build appbundle --release`, R8 + resource shrinking on, test the release build |
| Edge-to-edge | Default on recent Android; handle insets |
| Play Console | Permissions declaration for `USE_EXACT_ALARM`; Data Safety: no data collected |

## 10. Testing strategy

| Layer | Tool | What |
|---|---|---|
| Engine | `flutter_test` (pure Dart) + `FakeClock` | Every row of 3.4 |
| Controller | Riverpod overrides with fake `AlarmScheduler`, `OngoingNotifier`, `SessionStore` | Intents produce the right state **and** the right side-effect calls (schedule at exact `fireAt`, cancel on pause, etc.) |
| Background handler | Pure Dart test of the action handler with an in-memory store | Pause/cancel/+1 min from a "dead" app |
| Widgets | `flutter_test` | Pager snapping, tap/hold gestures, hold released early does nothing |
| Golden | goldens | Idle, lit, paused, done, stopwatch `+`, stopwatch `3`, each skin, Lite |
| Integration | `integration_test` on device | Start 1 min timer → background → screen off → alarm rings on time |
| Manual matrix | Real devices | Pixel (stock), Samsung, one aggressive OEM (Xiaomi/Oppo/Realme), low-end phone; Doze (`adb shell dumpsys deviceidle force-idle`), reboot mid-timer, notifications denied, TalkBack, Reduce Motion |

CI: GitHub Actions running `flutter analyze` and `flutter test` on every push, release AAB on tags (reuse Pop Calc's workflow).

## 11. Privacy and data

| Question | Answer in v1 |
|---|---|
| Sends data anywhere? | No |
| Accounts? | No |
| Ads, analytics, crash SDKs? | None |
| Third-party SDKs | Play Billing via official plugin |
| Data Safety form | No data collected, no data shared |
| Privacy policy | Static page: all data stays on-device |

## 12. Decisions log

| Decision | Choice | Alternative | Reason |
|---|---|---|---|
| Time source | Stored timestamps + `now()` | Counting `Timer.periodic` ticks | Survives backgrounding, process death, reboots; testable |
| Background countdown | System chronometer notification | Foreground service updating every second | No wake-ups, no FGS type restrictions on Android 14+, better battery |
| Alarm | Exact scheduled notification (`exactAllowWhileIdle`) | `android_alarm_manager_plus` + Dart callback | No Dart code at fire time, fewer moving parts |
| Full-screen alarm | Not in v1 | `USE_FULL_SCREEN_INTENT` | Restricted permission, extra review risk; heads-up + insistent sound is enough |
| Numeral rendering | Procedural painter (from Pop Calc) behind `GlyphRenderer` | Blender-rendered sprites | Reuse, skins are just colors; sprites stay possible later |
| Concurrent sessions | One at a time | Multiple timers | Keeps UI and notifications simple for v1 |
| State | Riverpod | Bloc | Same as Pop Calc |
| Storage | `shared_preferences` | drift/Hive | Data is a few small JSON blobs |
| Monetization | Free + one-time Pro | Paid, ads | Same proven model as Pop Calc |
| UI label font | Bebas Neue for headings, labels and hints; Antonio for descriptions and the countdown line (as in Pop Calc) | Antonio everywhere (`design.md` 3) | Pop Timer must read as Pop Calc's sibling; Pop Calc's shipped UI uses Bebas Neue for all labels |
| Application id | `com.ornobaadi.poptimer` | `com.example.poptimer` | Matches `com.ornobaadi.popcalc` |
| Numeral face | Hand-built chiseled polygons for `0`–`9` and `+` on a 28 × 100 grid (`glyph_paths.dart`); every render pass (shadow sweep, side-wall quads, face, per-facet chamfer) uses them | Antonio Bold glyphs (`design.md` 3) | Font outlines can't be read as paths, and per-facet lighting needs polygons; the faceted face matches the chiseled references. Antonio stays for the countdown line |
| Two-digit numerals | Shrink to fit 84% of the width, so on a 20:9 phone they're ~88% of single-digit height | Same height as single digits (`design.md` 4) | At full height two digits run off a 360 dp screen; revisit with a narrower grid if it looks off on device |
| Haptics | Pop Calc's native `poptimer/haptics` channel in `MainActivity` (composed primitives, waveform fallback), behind `HapticsService` | Flutter `HapticFeedback` only (section 1) | Same crisp feel as Pop Calc; needs only `VIBRATE`, already declared; falls back to `HapticFeedback` |
| Intent ordering | `SessionController` runs intents through a serial queue, deciding what to do inside the queue | Fire-and-forget async intents | A tap landing while a swipe's page change is still persisting must see the new page |
| Hold timing | Ring starts on the raw pointer-down; a release before 250 ms of fill is a tap | Start on `onTapDown` | `onTapDown` arrives after the 100 ms press timeout, which made a 600 ms hold take 700 |
| +1 min after time's up | Rings again one minute from the tap (`duration = elapsed + 1 min`) | Add a minute to the original duration (would still be in overtime) | The done notification's "+1 min" must mean "one more minute from now" |
