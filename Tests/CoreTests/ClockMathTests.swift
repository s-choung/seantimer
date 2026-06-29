import XCTest
import CoreGraphics
@testable import UltimateFocus

final class ClockMathTests: XCTestCase {
    let center = CGPoint(x: 100, y: 100)

    func testAngleCWAtCardinalPoints() {
        // 12 o'clock (straight up) → 0
        XCTAssertEqual(ClockMath.angleCW(point: CGPoint(x: 100, y: 0), center: center), 0, accuracy: 1e-9)
        // 3 o'clock (right) → π/2
        XCTAssertEqual(ClockMath.angleCW(point: CGPoint(x: 200, y: 100), center: center), .pi / 2, accuracy: 1e-9)
        // 6 o'clock (down) → π
        XCTAssertEqual(ClockMath.angleCW(point: CGPoint(x: 100, y: 200), center: center), .pi, accuracy: 1e-9)
        // 9 o'clock (left) → 3π/2
        XCTAssertEqual(ClockMath.angleCW(point: CGPoint(x: 0, y: 100), center: center), 3 * .pi / 2, accuracy: 1e-9)
    }

    func testShortestDeltaTakesShortArcAcrossSeam() {
        let a1 = 350.0 * .pi / 180
        let a2 = 10.0 * .pi / 180
        XCTAssertEqual(ClockMath.shortestDelta(from: a1, to: a2), 20.0 * .pi / 180, accuracy: 1e-9)
        XCTAssertEqual(ClockMath.shortestDelta(from: a2, to: a1), -20.0 * .pi / 180, accuracy: 1e-9)
    }

    func testCCWQuarterTurnFromTopIsFifteenMinutes() {
        // top → 9 o'clock the short (counterclockwise) way = +15 min
        let m = ClockMath.accumulate(minutes: 0, fromAngle: 0, toAngle: 3 * .pi / 2)
        XCTAssertEqual(m, 15, accuracy: 1e-9)
    }

    func testCWDragPinsAtZero() {
        // top → 3 o'clock (clockwise) = −15 min, clamped to 0
        let m = ClockMath.accumulate(minutes: 0, fromAngle: 0, toAngle: .pi / 2)
        XCTAssertEqual(m, 0, accuracy: 1e-9)
    }

    func testAccumulatePinsAtSixty() {
        // already at 55, push another +15 → 70, clamped to 60
        let m = ClockMath.accumulate(minutes: 55, fromAngle: 0, toAngle: 3 * .pi / 2)
        XCTAssertEqual(m, 60, accuracy: 1e-9)
    }

    func testSnapToNearestMinuteAndClamp() {
        XCTAssertEqual(ClockMath.snap(14.4), 14)
        XCTAssertEqual(ClockMath.snap(14.6), 15)
        XCTAssertEqual(ClockMath.snap(70), 60)   // clamp after snap
        XCTAssertEqual(ClockMath.snap(-3), 0)
    }
}
