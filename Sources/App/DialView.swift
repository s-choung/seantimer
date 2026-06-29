import SwiftUI

/// Static dial face: 60 minute ticks (every 5th longer) plus the four cardinal
/// labels — 60 at top, 45 right, 30 bottom, 15 left — so the numbers increase
/// counterclockwise (plan §1/§2). Drawn once with `Canvas`.
struct DialView: View {
    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let inset = radius * Theme.tickInset

            // Outline.
            let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                              width: radius * 2, height: radius * 2))
            context.stroke(ring, with: .color(Theme.hairline), lineWidth: 1)

            // 60 ticks.
            for i in 0 ..< 60 {
                let major = (i % 5 == 0)
                let length = radius * (major ? Theme.majorTickLength : Theme.minorTickLength)
                let angle = CGFloat(Angle(degrees: -90 + Double(i) * 6).radians)
                let outer = CGPoint(x: center.x + (radius - inset) * cos(angle),
                                    y: center.y + (radius - inset) * sin(angle))
                let inner = CGPoint(x: center.x + (radius - inset - length) * cos(angle),
                                    y: center.y + (radius - inset - length) * sin(angle))
                var tick = Path()
                tick.move(to: outer)
                tick.addLine(to: inner)
                context.stroke(tick,
                               with: .color(major ? Theme.ink : Theme.inkSoft),
                               lineWidth: major ? 2 : 1)
            }

            // Cardinal labels (counterclockwise numbering).
            let labelRadius = radius - inset - radius * Theme.majorTickLength - 18
            let labels: [(String, Double)] = [("60", -90), ("45", 0), ("30", 90), ("15", 180)]
            for (text, degrees) in labels {
                let a = CGFloat(Angle(degrees: degrees).radians)
                let point = CGPoint(x: center.x + labelRadius * cos(a),
                                    y: center.y + labelRadius * sin(a))
                let resolved = context.resolve(
                    Text(text).font(Theme.tickLabelFont).foregroundStyle(Theme.ink))
                context.draw(resolved, at: point)
            }
        }
        .accessibilityHidden(true)
    }
}
