// swift-tools-version:5.9
import PackageDescription

// SPM package over the **Foundation-only** core logic so the pure-logic phases
// (ClockMath, Countdown, SessionLog) can be unit-tested with `swift test` even
// without full Xcode. The SwiftUI app itself is built from Sources/Core +
// Sources/App via the XcodeGen project (project.yml) or the build script.
//
// The library target is named `Seantimer` so its module name matches the
// Xcode app target — the same test files (`@testable import Seantimer`)
// work under both build systems.
let package = Package(
    name: "Seantimer",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "Seantimer", path: "Sources/Core"),
        .testTarget(
            name: "SeantimerTests",
            dependencies: ["Seantimer"],
            path: "Tests/CoreTests"
        ),
    ]
)
