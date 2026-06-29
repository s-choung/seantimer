import Foundation

/// Pure deadline-based countdown math (plan §4).
///
/// Remaining time is **always derived** from the wall clock vs. an absolute
/// deadline — never a decremented counter — so it stays correct across app
/// sleep, App Nap, or window occlusion. The 1 Hz timer only triggers a refresh;
/// it is not the source of truth.
enum Countdown {
    /// Whole seconds remaining until `endDate` as seen from `now`, never below 0.
    /// Uses ceiling so the readout shows e.g. "1:00" for the full first second
    /// and only flips to "0:59" once a whole second has elapsed.
    static func remainingSeconds(now: Date, endDate: Date) -> Int {
        let interval = endDate.timeIntervalSince(now)
        guard interval > 0 else { return 0 }
        return Int(interval.rounded(.up))
    }

    /// Continuous seconds remaining (for a smooth wedge), never below 0.
    static func remainingInterval(now: Date, endDate: Date) -> Double {
        max(0, endDate.timeIntervalSince(now))
    }

    /// Wedge fraction in `0…1` = remaining / set duration. Guards divide-by-zero.
    static func fraction(remaining: Double, setSeconds: Int) -> Double {
        guard setSeconds > 0 else { return 0 }
        let f = remaining / Double(setSeconds)
        return min(1, max(0, f))
    }

    /// Integer-seconds convenience overload (used by the 1 Hz readout/wedge).
    static func fraction(remaining: Int, setSeconds: Int) -> Double {
        fraction(remaining: Double(remaining), setSeconds: setSeconds)
    }
}
