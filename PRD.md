# PRD: Pop Timer

> **Time, but make it physical.** A timer and stopwatch built from giant sculpted numerals. Swipe to pick a time, tap to start, watch it burst to life.

Working title: **Pop Timer** (sibling to Pop Calc). Alternatives if the name is taken on Play: *Pop Clock*, *Monolith Timer*, *Tick Pop*.

Built with Flutter · Android-first · 100% offline · Zero data collected

---

## 1. Summary

Pop Timer is a single-screen timer and stopwatch. Instead of dials and keypads, the whole screen is one huge extruded numeral carved out of a dark graphite surface. Swiping vertically scrolls through preset minute values (1, 3, 5, 10, 15 …). Tapping a numeral starts that timer: the numeral lights up white, radial speed lines burst behind it, and a small `mm:ss` countdown appears below. At the bottom of the list sits a sculpted **+**. Tapping it starts a stopwatch: the whole world inverts to white paper, the + turns black, and an elapsed counter (`+00:00:16`) ticks up. After the first minute, the + is replaced by the elapsed-minute numeral (`3`, `+00:03:16`).

Like Pop Calc, the product is the feel: tactile numerals, snappy motion, precise haptics. The utility is deliberately simple and must be rock-solid (a timer that fires late is a broken timer).

## 2. Goals

| Goal | Measure |
|---|---|
| Delight on first open | Store listing screenshots and a 10 s clip sell the look without explanation |
| Start a timer in one gesture | Median time from launch to running timer under 2 seconds |
| Never miss an alarm | Timer fires within 1 s of target with the app backgrounded, screen off, or killed |
| Pass Play closed testing smoothly | 12+ opted-in testers for 14 continuous days, then production access |
| Keep compliance light | No accounts, no ads, no network, no analytics in v1 |

## 3. Non-goals (v1)

- Multiple simultaneous timers (one active session at a time: either a timer or a stopwatch)
- Alarm clock (time-of-day alarms), world clock, Pomodoro cycles, interval/HIIT programs
- Wear OS, widgets, iOS release (planned later, same codebase)
- Cloud sync, accounts, analytics
- Health or fitness positioning (avoid Health category and workout claims)

## 4. Target users

- People who already like "design-forward" utility apps (Not Boring-style fans, Pop Calc users)
- Everyday timer users: cooking, tea, naps, focus sessions, board games, laundry
- Anyone who wants a stopwatch that is fun to look at

## 5. Core experience

### 5.1 Screen states

| State | Look | Entered by |
|---|---|---|
| **Browse** (idle) | Dark graphite, dark-on-dark sculpted numeral centered, neighbors peeking top and bottom, "TAP TO START" + ring hint | App launch, cancel, reset |
| **Timer running** | Numeral turns lit white, animated radial speed lines, `mm:ss` countdown below | Tap numeral in Browse |
| **Timer paused** | Numeral returns to dark-on-dark but stays on screen, speed lines frozen and dimmed, countdown blinks slowly | Tap while running |
| **Timer done** | Inverts to white paper, numeral `0` or a sculpted check, overtime counter `+00:00:12` counts up, alarm + haptics | Countdown reaches zero |
| **Stopwatch** | White paper, black sculpted + (under 1 min) then black elapsed-minute numeral, `+HH:MM:SS` below | Tap the + page |
| **Stopwatch paused** | Same, counter blinks slowly | Tap while running |

### 5.2 Gestures

| Gesture | Browse | Timer running / paused | Timer done | Stopwatch |
|---|---|---|---|---|
| Vertical swipe | Page to previous/next preset (snaps) | Disabled (prevents accidental changes) | Disabled | Disabled |
| Tap | Start timer (or stopwatch on + page) | Pause / resume | Dismiss alarm, return to Browse | Pause / resume |
| Long press (hold ring fills, ~600 ms) | Open custom duration picker | Cancel timer, return to Browse | Restart same timer | Reset, return to Browse |
| System back | Exit app | Confirm-free: goes to Browse only if paused; while running, backgrounds app (timer keeps going) | Dismiss | Same as timer |

Every destructive action (cancel, reset) is a **hold**, never a tap, so it cannot happen by accident.

### 5.3 Presets

Default vertical list (top to bottom): `1, 2, 3, 5, 10, 15, 20, 25, 30, 45, 60, 90`, then the **+** stopwatch page at the very bottom.

- App opens on the last-used preset (first launch: `5`).
- Numbers above 60 display as minutes (`90`), not hours, to keep the numeral language consistent. The countdown line shows `1:30:00` format.
- Custom duration: long press in Browse opens a vertical drag picker (1 to 180 minutes, optional seconds wheel). A custom value is inserted into the list in sorted order for the session and remembered as "recent" (max 3 recents).

### 5.4 What the big numeral shows

| Remaining / elapsed | Big numeral | Small line |
|---|---|---|
| Timer, ≥ 1 min left | Minutes remaining, rounded **up** (`10:00` → `10`, `9:59` → `10`, `9:00` → `9`) | `9:59` |
| Timer, < 1 min left | Seconds remaining (`59` … `1`), each change punches | `0:42` |
| Timer, last 10 s | Seconds with stronger punch + light haptic per second | `0:07` |
| Stopwatch, < 1 min | Sculpted `+` | `+00:00:16` |
| Stopwatch, ≥ 1 min | Elapsed minutes (`3`), up to `999` | `+00:03:16` |
| Overtime after done | `0` (or check glyph) | `+00:00:12` |

### 5.5 Background behavior (non-negotiable)

