# Phases: Pop Timer

Same shape as Pop Calc's plan, built around the same fact: **a new app needs a closed test with at least 12 opted-in testers for 14 continuous days before production.** Get a feature-complete, reliable free build into closed testing early, then build Pro while the clock runs.

The one difference from Pop Calc: a timer that fires late is a broken timer, so background reliability gets its own phase and is finished **before** the closed test starts.

```
Week 1     Week 2     Week 3     Week 4     Week 5     Week 6     Week 7     Week 8
[P0][--P1--][---P2---][--P3--][---P4---][P5]
                                           [ closed test ~ end of week 5 ....14 days.... ]
                                                 [------ P6 Pro / IAP ------]
                                                                     [-P7 listing-][P8 launch]
```

---

## Phase 0: Setup

**Goal:** a clean project with the same identity and foundations as Pop Calc.

- [x] App name: Pop Timer (sibling of Pop Calc).
- [x] Application id `com.ornobaadi.poptimer` (matches `com.ornobaadi.popcalc`).
- [x] Folder structure from `architecture.md` section 2 (`lib/core/...`, `lib/features/...`, `assets/...`, `test/engine`).
- [x] Dependencies for the engine and state: `flutter_riverpod`, `shared_preferences` (the rest are added in the phase that needs them).
- [x] Bundle the Pop Calc fonts (Antonio variable, Bebas Neue) and the OFL license.
- [x] Reuse Pop Calc's noise texture (`assets/textures/noise.png`).
- [x] Android manifest: portrait lock, `VIBRATE`, app label "Pop Timer".
- [ ] Draft one-page privacy policy (reuse Pop Calc's `docs/privacy-policy.html`, before closed test).
- [ ] Upload keystore for Play publishing (before closed test).
- [ ] Start recruiting testers (reuse Pop Calc's tester group, aim for 15 to 20).

**Exit criteria:** project builds, assets bundled, folders scaffolded. Status: **DONE** (privacy policy, keystore and testers carry over).


---

## Phase 1: Time engine

**Goal:** correct time, with no UI.

- [x] `Clock`, `SystemClock`, `FakeClock` (`core/engine/clock.dart`).
- [x] `Session`, `TimerSession`, `StopwatchSession` with pause/resume/+1 min and JSON round-trip (`session.dart`).
- [x] `elapsed`, `remaining`, `fireAt`, `displaySeconds`, `bigNumeral`, `nextBoundary` (`session_math.dart`).
- [x] Countdown `m:ss` / `h:mm:ss`, stopwatch and overtime `+HH:MM:SS` (`formatter.dart`).
- [x] Default presets, insert custom value, recents capped at 3 (`presets.dart`).
- [x] Unit tests for every row of `architecture.md` section 3.4, all on `FakeClock`.

**Exit criteria:** all engine tests pass. No Flutter imports in `core/engine`. Status: **DONE** (29/29 engine tests passing).

---

## Phase 2: Static UI

**Goal:** it looks right standing still, and reads as a Pop Calc sibling.

- [x] Skin tokens: Graphite Night + Paper surfaces (`core/theme/skin.dart`, `skins.dart`), `ThemeData` wiring.
- [x] `GlyphRenderer` interface + `ProceduralGlyphRenderer` built from Pop Calc's `ExtrudedNumberPainter`, adding the top-right light model, long cast shadow and chamfer pass.
- [x] Hand-built `+` path with chiseled arm ends.
- [x] Vertical snapping preset pager with peeking neighbors.
- [x] Browse screen: numeral, TAP TO START hint + ring, settings ring (top-right).
- [x] Countdown line, Paper surface screens (stopwatch `+`, stopwatch `3`, timer done `0`).
- [x] Grain overlay (from Pop Calc).
- [x] Golden tests for idle, lit, paused, done, stopwatch `+` and `3`.

**Exit criteria:** side by side with the references, every static state looks right. Status: **DONE in code** (48/48 tests, 9 goldens in `test/golden/goldens/`); still needs a look on a real device.

---

## Phase 3: Controller and motion

**Goal:** it works in the foreground and feels great.

- [ ] `SessionController` with every intent from `architecture.md` section 4, persisting through `SessionStore`, with fake platform services in tests.
- [ ] Frame-synced tick provider (UI owns the `Ticker`).
- [ ] Light-up, speed lines (pooled, one `Ticker`), minute sink/rise, last-10 s punch.
- [ ] Night ↔ Paper radial reveal.
- [ ] Hold ring (cancel, reset, restart, custom picker).
- [ ] Haptics service (from Pop Calc's `AppHaptics`) on every event in `design.md` section 8.
- [ ] Reduce Motion and Lite effects.

**Exit criteria:** 60 fps on a mid-range device, every gesture in PRD 5.2 works in the foreground.

---

## Phase 4: Background reliability

**Goal:** it never misses an alarm.

- [ ] `flutter_local_notifications` + `timezone`, desugaring enabled (check current plugin docs first).
- [ ] `AlarmScheduler` and `OngoingNotifier` interfaces + implementation; `ongoing` and per-sound `alarm` channels.
- [ ] Chronometer ongoing notification with Pause/Resume/Cancel actions; background action handler reusing the engine.
- [ ] Exact alarm at `fireAt`, restore on launch/resume, reboot rescheduling.
- [ ] Permissions flow: `POST_NOTIFICATIONS` on first start, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`. Merged manifest has no `INTERNET`.
- [ ] Foreground alarm sound (`SoundService`), 2 free alarm sounds in `res/raw`.
- [ ] Manual matrix: Doze, process kill, reboot, notifications denied, one aggressive OEM.

**Exit criteria:** a 1-minute timer rings on time with the app killed and the screen off.

---

## Phase 5: Free feature completion and closed-test build

- [ ] Custom duration picker with recents.
- [ ] Settings sheet (Pop Calc layout): haptics, minute tick haptic, alarm sound, keep screen on, Lite effects.
- [ ] Accessibility pass: Semantics, custom actions for holds, announcements.
- [ ] App icon (adaptive + monochrome), splash, notification small icon, all in the Pop Calc family.
- [ ] Release build with R8, upload to the closed testing track.

---

## Phase 6: Pro and in-app purchase (during the 14-day test)

- [ ] Copy Pop Calc's Pro feature folder, `pro_unlock` product.
- [ ] Pro skins, preset editing, extra alarm sounds, alternate fonts, tilt.
- [ ] Buy, cancel, pending, refund, restore tested on a Play track. Nothing about timing is locked.

## Phase 7: Store listing

- [ ] Screenshots and promo video from the real app (`design.md` section 10), feature graphic, descriptions.
- [ ] Data Safety (no data collected), `USE_EXACT_ALARM` declaration.

## Phase 8: Production access and launch

- [ ] Tester requirement met, production access applied for, release submitted.

---

## Definition of done for v1.0

- [ ] All MVP features in the PRD work
- [ ] Engine tests pass, including every row of `architecture.md` section 3.4
- [ ] Alarm rings on time backgrounded, screen off, killed, and after reboot
- [ ] 60 fps on a mid-range device, smooth in Lite mode on a low-end device
- [ ] TalkBack, large font, and Reduce Motion verified
- [ ] Pro purchase and restore verified on a real Play track
- [ ] Data Safety and privacy policy match the shipped app
