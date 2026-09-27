# Design: Pop Timer

Design language: **monolithic, sculpted, cinematic.** One giant numeral carved from a graphite surface. At rest everything is dark-on-dark and quiet; when time starts moving the numeral lights up and the screen bursts. The stopwatch lives in the negative: white paper, black sculpture.

Reference material: the tilted phone mockup (lit `15` with speed lines), the dark `+` page, the Browse `10` with TAP TO START, the running `10` with `10:00`, and the white stopwatch screens (`+` with `+00:00:16`, `3` with `+00:03:16`), plus the hero video.

---

## 1. What the references show

| Observation | Design consequence |
|---|---|
| At rest, numerals are the **same color as the background**, visible only through lighting: chamfered faces, soft highlights, long shadow falling down-left | Render with a lighting model, not a fill color. Front face ≈ `bg`, readability comes from bevel highlights and cast shadow |
| Numeral ends are faceted like pyramids (the `1` has a chiseled top, the `+` arms are 4-sided bevels) | Chamfer/bevel highlight pass with per-facet light direction, or pre-rendered glyph sprites |
| Neighboring presets peek from the top and bottom edges | Vertical `PageView` with viewport fraction < 1 or oversized glyphs clipped by the screen |
| Running state: numeral front face flips to bright white, thin white radial lines burst from behind it | Two-state material (dark → lit) and a speed-line painter layered behind the numeral |
| Small condensed `10:00` under the numeral | Secondary line in the same condensed face, tabular figures |
| Stopwatch inverts: white paper background, black sculpted glyph, soft grey cast shadow, `+00:00:16` | Separate "Paper" surface tokens; the + glyph doubles as the stopwatch icon |
| After a minute the stopwatch shows the elapsed minute count as a big numeral (`3`) | Same numeral pipeline, inverted material |
| Scattered abstract 3D shapes on the table in the mockup | Optional: faint background shapes for store graphics only, not in-app (keeps focus on the numeral) |
| Visible grain on every surface | Reuse Pop Calc's tileable noise overlay |

## 2. Surfaces and themes

A theme in Pop Timer has two surfaces: **Night** (Browse and running timer) and **Paper** (stopwatch and timer done). Night and Paper invert each other.

### Graphite (default)

**Night surface**

| Token | Hex | Use |
|---|---|---|
| `bg` | `#1B1B1B` | Screen background |
| `bgShade` | `#141414` | Vignette toward edges |
| `glyphFace` | `#1E1E1E` | Idle numeral front face (almost `bg`) |
| `glyphBevelLight` | `#FFFFFF2E` | Lit chamfer facets (up-right facing) |
| `glyphBevelDark` | `#00000066` | Shaded chamfer facets (down-left facing) |
| `glyphSide` | `#101010` | Extrusion side wall |
| `castShadow` | `#000000A0` | Long shadow toward bottom-left |
| `litFace` | `#F2F2F2` | Running numeral front face |
| `litSide` | `#9A9A9A` | Running numeral side wall |
| `speedLine` | `#FFFFFF` | Radial burst lines |
| `ink` | `#EDEDED` | `TAP TO START`, countdown line |
| `inkSoft` | `#8A8A8A` | Hints, settings icon |

**Paper surface**

| Token | Hex | Use |
|---|---|---|
| `bg` | `#F4F4F2` | Screen background |
| `bgShade` | `#E6E6E3` | Vignette |
| `glyphFace` | `#1C1C1C` | Numeral front face |
| `glyphBevelLight` | `#FFFFFF33` | Lit chamfers |
| `glyphBevelDark` | `#00000080` | Shaded chamfers |
| `glyphSide` | `#0A0A0A` | Side wall |
| `castShadow` | `#00000033` | Soft grey long shadow |
| `ink` | `#111111` | `+00:03:16` line |
| `inkSoft` | `#6B6B6B` | Hints |

### Pro skins (ideas)

Each skin defines both surfaces.

