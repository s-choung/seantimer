import SwiftUI

/// The interactive dial: white face, red wedge, ticks, centre readout, and the
/// drag-to-set gesture (plan §1/§2). The gesture accumulates signed angle deltas
/// through `ClockMath`, so there is no seam jitter and 0/60 are hard stops.
struct ClockFaceView: View {
    var model: TimerModel
    @State private var lastAngle: Double?
    @State private var accumMinutes: Double = 0

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2
            ZStack {
                Circle().fill(Theme.face)
                Circle().strokeBorder(Theme.hairline, lineWidth: 1)

                WedgeShape(fraction: model.wedgeFraction)
                    .fill(Theme.red)
                    // Smooth 1 Hz depletion while running; instant follow while dialing.
                    .animation(model.isRunning ? .linear(duration: 1) : nil,
                               value: model.wedgeFraction)

                DialView()
                CenterReadoutView(model: model)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(center: center, radius: radius))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func dragGesture(center: CGPoint, radius: CGFloat) -> some Gesture {
        // Only the rim band responds — grab near the dial's edge to turn it.
        // A drag that strays into the hub (or far past the rim) pauses until it
        // returns to the band, so the centre readout area is never a grab target.
        let innerBand = radius * 0.55
        let outerBand = radius * 1.20
        return DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard model.canSet else { return }
                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                let dist = sqrt(dx * dx + dy * dy)
                guard dist >= innerBand, dist <= outerBand else {
                    lastAngle = nil      // out of the rim band: pause accumulation
                    return
                }
                let angle = ClockMath.angleCW(point: value.location, center: center)
                if let last = lastAngle {
                    accumMinutes = ClockMath.accumulate(minutes: accumMinutes,
                                                        fromAngle: last, toAngle: angle)
                    model.setMinutes(ClockMath.snap(accumMinutes))
                } else {
                    // (Re)begin from wherever the dial currently sits.
                    accumMinutes = Double(model.setSeconds) / 60
                }
                lastAngle = angle
            }
            .onEnded { _ in lastAngle = nil }
    }
}

/// Big "M:SS" / minutes readout in the hub.
private struct CenterReadoutView: View {
    var model: TimerModel

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let subtitle = side * 0.062            // scales with the window
            VStack(spacing: side * 0.012) {
                if model.phase == .finished {
                    Text("Done")
                        .font(Theme.readoutFont(side * 0.17))
                        .foregroundStyle(Theme.red)
                } else if model.isSetting {
                    Text("\(model.minutesSet)")
                        .font(Theme.readoutFont(side * 0.24))
                        .foregroundStyle(Theme.ink)
                    Text("min")
                        .font(.system(size: subtitle, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    Text(model.readoutText)
                        .font(Theme.readoutFont(side * 0.18))
                        .foregroundStyle(Theme.ink)
                    Text(model.phase == .paused ? "paused" : "remaining")
                        .font(.system(size: subtitle, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }
}
