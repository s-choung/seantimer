import SwiftUI

/// Play/pause · reset · float-on-top, in the OpenAI-minimal red/white/black look
/// (plan §1/§6). The play button is disabled at 0 minutes (addendum C).
struct ControlsView: View {
    var model: TimerModel
    @Binding var floatOnTop: Bool

    private var playEnabled: Bool { model.isRunning || model.canPlay }

    var body: some View {
        HStack(spacing: Theme.controlsSpacing) {
            Button(action: model.reset) {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(ControlButtonStyle(enabled: model.phase != .idle))
            .disabled(model.phase == .idle)
            .help("Reset")

            Button(action: playPause) {
                Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
            }
            .buttonStyle(ControlButtonStyle(enabled: playEnabled, prominent: true))
            .disabled(!playEnabled)
            .help(model.isRunning ? "Pause" : "Start")

            Button { floatOnTop.toggle() } label: {
                Image(systemName: floatOnTop ? "pin.fill" : "pin")
            }
            .buttonStyle(ControlButtonStyle(enabled: true, active: floatOnTop))
            .help(floatOnTop ? "Floating on top" : "Float on top")
        }
    }

    private func playPause() {
        switch model.phase {
        case .running: model.pause()
        case .paused:  model.resume()
        default:       model.start()
        }
    }
}

/// Flat circular control button. `prominent` = the red primary (play/pause);
/// `active` = a toggled-on secondary (pin).
private struct ControlButtonStyle: ButtonStyle {
    var enabled: Bool
    var prominent: Bool = false
    var active: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let diameter: CGFloat = prominent ? 66 : 46
        configuration.label
            .font(.system(size: prominent ? 23 : 17, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: diameter, height: diameter)
            .background(background)
            .overlay(
                Circle().stroke(Theme.hairline, lineWidth: prominent ? 0 : 1)
            )
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .opacity(enabled ? 1 : 0.55)
    }

    private var foreground: Color {
        if prominent { return enabled ? .white : Theme.controlDisabled }
        if active { return Theme.red }
        return enabled ? Theme.controlIdle : Theme.controlDisabled
    }

    private var background: some View {
        Group {
            if prominent {
                Circle().fill(enabled ? Theme.red : Theme.fillStrong)
            } else {
                Circle().fill(active ? Theme.red.opacity(0.10) : Theme.fill)
            }
        }
    }
}