| Skin | Night bg | Lit face | Paper bg | Vibe |
|---|---|---|---|---|
| **Andy** | `#E69A00` marigold | `#FFF4D6` | `#FFF4D6` | Sunny, matches Pop Calc Andy |
| **Opal** | `#0E1620` | `#BFE3FF` | `#EAF5FF` | Cold sky |
| **Chroma** | `#1A1027` | `#D9B8FF` | `#F3EAFF` | Violet neon |
| **Mint** | `#0D241C` | `#BFF5DA` | `#EAFBF2` | Fresh |
| **Carbon** | `#111111` | `#FF5A1F` | `#F2F2F2` | Mono with hot accent |

**Contrast rule:** the idle numeral is intentionally low-contrast, so everything that carries meaning must not rely on it. `TAP TO START`, the countdown line and all text reach WCAG AA (4.5:1) against `bg`. The numeral's value is always also exposed through Semantics.

## 3. Typography

| Role | Face | Notes |
|---|---|---|
| Big numeral and `+` | **Antonio** Bold (same bundled variable font as Pop Calc) or a heavier condensed face such as *Big Shoulders Display* Black | Ultra-condensed, tall. Numeral height about 70 percent of screen height |
| Countdown / elapsed line | Antonio 500, 22–26 sp, tabular figures | `10:00`, `+00:03:16` |
| Hint (`TAP TO START`) | Antonio 500, 20 sp, letter-spacing 0.5 | Uppercase |
| Settings sheet | Antonio 400–500 | |

- Bundle fonts, no runtime fetching (offline, no network permission).
- Keep OFL license text in `assets/licenses/`.
- The `+` glyph is **not** a font character; draw it as a custom path so its arms have the chiseled pyramid ends from the reference.

## 4. Layout

Portrait only. One screen, full bleed.

```
+--------------------------------+
|  ▄▄ (prev preset peeking)   (◉)|  settings button: 40dp ring, top-right
|                                |
|        ███    ██████           |
|         ██   ██    ██          |
|         ██   ██    ██          |  Big numeral: ~70% height,
|         ██   ██    ██          |  centered, cast shadow down-left
|         ██  TAP TO START       |  hint overlaps numeral center
|         ██   ██ (  ) ██        |  hold-ring 56dp
|         ██   ██    ██          |
|        ████   ██████           |
|              10:00             |  countdown line (running only)
|  ▀▀ (next preset peeking)      |
+--------------------------------+
```

- Page height = screen height. The glyph is taller than the safe area can fit with its neighbors, so neighbors peek ~8–12 percent from the edges (as in the `10` reference, where the `5` above and the `15` below are cut off).
- Settings ring sits top-right under the status bar, 48 dp touch target. Hidden while a session runs; reappears on pause.
- Countdown line sits 24 dp below the numeral baseline, above the gesture bar inset.
- Two-digit numerals: fit both digits into the width with the same height as single digits (condensed face makes this work). Three digits (stopwatch ≥ 100 min) shrink height to fit width.
- Respect system insets; the background and glyphs go edge to edge, text never goes under the status or navigation bars.

## 5. The sculpted numeral technique

Build on Pop Calc's `ExtrudedNumberPainter`, adding a light model so a numeral the same color as the background still reads as an object.

**Light setup:** a single key light from the top-right (about 45°), so shadows fall toward the bottom-left, matching every reference.

Render order per glyph:

1. **Long cast shadow**: draw the glyph path offset along (-0.35, +0.45) × depth, repeated as a smear of 8–12 steps (or one path extruded via `Path.combine`), then blur 10–20 dp. Night: `castShadow`. Paper: lighter grey.
2. **Side walls**: 8–14 stacked layers along the extrusion vector (toward bottom-left) in `glyphSide`, darkening toward the base.
3. **Front face**: `glyphFace` (idle) or `litFace` (running), with a subtle vertical gradient (top a touch lighter).
4. **Chamfer pass**: inset the glyph outline by the bevel width (4–6 dp). For each edge segment of the outer contour, compute its normal; facets whose normal faces the light get `glyphBevelLight`, the rest `glyphBevelDark`. This is what gives the pyramid/chiseled look on the `1` and `+`.
5. **Grain**: shared noise overlay at 4–6 percent on top of everything.

