#!/bin/bash
# Build Seantimer into a runnable .app using only Command Line Tools
# (no full Xcode required). Compiles every source with swiftc, wraps the binary
# in an .app bundle, writes Info.plist, and ad-hoc codesigns it.
#
#   bash build.sh        # build only
#   bash build.sh run    # build, then launch
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$PROJECT/build"
APP="$BUILD/Seantimer.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
TARGET="arm64-apple-macos14.0"

mkdir -p "$MACOS" "$RES"

echo "› compiling…"
swiftc -parse-as-library -sdk "$SDK" -target "$TARGET" \
  "$PROJECT/Sources/Core/ClockMath.swift" \
  "$PROJECT/Sources/Core/Countdown.swift" \
  "$PROJECT/Sources/Core/SessionRecord.swift" \
  "$PROJECT/Sources/Core/SessionLog.swift" \
  "$PROJECT/Sources/App/Theme.swift" \
  "$PROJECT/Sources/App/TimerModel.swift" \
  "$PROJECT/Sources/App/WedgeShape.swift" \
  "$PROJECT/Sources/App/DialView.swift" \
  "$PROJECT/Sources/App/ClockFaceView.swift" \
  "$PROJECT/Sources/App/ControlsView.swift" \
  "$PROJECT/Sources/App/SettingsView.swift" \
  "$PROJECT/Sources/App/HistoryView.swift" \
  "$PROJECT/Sources/App/MenuBarPanel.swift" \
  "$PROJECT/Sources/App/ContentView.swift" \
  "$PROJECT/Sources/App/SeantimerApp.swift" \
  -o "$MACOS/Seantimer"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Seantimer</string>
    <key>CFBundleDisplayName</key>     <string>Seantimer</string>
    <key>CFBundleIdentifier</key>      <string>com.sean.seantimer</string>
    <key>CFBundleExecutable</key>      <string>Seantimer</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>LSApplicationCategoryType</key> <string>public.app-category.productivity</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

# App icon (generated once via icon/RenderIcon.swift + iconutil; copied if present).
if [ -f "$PROJECT/icon/AppIcon.icns" ]; then
  cp "$PROJECT/icon/AppIcon.icns" "$RES/AppIcon.icns"
fi

codesign --force --sign - "$APP" >/dev/null 2>&1 || codesign --force --sign - "$APP"
echo "› built: $APP"

if [ "${1:-}" = "run" ]; then
  echo "› launching…"
  open "$APP"
fi
