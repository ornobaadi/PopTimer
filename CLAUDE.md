# CLAUDE.md: Pop Timer

Flutter timer + stopwatch app with giant sculpted numerals. Sibling of Pop Calc. Android-first, offline, no accounts, no analytics.

## Source of truth

- `PRD.md`: what to build and the exact display rules (section 5.4)
- `design.md`: tokens, glyph technique, motion timings, haptics
- `architecture.md`: folders, time engine, background reliability, testing
- `phases.md`: current phase and checklist. Only work on the phase I name. Tick checkboxes as tasks finish.

If a request conflicts with these docs, point out the conflict before coding. Record architecture decisions in `architecture.md` section 12.

## Hard rules

- `lib/core/engine/` is pure Dart. No `package:flutter` imports there.
- Time comes from stored timestamps and `Clock.now()`. Never count `Timer.periodic` ticks to track remaining time.
- Everything that touches time takes a `Clock`. Tests use `FakeClock`; no real sleeps in tests.
- `SessionController` never animates and never ticks. Animation state lives in widgets.
- Platform side effects (notifications, alarms, sound, haptics, wakelock, storage) only through interfaces in `lib/core/platform/` and `lib/core/storage/`.
- Persist the session **before** scheduling or cancelling an alarm.
- Never gate timing, background reliability, custom durations or the stopwatch behind Pro.
- Don't add packages or Android permissions that aren't in `architecture.md` without asking. Never add `INTERNET`.
- Check current package docs before using `flutter_local_notifications` APIs; they change between versions.

## Commands

```
flutter pub get
flutter analyze
flutter test
flutter test test/engine
flutter run --profile          # performance checks, on a real device
flutter build appbundle --release
```

## Done means

`flutter analyze` clean, tests pass, new logic has tests, and the relevant `phases.md` checkboxes are ticked.