**Two implementation paths** (decide in Phase 2 after a spike; see architecture decision log):

| Path | How | Pros | Cons |
|---|---|---|---|
| A. Procedural | `CustomPainter` with glyph `Path`s (from `TextPainter` → `computeMetrics`, or hand-built paths for `0–9` and `+`) and the chamfer pass above | Any font size, animatable depth and material, skins are just colors, small APK | Faceted bevels take real effort to look as good as the reference |
| B. Pre-rendered sprites | Model `0–9` and `+` once in Blender, render front-lit and idle variants per surface as high-res WebP with alpha; compose numbers from digit sprites | Looks exactly like the reference, cheap at runtime | Heavier assets, skins need re-renders or tinting, no continuous depth animation |

Recommended: start with **A** (reusing Pop Calc code) and a hand-built path for `+`; keep a `GlyphRenderer` interface so **B** can replace it for specific skins later.

**Lite effects:** 4 side layers, no blur on the cast shadow (use a solid 30 percent shape), no grain, speed lines capped at 12.

## 6. Speed lines

Radial burst behind the lit numeral, from the reference `15` and running `10`.

- Origin: numeral center.
- 18–28 lines, random angle with a slight clustering, random inner radius (inside the glyph, hidden behind it) and length (reaching past screen edges).
- Stroke 1.5–3 dp, `speedLine` color, occasional thicker "hero" line.
- Motion: each line slides outward and fades, respawning at a new angle. Line lifetime 500–900 ms, staggered.
- Intensity curve: burst (full density) for 600 ms on start, then settle to about 40 percent density and slower drift. Short re-burst on each minute change and every second in the last 10 s.
- Paused: freeze and fade to 20 percent. Reduce Motion: static lines, no drift.
- Implemented as one `CustomPainter` driven by a single `Ticker`, lines stored in a fixed-size pool (no allocations per frame).

## 7. Motion

Principles carried over from Pop Calc: fast in, soft out; springs for physical things; one hero moment per action; everything interruptible.

### Timing tokens

| Token | Value | Use |
|---|---|---|
| `pageSnap` | Spring (stiffness 300, damping 30) | Preset pager snapping |
| `lightUp` | 380 ms, `easeOutCubic` | Idle → lit material on start |
| `burst` | 600 ms | Speed-line burst on start |
| `minuteTick` | 320 ms spring (stiffness 450, damping 24) | Numeral change each minute |
| `secondPunch` | 180 ms | Last-10-seconds scale punch (1.0 → 1.06 → 1.0) |
| `invert` | 450 ms | Night ↔ Paper radial reveal from tap point |
| `holdRing` | 600 ms linear | Hold-to-cancel/reset ring fill |
| `dimDown` | 260 ms, `easeInCubic` | Lit → idle on pause/cancel |

### Animation catalog

| Trigger | Animation |
|---|---|
| Swipe between presets | Glyphs move with the finger at 1:1, snap with `pageSnap`. The incoming glyph's cast shadow lengthens slightly as it reaches center (depth 0.85 → 1.0) |
| Tap to start | Ring pulses, hint fades out, numeral material lerps idle → lit (`lightUp`), speed lines `burst`, countdown line slides up 8 dp and fades in |
| Minute changes (`10` → `9`) | Old numeral sinks (depth 1 → 0, scale 0.96) while new rises (depth 0 → 1 with overshoot), mini re-burst |
| Crossing 1:00 left | Numeral morphs from `1` to `59` with the same sink/rise, speed lines speed up slightly |
| Last 10 seconds | `secondPunch` + light haptic each second |
| Timer done | Radial `invert` to Paper from the numeral center, numeral becomes `0`, a strong 3-pulse haptic pattern, overtime line appears |
| Tap + (stopwatch) | Radial `invert` from the tap point, + turns from Night to Paper material, counter fades in |
| Stopwatch passes each minute | + (or previous minute) sinks, new minute numeral rises |
| Pause | `dimDown`, speed lines freeze and fade, countdown blinks (1 s on, 0.5 s at 40 percent) |
| Hold | Ring fills around the touch point; release early = spring back, no action |
| Cancel / reset | Numeral dims, inverts back to Night if on Paper, pager returns to the preset that was running |