- Timer keeps running when the app is backgrounded, the screen is off, or the process is killed.
- An ongoing notification shows the live countdown (system chronometer, no app wake-ups needed) with Pause/Resume and Cancel actions.
- At zero, an exact alarm fires a high-priority notification with the alarm sound and vibration, even in Doze.
- Stopwatch shows an ongoing notification with a counting-up chronometer.
- Reopening the app restores the exact state from stored timestamps.
- Timer survives a device reboot (rescheduled on boot).

## 6. Feature list

### MVP (free)

| # | Feature | Priority |
|---|---|---|
| F1 | Vertical snapping preset pager with peeking neighbors | P0 |
| F2 | Dark-on-dark extruded numerals with long cast shadow | P0 |
| F3 | Tap to start timer: light-up transition + radial speed lines + countdown | P0 |
| F4 | Pause/resume (tap), cancel (hold) | P0 |
| F5 | Big-numeral rules from 5.4 (minute ceil, seconds under a minute) | P0 |
| F6 | Timer done state: inversion, alarm sound, vibration pattern, overtime counter | P0 |
| F7 | Stopwatch via + page: inverted theme, `+HH:MM:SS`, pause/resume, hold to reset | P0 |
| F8 | Background reliability: ongoing notification, exact alarm, restore after kill/reboot | P0 |
| F9 | Custom duration picker (long press) | P1 |
| F10 | Haptics on paging, start, minute tick, last 10 s, finish | P0 |
| F11 | Settings sheet: haptics, alarm sound (2 free sounds), keep screen on while running, Lite effects, Reduce Motion respect | P1 |
| F12 | Stopwatch laps (tap small lap button, list in bottom sheet) | P2, can slip to v1.1 |
| F13 | Accessibility: TalkBack labels, announcements, large font support | P0 |

### Pro (one-time purchase, cosmetic only, same model as Pop Calc)

- Extra skins (e.g. *Andy* marigold, *Opal*, *Chroma*, *Mint*, *Carbon*) applied to both the Browse and Stopwatch surfaces
- Edit the preset list (add, remove, reorder)
- Extra alarm sounds and a gentle "rising" alarm
- Alternative numeral fonts
- Tilt parallax on the numeral

**Rule:** timing itself is never locked. Custom durations, background reliability, and the stopwatch stay free.

## 7. Requirements

### Functional

- Timing accuracy: remaining time is always computed from stored wall-clock/monotonic timestamps, never by counting ticks.
- Displayed seconds never skip or repeat under normal load.
- One active session at a time. Starting a stopwatch while a timer runs asks via a small inline prompt ("Timer running. Hold to replace.") rather than a dialog.
- Alarm continues until dismissed or 2 minutes pass, then the notification stays silently.

### Non-functional

| Area | Target |
|---|---|
| Frame rate | 60 fps while paging and while speed lines animate on a mid-range device |
| Startup | Under 1 s to interactive |
| Battery | No periodic wake-ups while backgrounded (system chronometer + exact alarm only) |
| App size | Under 15 MB AAB |
| Offline | No `INTERNET` permission |
| Platform | Android minSdk 24–26, targetSdk 36 (Android 16), portrait only |
| Format | Signed Android App Bundle (`.aab`) |

## 8. Permissions and compliance

| Permission | Why | Notes |
|---|---|---|
| `POST_NOTIFICATIONS` | Ongoing countdown + alarm notification | Ask at first timer start, not at launch. If denied, show an inline hint; timer still works in foreground |
| `USE_EXACT_ALARM` | Fire the alarm on time in Doze | Intended for apps whose core function is a timer/alarm. Requires the Play Console permissions declaration; verify current policy before release |
| `RECEIVE_BOOT_COMPLETED` | Reschedule an active timer after reboot | |
| `VIBRATE` | Haptics and alarm vibration | |
| `WAKE_LOCK` | Only if "Keep screen on while running" is enabled (via wakelock plugin) | |

- Category: **Tools** (or Productivity). Avoid Health & Fitness, Kids, Finance, News.
- Data Safety: no data collected, no data shared.
- Privacy policy: short static page (reuse Pop Calc's template).
- No full-screen-intent alarm in v1 (restricted permission, extra review risk). Heads-up notification with alarm sound is enough.

## 9. Monetization

Free with a single one-time **Pop Timer Pro** unlock (`pro_unlock`), mirroring Pop Calc. No ads, no subscriptions. Consider a later bundle offer for Pop Calc Pro owners (cross-promo only, no shared account).

## 10. Success metrics (first 60 days)

- Crash-free users above 99.5 percent
- Alarm reliability: zero "timer didn't ring" reports that trace to app logic
- Store listing conversion at or above Pop Calc's
- Rating 4.5+
- Pro conversion 2 to 4 percent of active users

## 11. Risks

| Risk | Mitigation |
|---|---|
| OEM battery killers delay alarms (Xiaomi, Samsung, Oppo) | Exact alarm + high-priority channel; optional "battery optimization" help link in settings; test on at least one aggressive OEM |
| Exact-alarm permission policy changes | Keep alarm scheduling behind one interface; fallback to `SCHEDULE_EXACT_ALARM` request flow, then inexact alarm + foreground notice |
| Numeral style doesn't match the reference's sculpted bevels | Two render paths planned (procedural painter, pre-rendered glyph sprites), see architecture decision log |
| Accidental cancel | Hold-to-cancel with visible ring fill |
| Scope creep (multiple timers, Pomodoro) | Everything outside section 6 MVP goes to v1.1 list |

## 12. Release plan

1. Closed test track as early as possible (new app needs its own closed test period before production; reuse Pop Calc's tester Google Group and add new testers for margin).
2. Build Pro during the 14-day window.
3. Store listing, then production access application, then launch.

See `phases.md` for the detailed schedule.
