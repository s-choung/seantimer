# Ultimate Focus — Design & Implementation Plan

> **For Claude (later session):** REQUIRED SUB-SKILL — use `superpowers:executing-plans` to implement Section 8 task-by-task. Code blocks below are **illustrative pseudocode in the plan**, not finished source files.

**Goal:** A lightweight native macOS "Time Timer"-style visual countdown clock that replaces the heavy "Ultimate Focus" app. Drag counterclockwise on a 60-minute dial to set a duration (red wedge fills), press play to count down (red wedge depletes), and log each session to a file.

**Architecture:** Single SwiftUI window app, one `@Observable` state model driving a circular `ClockFaceView`. The countdown is **deadline-based** (remaining time is always derived from an absolute `Date`, never decremented), so accuracy survives app sleep/background. Sessions append to a JSON Lines file on completion or early stop.

**Tech Stack:** SwiftUI + AppKit (NSSound) + Foundation only. No external packages. macOS 14+ (Observation framework). Target bundle ~3–5 MB.

**Design language:** OpenAI-minimal. Colors strictly **red / white / black**. Generous whitespace, one accent (red), restrained SF/system typography, no chrome, no gradients, no shadows beyond the subtlest.

---

## 1. Architecture

### View tree
```
UltimateFocusApp (@main)
└─ WindowGroup  (single window, hidden title bar)
   └─ ContentView
      ├─ ClockFaceView            // the interactive dial — owns drag + wedge
      │  ├─ DialView              // static tick marks + minute labels (60/45/30/15)
      │  ├─ WedgeShape().fill(red)// the depleting/filling red wedge
      │  └─ CenterReadoutView     // big "MM:SS" or "NN min" text in the hub
      └─ ControlsView             // play / pause / reset buttons + optional label field
```

### State model — `TimerModel` (`@Observable`, a single source of truth)
```swift
enum Phase { case idle, setting, running, paused, finished }

@Observable final class TimerModel {
    var phase: Phase = .idle
    var setSeconds: Int = 0          // duration the user dialed in (0…3600)
    var endDate: Date? = nil         // absolute deadline while running
    var remainingAtPause: Int = 0    // frozen remaining while paused
    var sessionStartedAt: Date? = nil
    var label: String = ""

    // Derived (computed), never stored as a decrementing counter:
    var remainingSeconds: Int { … }  // running → max(0, endDate − now); paused → remainingAtPause; else setSeconds
    var fraction: Double { … }       // remaining / max(setSeconds,1) → drives the wedge (0…1)
}
```
Intents (methods): `setMinutes(_:)`, `start()`, `pause()`, `resume()`, `reset()`, `tick()` (called by the timer; on reaching zero → `finish()`), `finish(completed:)`.

### Concrete Swift files
| File | Holds |
|---|---|
| `UltimateFocusApp.swift` | `@main` `App`, `WindowGroup`, window styling, owns one `TimerModel` |
| `Models/TimerModel.swift` | the `@Observable` state machine + intents above |
| `Models/ClockMath.swift` | **pure functions**: drag-point→angle, angle-delta→minutes, snap, clamp. (Unit-tested.) |
| `Models/SessionRecord.swift` | `Codable` struct for one logged session |
| `Models/SessionLog.swift` | append-to-JSONL persistence (FileHandle); creates dir/file. (Unit-tested round-trip.) |
| `Views/ContentView.swift` | layout: clock above, controls below |
| `Views/ClockFaceView.swift` | the `ZStack` dial; hosts the `DragGesture`; binds wedge to `model.fraction` |
| `Views/WedgeShape.swift` | custom `Shape` with `animatableData` for the wedge |
| `Views/DialView.swift` | static ticks + labels (drawn once via `Canvas`) |
| `Views/ControlsView.swift` | play/pause/reset buttons, duration readout |
| `Support/Theme.swift` | color + spacing + font constants (red/white/black) |

No `ObservableObject`/`Combine` needed for state (Observation handles it); `Timer.publish` is the only Combine touch and can be a plain `Timer` instead.

---

## 2. Circular drag interaction (the math)