### Reduce Motion

Read `MediaQuery.disableAnimations`. No springs, no speed-line drift, no punches, no radial reveal (instant cross-fade instead). All states must remain distinguishable.

## 8. Haptics and sound

| Event | Haptic | Sound |
|---|---|---|
| Pager snaps to a preset | `selectionClick` | None |
| Start | `mediumImpact` | Optional soft "whoosh" (Pro) |
| Pause / resume | `lightImpact` | None |
| Minute tick while running | `selectionClick` (setting, on by default) | None |
| Last 10 s, each second | `lightImpact` | Optional tick (Pro) |
| Timer done | Repeating vibration pattern (e.g. 400 on / 200 off ×3, loop) | Alarm sound, looped until dismissed, alarm audio stream |
| Hold completes (cancel/reset) | `heavyImpact` | None |

- Free alarm sounds: 2 (e.g. *Bell*, *Pulse*). Pro: 4–6 more plus a rising volume option.
- Use the alarm audio usage so it respects the alarm volume rather than media volume.
- Keep UI sounds under 200 ms and respect silent mode for everything except the alarm.

## 9. Notifications (visual spec)

| Notification | Content | Actions |
|---|---|---|
| Timer running (ongoing) | Title: `10 min timer`, system chronometer counting down, small icon: + mark | Pause · Cancel |
| Timer paused (ongoing) | `Paused · 7:42 left` | Resume · Cancel |
| Timer done (high priority) | `Time's up · 10 min` | Dismiss · +1 min |
| Stopwatch (ongoing) | Chronometer counting up | Pause · Reset |

Small icon: monochrome silhouette of the + glyph. Accent color from the current skin.

## 10. Icons and store visuals

### App icon

- A sculpted `+` or a single chiseled numeral on a graphite tile, lit from the top-right with a long shadow. Should sit well next to Pop Calc's icon (sibling family).
- Must read at 48 px. Adaptive icon layers plus a monochrome layer for themed icons.

### Store graphics

| Asset | Plan |
|---|---|
| Screenshot 1 | Lit `15` with speed lines and `15:00`, caption "Time, but make it physical" |
| Screenshot 2 | Idle `10` with TAP TO START, caption "Swipe. Tap. Go." |
| Screenshot 3 | White stopwatch `3` with `+00:03:16` |
| Screenshot 4 | Timer done / overtime state |
| Screenshot 5 | Pro skins grid |
| Promo video | 10–15 s screen recording: swipe through presets, tap, burst, minute tick, tap +, invert |
| Feature graphic | 1024 × 500, tilted phone on dark table with scattered sculpted shapes (like the reference mockup) |

Screenshots must show the real app. No features in marketing that the app does not have.

## 11. Accessibility

- Semantics on the pager: "5 minute timer. Double tap to start. Swipe up or down for other times." The + page: "Stopwatch. Double tap to start."
- Custom accessibility actions for hold gestures ("Cancel timer", "Reset stopwatch") so TalkBack users never need to long-press precisely.
- Announce state changes: "Timer started, 10 minutes", "Paused, 7 minutes 42 seconds left", "Time's up".
- Do not announce every second. Announce each minute only when the user requests it via a setting.
- Countdown line supports font scaling to 200 percent; the big numeral is decorative-scale and does not scale with system font.
- Minimum touch target 48 × 48 dp for settings and lap buttons.
- Do not rely on the low-contrast idle numeral for meaning.

## 12. Design QA checklist

- [ ] Idle numerals readable in a dim room and in sunlight (bevels do the work)
- [ ] 60 fps while paging and with speed lines running, mid-range device
- [ ] Lite effects smooth on a low-end device
- [ ] Every minute change, the seconds switch at 1:00, and the last 10 s look right
- [ ] Night ↔ Paper inversions have no flash of wrong color
- [ ] Holds can't be triggered by a normal tap or a scroll
- [ ] Reduce Motion, TalkBack, 200% font verified
- [ ] Notification icon and colors correct in light and dark system themes
- [ ] Screenshots match the real app
