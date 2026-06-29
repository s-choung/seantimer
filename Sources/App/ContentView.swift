import SwiftUI
import AppKit

/// Window layout: a centered goal field, the dial, then the controls row, on a
/// clean white field (plan §1/§6). Resizable — dial and text scale with the
/// window. Top-right: a History (☰) button stacked above Settings (⚙). Toggling
/// History extends the window to the right with an attached white panel (same
/// background), rather than a floating popover.
struct ContentView: View {
    @Bindable var model: TimerModel
    @Binding var floatOnTop: Bool
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var window: NSWindow?

    private let panelWidth: CGFloat = 300

    var body: some View {
        HStack(spacing: 0) {
            mainColumn
            if showHistory {
                HistoryPanel(model: model, onClose: toggleHistory)
                    .frame(width: panelWidth)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Theme.hairline).frame(width: 1)
                    }
            }
        }
        .background(Theme.background)
        .background(WindowAccessor { window = $0 })
        .preferredColorScheme(model.darkMode ? .dark : .light)
    }

    private var mainColumn: some View {
        VStack(spacing: Theme.controlsTopGap) {
            HStack(alignment: .top, spacing: 8) {
                Color.clear.frame(width: 34, height: 1)        // balances the button column
                goalField
                cornerButtons
            }
            ClockFaceView(model: model)
            ControlsView(model: model, floatOnTop: $floatOnTop)
        }
        .padding(Theme.windowPadding)
        .frame(minWidth: 300, idealWidth: 360, maxWidth: .infinity,
               minHeight: 452, idealHeight: 520, maxHeight: .infinity)
    }

    private var goalField: some View {
        // Wraps onto new lines as it grows (up to 3), capped at 80 characters.
        TextField("이 세션의 목표…", text: $model.label, axis: .vertical)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .lineLimit(1 ... 3)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.fill))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
            .frame(maxWidth: .infinity)
            .onChange(of: model.label) { _, new in
                if new.count > 80 { model.label = String(new.prefix(80)) }
            }
    }

    private var cornerButtons: some View {
        VStack(spacing: 8) {
            cornerButton("list.bullet", help: "History", on: showHistory, action: toggleHistory)
            cornerButton("gearshape", help: "Settings", on: showSettings) { showSettings.toggle() }
                .popover(isPresented: $showSettings, arrowEdge: .top) { SettingsView(model: model) }
        }
        .frame(width: 34)
    }

    private func cornerButton(_ symbol: String, help: String, on: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(on ? Theme.red : Theme.controlIdle)
                .frame(width: 30, height: 30)
                .background(Circle().fill(on ? Theme.red.opacity(0.10) : Theme.fill))
                .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    /// Extend / retract the attached history panel by resizing the real window
    /// (top-left fixed, grows to the right). We set the width explicitly both
    /// ways so it always stays ≥ the content's minimum and never double-grows.
    private func toggleHistory() {
        let opening = !showHistory
        showHistory = opening
        guard let window else { return }
        var frame = window.frame
        frame.size.width += opening ? panelWidth : -panelWidth
        window.setFrame(frame, display: true, animate: true)
    }
}

/// Grabs the hosting `NSWindow` so the layout can resize it directly.
private struct WindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { if let window = view.window { onResolve(window) } }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
