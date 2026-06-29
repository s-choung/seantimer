import Foundation
import Observation
import AppKit

/// The five states of the timer (plan §1).
enum Phase {
    case idle      // nothing dialed in
    case setting   // a duration is being / has been dialed
    case running   // counting down against an absolute deadline
    case paused    // frozen mid-countdown
    case finished  // reached zero
}

/// Single source of truth (plan §1/§4). The countdown is **deadline-based**:
/// remaining time is always derived from the wall clock vs. an absolute
/// `endDate`, never a decremented counter, so it survives sleep / App Nap.
/// The 1 Hz timer only nudges the observed `remainingSeconds`/`wedgeFraction`
/// so SwiftUI re-renders; it is not the source of truth.
@Observable final class TimerModel {
    /// Duration the app opens with (locked: 15 min default).
    static let defaultMinutes = 15

    /// Shared instance — the SwiftUI scene and the menu-bar status item both
    /// drive this one model.
    static let shared = TimerModel()

    // Observed UI state.
    var phase: Phase = .setting
    var setSeconds: Int = TimerModel.defaultMinutes * 60   // duration dialed in (0…3600)
    var label: String = ""

    // Persisted settings (gear panel).
    var soundEnabled: Bool = UserDefaults.standard.object(forKey: "uf.sound") as? Bool ?? true {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "uf.sound") }
    }
    var volume: Double = UserDefaults.standard.object(forKey: "uf.volume") as? Double ?? 0.7 {
        didSet { UserDefaults.standard.set(volume, forKey: "uf.volume") }
    }
    /// Dark-mode override (sun/moon toggle). Persisted; drives the root
    /// `.preferredColorScheme`, which in turn flips every Theme dynamic color.
    var darkMode: Bool = UserDefaults.standard.bool(forKey: "uf.dark") {
        didSet { UserDefaults.standard.set(darkMode, forKey: "uf.dark") }
    }

    private(set) var remainingSeconds: Int = TimerModel.defaultMinutes * 60
    private(set) var wedgeFraction: Double = Double(TimerModel.defaultMinutes) / ClockMath.maxMinutes

    init() { recompute() }

    // Internal (non-observed) running state.
    @ObservationIgnored private var endDate: Date?
    @ObservationIgnored private var remainingAtPause: Int = 0
    @ObservationIgnored private var sessionStartedAt: Date?
    @ObservationIgnored private var timer: Timer?

    // Injectable seams.
    @ObservationIgnored var now: () -> Date = { Date() }
    @ObservationIgnored var log = SessionLog()

    // MARK: Derived helpers for the views
    var isSetting: Bool { phase == .idle || phase == .setting }
    var minutesSet: Int { setSeconds / 60 }
    var canSet: Bool { phase == .idle || phase == .setting || phase == .finished }
    var canPlay: Bool { setSeconds > 0 && (phase == .idle || phase == .setting || phase == .paused) }
    var isRunning: Bool { phase == .running }

    /// "M:SS" remaining (used while running / paused).
    var readoutText: String {
        let s = max(0, remainingSeconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: Intents
    /// Set the dialed duration in whole minutes (0…60). Only while settable.
    func setMinutes(_ minutes: Int) {
        if phase == .finished { phase = .idle }      // re-dialing after "Done" starts fresh
        guard phase == .idle || phase == .setting else { return }
        let clamped = max(0, min(Int(ClockMath.maxMinutes), minutes))
        setSeconds = clamped * 60
        phase = setSeconds > 0 ? .setting : .idle
        recompute()
    }

    func start() {
        guard canPlay, setSeconds > 0 else { return }   // addendum C: no play at 0
        sessionStartedAt = now()
        endDate = now().addingTimeInterval(Double(setSeconds))
        phase = .running
        startTicking()
        recompute()
    }

    func pause() {
        guard phase == .running else { return }
        remainingAtPause = remainingSeconds
        endDate = nil
        phase = .paused
        stopTicking()
        recompute()
    }

    func resume() {
        guard phase == .paused, remainingAtPause > 0 else { return }
        endDate = now().addingTimeInterval(Double(remainingAtPause))
        phase = .running
        startTicking()
        recompute()
    }

    func reset() {
        if phase == .running || phase == .paused {
            logSession(completed: false)             // an aborted session is still logged
        }
        stopTicking()
        setSeconds = TimerModel.defaultMinutes * 60   // back to the ready 15-min default
        phase = .setting
        endDate = nil
        remainingAtPause = 0
        sessionStartedAt = nil
        recompute()
    }

    /// Called by the 1 Hz timer. Refreshes derived state and fires `finish` at 0.
    func tick() {
        guard phase == .running, let endDate else { return }
        if now() >= endDate {
            finish(completed: true)
        } else {
            recompute()
        }
    }

    func finish(completed: Bool) {
        logSession(completed: completed)
        stopTicking()
        phase = .finished
        endDate = nil
        remainingAtPause = 0
        sessionStartedAt = nil
        recompute()
        playFinishSound()
        NSApplication.shared.requestUserAttention(.criticalRequest)   // Dock bounce if not frontmost
    }

    /// Plays the finish chime at the configured volume, if sound is enabled.
    /// Also used by the Settings "Test" button.
    func playFinishSound() {
        guard soundEnabled, let sound = NSSound(named: "Glass") else { return }
        sound.stop()                  // allow rapid re-trigger (e.g. Test button)
        sound.volume = Float(volume)
        sound.play()
    }

    // MARK: History (read + edit)
    /// Aggregate focus statistics for the history header.
    struct Stats {
        var count: Int           // sessions logged
        var totalSeconds: Int    // lifetime focused seconds (actual, not planned)
        var weekSeconds: Int     // focused seconds within the current calendar week
    }

    /// All logged sessions, newest first (display order).
    func allRecords() -> [SessionRecord] {
        ((try? log.readAll()) ?? []).reversed()
    }

    /// Count + lifetime + this-week focused time. "Focused" = `actualSeconds`,
    /// so an aborted 7-of-15-min session still counts its 7 minutes.
    func stats() -> Stats {
        let records = (try? log.readAll()) ?? []
        let total = records.reduce(0) { $0 + $1.actualSeconds }
        var week = 0
        if let interval = Calendar.current.dateInterval(of: .weekOfYear, for: now()) {
            week = records
                .filter { interval.contains($0.startedAt) }
                .reduce(0) { $0 + $1.actualSeconds }
        }
        return Stats(count: records.count, totalSeconds: total, weekSeconds: week)
    }

    /// Remove one session from the log (history delete).
    func deleteRecord(_ id: UUID) {
        let kept = ((try? log.readAll()) ?? []).filter { $0.id != id }
        try? log.overwrite(kept)
    }

    /// Rename one session's goal label (history inline edit). Empty → nil.
    func updateRecordLabel(_ id: UUID, _ newLabel: String) {
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = ((try? log.readAll()) ?? []).map { record -> SessionRecord in
            guard record.id == id else { return record }
            var copy = record
            copy.label = trimmed.isEmpty ? nil : trimmed
            return copy
        }
        try? log.overwrite(updated)
    }

    // MARK: Private
    private func recompute() {
        let remInterval: Double
        switch phase {
        case .running:
            if let endDate {
                remainingSeconds = Countdown.remainingSeconds(now: now(), endDate: endDate)
                remInterval = Countdown.remainingInterval(now: now(), endDate: endDate)
            } else {
                remainingSeconds = setSeconds
                remInterval = Double(setSeconds)
            }
        case .paused:
            remainingSeconds = remainingAtPause
            remInterval = Double(remainingAtPause)
        case .finished:
            remainingSeconds = 0
            remInterval = 0
        case .idle, .setting:
            remainingSeconds = setSeconds
            remInterval = Double(setSeconds)
        }
        // Time Timer semantics: the wedge always spans (remaining minutes / 60)
        // of a full revolution, so it fills as you dial and depletes as it runs
        // with no jump at play. (Denominator is the full 60-min dial, not
        // setSeconds — see plan §3 note.)
        wedgeFraction = min(1, max(0, remInterval / (ClockMath.maxMinutes * 60)))
    }

    private func startTicking() {
        stopTicking()
        // .common mode so it keeps firing during window resize / menu tracking.
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t   // addendum B: started only on run, cancelled on pause/finish/reset
    }

    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    private func logSession(completed: Bool) {
        guard let startedAt = sessionStartedAt, setSeconds > 0 else { return }
        let remaining = completed ? 0 : remainingSeconds
        let actual = max(0, setSeconds - remaining)
        let record = SessionRecord(id: UUID(), startedAt: startedAt,
                                   plannedSeconds: setSeconds, actualSeconds: actual,
                                   completed: completed,
                                   label: label.isEmpty ? nil : label)
        try? log.append(record)
    }
}
