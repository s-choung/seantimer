# Seantimer

A lightweight **Time Timer-style** visual countdown for macOS — a red wedge that
depletes as your focus session runs, with a live menu-bar readout and focus history.

[![Download for macOS](https://img.shields.io/badge/⬇%20Download-macOS%20.dmg-2ea44f?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/s-choung/seantimer/releases/latest/download/Seantimer.dmg)

Open the `.dmg`, drag **Seantimer** onto Applications. **macOS 14+ · Apple Silicon.**
First launch (ad-hoc signed): right-click → **Open**, or once run
`xattr -dr com.apple.quarantine /Applications/Seantimer.app`.

## Features

- Drag the dial rim to set 0–60 min; the red wedge depletes 1 Hz as it runs.
- Menu-bar countdown — click to show/hide the window; float-on-top.
- Dark mode (Settings ⚙); finish chime + Dock bounce.
- History (☰): total / lifetime / this-week focus time, inline rename + delete.
- Deadline-based timing survives sleep; sessions saved as JSONL.

## Build

```bash
bash build.sh run    # compile → build/Seantimer.app, then launch
```

`Sources/Core` = pure logic (unit-tested via `swift test`); `Sources/App` =
SwiftUI/AppKit UI. macOS-only — a Windows port would need a UI rewrite (Tauri/Flutter).

---

Independent hobby project inspired by the **Time Timer®** concept; not affiliated
with Time Timer LLC. Code is original.
