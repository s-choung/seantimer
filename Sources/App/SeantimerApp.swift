import SwiftUI
import AppKit

/// Seantimer — a lightweight Time Timer-style visual countdown (plan §6).
/// A resizable hidden-title-bar window plus a live menu-bar readout whose click
/// shows/hides that window. On finish: a system sound (volume per Settings) and
/// a Dock bounce (locked decision 2).
@main
struct SeantimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = TimerModel.shared
    @State private var floatOnTop = false

    var body: some Scene {
        Window("Seantimer", id: "main") {
            ContentView(model: model, floatOnTop: $floatOnTop)
                .onChange(of: floatOnTop) { _, on in applyFloat(on) }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)   // movable + resizable above the min
    }

    /// Float toggle (locked decision 7). Set the app's real window(s) only.
    private func applyFloat(_ on: Bool) {
        for window in NSApplication.shared.windows where window.canBecomeMain {
            window.level = on ? .floating : .normal
        }
    }
}

/// Menu-bar status item: a live countdown that, when clicked, shows/hides the
/// movable, resizable window. (A SwiftUI MenuBarExtra would only give an
/// un-draggable popover, so we drive an NSStatusItem directly.)
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var titleTimer: Timer?
    private let model = TimerModel.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Seantimer")
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
            button.target = self
            button.action = #selector(toggleWindow)
        }
        statusItem = item

        refreshTitle()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refreshTitle() }
        RunLoop.main.add(timer, forMode: .common)
        titleTimer = timer
    }

    private func refreshTitle() {
        statusItem?.button?.title = " " + model.readoutText
    }

    /// Click → bring the window front, or hide it if it's already the key window.
    @objc private func toggleWindow() {
        guard let window = NSApp.windows.first(where: { $0.canBecomeMain }) else {
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        if window.isVisible && window.isKeyWindow {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}
