import SwiftUI

/// The single red wedge that fills while dialing and depletes while running
/// (plan §3). `animatableData` lets SwiftUI interpolate the sweep for free.
///
/// Addendum A: `Path.addArc(clockwise:)` is evaluated in SwiftUI's y-down space,
/// which inverts the visual sense. Pairing `endAngle = −90 − 360·fraction` with
/// `clockwise: true` makes the wedge sweep **counterclockwise** from 12 o'clock,
/// matching the counterclockwise drag-to-fill. (Mirror of the canonical
/// clockwise progress-ring recipe.)
struct WedgeShape: Shape {
    var fraction: Double   // 0…1 of a full 60-min revolution

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard fraction > 0 else { return p }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let start = Angle(degrees: -90)                          // 12 o'clock
        let end = Angle(degrees: -90 - 360 * min(fraction, 1))   // sweep CCW
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
        p.closeSubpath()
        return p
    }
}
