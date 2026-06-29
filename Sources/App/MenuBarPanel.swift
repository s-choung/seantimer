import SwiftUI
import AppKit

/// Contents of the menu-bar popover: the full dial/controls, plus a header
/// button to pop the timer out into the movable, resizable window (a popover
/// itself can't be dragged, so this is how you reposition it).
struct MenuBarPanel: View {
    var model: TimerModel
    @Binding var floatOnTop: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Open as window", systemImage: "macwindow")
                        .font(Theme.labelFont)
                        .foregroundStyle(Theme.controlIdle)
                }
                .buttonStyle(.plain)
                .help("Open the movable, resizable window")
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            ContentView(model: model, floatOnTop: $floatOnTop)
        }
    }
}
