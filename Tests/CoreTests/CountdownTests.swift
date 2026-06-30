import XCTest
@testable import Seantimer

final class CountdownTests: XCTestCase {
    func testRemainingSecondsDerivedFromDeadline() {
        let now = Date(timeIntervalSince1970: 1000)
        let end = now.addingTimeInterval(60)
        XCTAssertEqual(Countdown.remainingSeconds(now: now, endDate: end), 60)
        XCTAssertEqual(Countdown.remainingSeconds(now: now.addingTimeInterval(59), endDate: end), 1)
        XCTAssertEqual(Countdown.remainingSeconds(now: now.addingTimeInterval(60), endDate: end), 0)
        // Past the deadline (e.g. woke from sleep late) → clamped to 0, no negatives.
        XCTAssertEqual(Countdown.remainingSeconds(now: now.addingTimeInterval(120), endDate: end), 0)
    }

    func testFractionGuardsAndClamps() {
        XCTAssertEqual(Countdown.fraction(remaining: 30, setSeconds: 60), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Countdown.fraction(remaining: 0, setSeconds: 60), 0, accuracy: 1e-9)
        XCTAssertEqual(Countdown.fraction(remaining: 60, setSeconds: 60), 1, accuracy: 1e-9)
        XCTAssertEqual(Countdown.fraction(remaining: 10, setSeconds: 0), 0, accuracy: 1e-9) // divide-by-zero guard
    }
}
