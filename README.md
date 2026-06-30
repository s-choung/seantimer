# timetimer_sean

A lightweight **Time Timer-style** visual countdown for macOS — a red wedge that
depletes as your focus session runs, an OpenAI-minimal red/white/black look, a
live menu-bar readout, and a focus history with weekly stats.

> SwiftUI + AppKit, macOS 14+. Builds with just the Command Line Tools (no full
> Xcode required).

## Download

**[⬇ Download timetimer_sean.dmg](https://github.com/s-choung/timetimer/releases/latest/download/timetimer_sean.dmg)** — open it, then drag the app onto the **Applications** shortcut.

Prefer a plain archive? Grab the [.zip](https://github.com/s-choung/timetimer/releases/latest/download/timetimer_sean.zip), or browse all [Releases](https://github.com/s-choung/timetimer/releases). Requires **macOS 14 (Sonoma)+** on **Apple Silicon (arm64)**.

> **First launch:** this build is ad-hoc signed (no Apple notarization), so
> macOS may say it can't verify the developer. Right-click the app → **Open** →
> **Open**, or run once:
> ```bash
> xattr -dr com.apple.quarantine /Applications/timetimer_sean.app
> ```

## Features

- **Drag-to-set dial** — grab the rim and turn to dial 0–60 minutes; the wedge
  fills as you set and depletes 1 Hz as it runs.
- **Deadline-based countdown** — survives sleep / App Nap (time is derived from
  the wall clock, never a decremented counter).
- **Menu-bar readout** — live `M:SS` in the status bar; click to show/hide the
  movable, resizable window. Float-on-top toggle.
- **Dark mode** — toggle inside Settings (⚙). Every neutral is a dynamic color,
  so the whole UI (dial, ticks, controls, panel) repaints.
- **Finish chime + Dock bounce** — system sound at a configurable volume.
- **History (☰)** — completed/aborted sessions newest-first with:
  - `지금까지 수행한 타이머` (total count)
  - `지금까지 집중한 시간` (lifetime focused time)
  - `이번주 집중한 시간` (this calendar week)
  - inline **rename** (✎) and **delete** (🗑) per row.
- **Persistence** — append-only JSON Lines at
  `~/Library/Application Support/UltimateFocus/sessions.jsonl`.

## Build & run

```bash
bash build.sh        # compile → build/timetimer_sean.app
bash build.sh run    # build, then launch
```

Alternatively, generate an Xcode project:

```bash
brew install xcodegen
xcodegen            # → UltimateFocus.xcodeproj, then open and ⌘R
```

## Tests

Core logic (ClockMath / Countdown / SessionLog) is Foundation-only and unit-tested:

```bash
swift test          # requires full Xcode for XCTest
```

## Layout

```
Sources/Core   pure logic (ClockMath, Countdown, SessionRecord, SessionLog)
Sources/App    SwiftUI + AppKit UI (dial, controls, history, menu bar)
Tests/CoreTests  XCTest over the core
```

## Platform note

This is a **macOS-only** app (SwiftUI + AppKit: `NSStatusItem`, `NSWindow`).
A cross-platform (incl. Windows) port would mean re-implementing the UI in a
framework like Tauri or Flutter; only `Sources/Core` would carry over.