**Conventions (per brief):** 12 o'clock = 0 / 60 min. Dragging **counterclockwise increases** minutes. So 15 min = 9 o'clock (left), 30 = 6 o'clock (bottom), 45 = 3 o'clock (right), 60 = back to top. **Cap at 60 min** (recommended — simplest; no multi-revolution accounting, matches a physical 60-minute Time Timer).

**Coordinate facts:** SwiftUI's local space has origin top-left, **y increases downward**. Center `C`, touch `P`, `dx = P.x − C.x`, `dy = P.y − C.y`.

**Clock angle** (like a clock hand, measured clockwise from 12 o'clock):
```
angleCW = atan2(dx, -dy)        // 0 at top, +π/2 at 3-o'clock, π at bottom, −π/2 at 9-o'clock
if angleCW < 0 { angleCW += 2π }   // normalize to [0, 2π)
```

### Recommended: incremental angle-delta accumulation (robust, no seam jitter)
Absolute angle→minute mapping is ambiguous exactly at 12 o'clock (is "top" 0 or 60?) and jitters across that seam. Accumulating signed deltas avoids both and makes the 0/60 hard-stops trivial:
```
onDragBegan(P):   lastAngle = angleCW(P)
onDragChanged(P):
    a     = angleCW(P)
    delta = a − lastAngle
    if delta >  π { delta −= 2π }      // take the shortest arc
    if delta < −π { delta += 2π }
    // CCW drag = angleCW decreasing = positive minutes:
    minutesAccum += (−delta) / (2π) * 60
    minutesAccum  = clamp(minutesAccum, 0, 60)   // hard stops at 0 and 60
    lastAngle     = a
    model.setMinutes( snap(minutesAccum) )
```
- **Snap:** `snap(m) = round(m / step) * step`, default `step = 1` min (recommend 1-min; offer 5-min as a setting later). Snap the *recorded/displayed* value; keep the wedge continuous (`fraction` from un-snapped accum) for smooth visuals, or snap both — recommend snap both so the wedge edge lands on tick marks.
- **Clamp:** `[0, 60]`. Because we accumulate, dragging "past" 60 simply pins at 60; dragging back below 0 pins at 0. No wrap-around.

*(Simpler fallback, documented but not recommended: absolute mapping `minutesCCW = (60 − angleCW/2π·60) mod 60` + a "jump > 30 ⇒ clamp to nearest of {0,60}" seam guard. Works, but the delta method is cleaner.)*

Tap-without-drag and a "Reset" both set `setSeconds = 0`. Dragging is only enabled in `.idle`/`.setting` phases (locked while running).

---

## 3. Red-wedge rendering

**Choice: a custom `Shape` with `animatableData`** (not `Canvas`). A filled `Shape` is GPU-composited, gets implicit SwiftUI animation for free, and is the lightest way to animate a single sweeping arc. (`Canvas` is fine for the *static* dial ticks but redraws imperatively — worse fit for the animating wedge.)

```swift
struct WedgeShape: Shape {
    var fraction: Double                 // 0…1 of a full 60-min revolution
    var animatableData: Double { get { fraction } set { fraction = newValue } }

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let start = Angle(degrees: -90)                      // 12 o'clock
        let end   = Angle(degrees: -90 - 360 * fraction)     // sweep COUNTERCLOCKWISE
        var p = Path()
        p.move(to: c)
        p.addArc(center: c, radius: r, startAngle: start, endAngle: end,
                 clockwise: true)        // note: SwiftUI's y-down flips the visual sense;
                                         // pair this sign with the −90·360·fraction above and verify on screen
        p.closeSubpath()
        return p
    }
}
```
- **Same shape for both phases:** while *setting*, `fraction = setSeconds/3600`; while *running*, `fraction = remaining/setSeconds`. The wedge **fills as you drag** and **depletes as it runs** with identical code.
- **Smooth depletion:** drive `fraction` from a 1-second tick wrapped in `withAnimation(.linear(duration: 1))` so each step interpolates smoothly (looks continuous at 1 Hz, near-zero CPU). *Buttery alternative:* wrap the wedge in `TimelineView(.animation)` and compute `fraction` from `Date.now` vs `endDate` every frame — perfectly smooth but redraws at display refresh (more CPU). **Recommend the 1 Hz + linear-animation approach**; it is light and smooth enough.
- Fill with `Theme.red`; the wedge sits above the white face, below the tick labels and center readout.

---

## 4. Timer engine

**Deadline-based, never decrement a counter.** On `start()`/`resume()`: `endDate = Date().addingTimeInterval(remaining)`. The displayed remaining is always `max(0, endDate.timeIntervalSinceNow)`. This is correct after sleep, App Nap, or window occlusion because it reads the wall clock — the timer only *triggers a refresh*, it is not the source of truth.

```swift
// 1 Hz, .common mode so it keeps firing during window resize / menu tracking:
Timer.publish(every: 1, on: .main, in: .common).autoconnect()  // → model.tick()
// tick(): if remainingSeconds <= 0 { finish(completed: true) } else { objectWillChange via @Observable }
```
- **Pause:** `remainingAtPause = remainingSeconds; endDate = nil; stop timer`. **Resume:** `endDate = now + remainingAtPause; start timer`.
- **Accuracy note:** even if the OS throttles the 1 Hz timer while backgrounded, the next fire recomputes from `endDate` and the wedge snaps to the correct position — no drift. `DispatchSourceTimer` is an option but unnecessary; `Timer.publish` is lighter to wire and sufficient.

**At zero (recommend the lightest):**
1. `NSSound(named: "Glass")?.play()` — a built-in system sound, **no bundled asset, no permissions**.
2. `phase = .finished`; show a calm "Done" state on the face (empty wedge + label).
3. `NSApp.requestUserAttention(.criticalRequest)` — bounces the Dock icon if the app isn't frontmost. Zero permission cost.

**Skip `UNUserNotificationCenter` for v1** — it adds an authorization prompt, an entitlement, and a delegate, for little gain on a single-window foreground focus tool. Make it an opt-in v2 setting. (Open question 2.)

---

## 5. Session logging

**Choice: append-only JSON Lines** at `~/Library/Application Support/UltimateFocus/sessions.jsonl` (one JSON object per line).

**Why JSONL over the alternatives:**
- **vs SwiftData:** SwiftData pulls in a model container + framework and is overkill for an append-only event log; it adds migration surface for what is literally "append one record." Against the "lightweight, YAGNI" goal.
- **vs CSV:** JSONL handles the optional `label` and any future field without column-order fragility, and is still trivially greppable/parseable.
- **Append-only** = crash-safe and concurrency-trivial; we never rewrite the file.

```swift
struct SessionRecord: Codable {
    let id: UUID
    let startedAt: Date        // ISO-8601 via .iso8601 strategy
    let plannedSeconds: Int
    let actualSeconds: Int
    let completed: Bool        // true = ran to zero, false = stopped early
    var label: String?
}
```
Write path: ensure dir exists → `FileHandle(forWritingTo:)` → `seekToEndOfFile()` → append `encoded + "\n"`. A record is written on **every** session end (natural finish *or* manual reset/stop while running), with `completed` set accordingly and `actualSeconds = plannedSeconds − remainingAtStop`.

**In-app history: out of scope for v1** — the file is the deliverable. A minimal read-only list view (decode the JSONL into rows) is an easy v2 add (file already structured for it).

---

## 6. Window / presentation style

**Recommendation: a single standalone window for v1** (compact, fixed aspect, hidden title bar), with a **menu-bar countdown readout as a fast-follow (v2)**.

**Rationale:** The core interaction is a *drag on a circular face* — that needs real estate and is awkward in a small menu-bar popover. A Time Timer is also something you want **glanceably parked on screen** while you focus, which a window does well. The user already ships a `MenuBarExtra` app (Speak11), so adding a status-bar "MM:SS" readout later is low-risk and natural — but it's additive, not v1.

Window config for the minimal look:
- `.windowStyle(.hiddenTitleBar)` and `.windowResizability(.contentSize)` — no title chrome, content drives size.
- Square-ish content (the dial + a slim controls row), generous padding, white background.
- Optional **float toggle** (`NSWindow.level = .floating`) so it can sit above other apps during a focus session (open question 7).

---

## 7. Project scaffolding

- **Xcode template:** macOS → App, SwiftUI interface, Swift language, **no** Core Data, **no** tests-bundle-needed-but-add-one (we want a unit test target for `ClockMath` + `SessionLog`). macOS-only target.
- **Deployment target:** macOS 14.0 (Observation `@Observable`). Drop to 13.0 only if needed → then use `ObservableObject`/`@Published` (open question 8).
- **Dependencies:** none. Empty SwiftPM. Linked frameworks: SwiftUI, AppKit (transitive), Foundation. That's it → naturally tiny bundle.
- **Sandbox:** for a personal tool not headed to the App Store, **disable App Sandbox** so the log lands at the clean `~/Library/Application Support/UltimateFocus/`. With sandbox ON, that path silently redirects into `~/Library/Containers/<bundle-id>/Data/…`. Decide explicitly (open question 5).
- **Release lightness:** `SWIFT_OPTIMIZATION_LEVEL = -O`, dead-strip, no asset catalogs beyond the app icon.
- **App icon:** one 1024×1024 PNG (red wedge on white) in `Assets.xcassets` using Xcode's single-size AppIcon (auto-derives the rest).
- **Build/run:** open the `.xcodeproj`, ⌘R. For sharing: Archive → export Developer-ID-signed `.app` (or just run locally).
- **Bundle id / name:** suggest keeping `UltimateFocus` (it replaces the old app); confirm bundle id (open question 9).

---

## 8. Step-by-step build order

> Execute with `superpowers:executing-plans`. Pure-logic files (`ClockMath`, `SessionLog`) get **real unit tests** (TDD); UI phases are verified by eye + on-device run. Commit after each phase.

**Phase 0 — Scaffold.** Create the Xcode App project (macOS 14, no sandbox, unit-test target). Add `Theme.swift` (red/white/black, fonts, spacing). Empty white `ContentView`. Run; commit.

**Phase 1 — Static dial.** `DialView` via `Canvas`: 60 minute ticks (every 5th longer) + labels 60/45/30/15 at top/right/bottom/left. Center it in `ClockFaceView`. Verify proportions; commit.

**Phase 2 — Wedge (fixed).** Add `WedgeShape`; render with a hardcoded `fraction = 0.5` (should sweep CCW from 12 to 6 o'clock). Confirm the `clockwise:`/sign combo looks right on screen. Commit.

**Phase 3 — Clock math (TDD).** Write tests for `ClockMath`: `angleCW(point:center:)`, `minutesDelta(...)` accumulation, `snap`, `clamp` (incl. seam-cross and 0/60 pinning). Implement until green. Commit.

**Phase 4 — Drag-to-set.** Add `DragGesture` in `ClockFaceView` wired through `ClockMath` into `model.setMinutes`. Wedge + center readout follow the drag live; gesture only active in idle/setting. Manually verify CCW fills, hard-stops at 0/60. Commit.

**Phase 5 — State machine + controls.** Flesh out `TimerModel` phases and `ControlsView` (play/pause/reset). Buttons drive transitions; wedge locks during running. No countdown yet (start just freezes the set value). Commit.

**Phase 6 — Countdown engine (TDD where possible).** Deadline-based `start/pause/resume`; `remainingSeconds`/`fraction` derived from `endDate`. 1 Hz `Timer.publish` → `tick()`. Wedge depletes via `withAnimation(.linear(duration: 1))`. Unit-test the remaining/fraction math with injected dates. Verify a 1-min run depletes smoothly to zero. Commit.

**Phase 7 — Finish behavior.** On zero: `NSSound("Glass")`, `.finished` state, `requestUserAttention(.criticalRequest)`. Commit.

**Phase 8 — Session logging (TDD).** `SessionRecord` + `SessionLog` JSONL append with round-trip test (encode→write→read→decode). Hook `finish(completed:)` and manual stop to write a record (`completed` + `actualSeconds`). Verify file contents after a real + an aborted session. Commit.

**Phase 9 — Polish.** Hidden title bar, `.contentSize` resizability, spacing/typography pass to the OpenAI-minimal look, app icon. Commit.

**Phase 10 — (Optional, v2).** Menu-bar `MenuBarExtra` countdown readout; read-only history list; 5-min snap setting; float-on-top toggle; opt-in notification.

---

## 9. Open questions for the user

1. **Window vs menu-bar for v1?** Plan recommends a single standalone window now, menu-bar readout in v2 — confirm.
2. **Finish alert:** system sound (`Glass`) + Dock bounce only, or also a macOS notification (adds a permission prompt)? Recommend sound + bounce for v1.
3. **Cap at 60 min**, or allow multi-hour (multiple revolutions)? Recommend cap at 60.
4. **Snap increment:** 1-minute (recommended) or 5-minute?
5. **Log location / sandbox:** disable App Sandbox to use the clean `~/Library/Application Support/UltimateFocus/` (recommended for a personal tool), or keep sandbox and accept the container path?
6. **In-app history view** now, or just the file for v1 (recommended)?
7. **Always-on-top (floating) window** toggle wanted?
8. **Minimum macOS version:** 14 (clean `@Observable`, recommended) or 13 (needs `ObservableObject`)?
9. **App name / bundle id / icon:** keep "Ultimate Focus" branding, and do you have an icon or should one be generated (red wedge on white)?
10. **Pause supported**, or stop-only? Plan assumes play/pause/reset; confirm pause is wanted.

---

## 10. Locked decisions & review addenda (2026-06-28)

All Section 9 open questions are now **resolved** — implement against these, no further input needed.

| # | Question | **Decision** |
|---|---|---|
| 1 | Window vs menu-bar | **Standalone window** (v1). Menu-bar readout = v2. |
| 2 | Finish alert | **System sound (`Glass`) + Dock bounce only.** No `UNUserNotificationCenter` in v1. |
| 3 | Duration cap | **Cap at 60 min** (single revolution, no multi-rev). |
| 4 | Snap increment | **1-minute** snap. |
| 5 | Sandbox / log path | **App Sandbox OFF** → log at `~/Library/Application Support/UltimateFocus/sessions.jsonl`. |
| 6 | In-app history | **File only** for v1 (no history view). |
| 7 | Floating window toggle | **Yes — include it.** `NSWindow.level = .floating` toggle in `ControlsView`. |
| 8 | Min macOS version | **macOS 14** (user is on 14.2; clean `@Observable`). |
| 9 | Name / bundle id / icon | **Keep "Ultimate Focus"**, bundle id `UltimateFocus`. App icon = generate a red-wedge-on-white 1024² PNG (TODO before Phase 9). |
| 10 | Pause | **Supported** — play / pause / reset (`paused` phase stays in the state machine). |

### Review addenda — implementation gaps to handle during the build
These do **not** change the plan's structure; fold each into the noted phase.

- **A. Wedge sweep sign (Phase 2, priority 1).** `Path.addArc(clockwise:)` flips under SwiftUI's y-down space. The wedge MUST sweep **counterclockwise** to match the CCW drag-to-fill, or the dialed value and the visual diverge. Nail this on screen in Phase 2 before moving on.
- **B. Don't run the 1 Hz timer while idle (Phase 6).** `Timer.publish().autoconnect()` auto-starts and would wake every second even when not counting. Hold the `Cancellable`; **start the tick only on `start()`/`resume()`, cancel on `pause()`/`finish()`/`reset()`** (battery).
- **C. Disable play at zero (Phase 5).** When `setSeconds == 0`, the play button must be disabled / a no-op.
- **D. Dial-drag vs window-move (Phase 9).** With hidden title bar + `isMovableByWindowBackground`, a drag on the dial could also move the window. Ensure the dial's `DragGesture` takes precedence (e.g. gesture priority / move the window only from empty padding), so setting the timer never drags the window.
