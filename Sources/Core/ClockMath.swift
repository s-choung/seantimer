import Foundation
import CoreGraphics

/// Pure geometry for the circular drag-to-set interaction (plan §2).
///
/// Conventions: 12 o'clock = 0/60 min. A **counterclockwise** drag increases
/// minutes (15 = 9 o'clock, 30 = 6 o'clock, 45 = 3 o'clock, 60 = back to top).
/// Minutes are accumulated from signed angle deltas so there is no seam jitter
/// at 12 o'clock and the 0/60 hard stops are trivial. Cap is a single
/// revolution: [0, 60].
enum ClockMath {
    static let maxMinutes: Double = 60

    /// Clockwise angle from 12 o'clock, in radians, normalized to `[0, 2π)`.
    /// SwiftUI local space has origin top-left with **y increasing downward**.
    /// `atan2(dx, -dy)` ⇒ 0 at top, +π/2 at 3 o'clock, π at bottom, 3π/2 at 9.
    static func angleCW(point p: CGPoint, center c: CGPoint) -> Double {
        let dx = Double(p.x - c.x)
        let dy = Double(p.y - c.y)
        var a = atan2(dx, -dy)
        if a < 0 { a += 2 * .pi }
        return a
    }

    /// Shortest signed delta `a2 − a1`, wrapped to `(−π, π]` so a drag that
    /// crosses the 0/2π seam takes the short arc instead of nearly a full turn.
    static func shortestDelta(from a1: Double, to a2: Double) -> Double {
        var d = a2 - a1
        if d > .pi { d -= 2 * .pi }
        if d < -.pi { d += 2 * .pi }
        return d
    }

    /// Apply one drag step: accumulate minutes from a change in clockwise angle.
    /// A CCW drag makes `angleCW` decrease, which must *increase* minutes — hence
    /// the `−delta`. Result is clamped to `[0, 60]` so dragging "past" an end
    /// simply pins there (no wrap-around).
    static func accumulate(minutes current: Double, fromAngle a1: Double, toAngle a2: Double) -> Double {
        let delta = shortestDelta(from: a1, to: a2)
        let deltaMinutes = (-delta) / (2 * .pi) * maxMinutes
        return clamp(current + deltaMinutes)
    }

    /// Clamp minutes to a single revolution `[0, 60]`.
    static func clamp(_ m: Double) -> Double {
        min(maxMinutes, max(0, m))
    }

    /// Snap to the nearest `step` (default 1 min), then clamp, as a whole number.
    static func snap(_ m: Double, step: Double = 1) -> Int {
        let snapped = (m / step).rounded() * step
        return Int(clamp(snapped))
    }
}
