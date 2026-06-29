import SwiftUI
import AppKit

/// OpenAI-minimal design tokens (plan §intro). One accent (red), restrained
/// system typography, generous whitespace. Light + dark are the same layout —
/// only the neutrals flip. Every neutral is a **dynamic** color that resolves
/// against the current `NSAppearance`, so toggling `.preferredColorScheme`
/// repaints the whole UI (dial, ticks, controls, panel) with no per-view work.
enum Theme {
    /// Build a Color that picks `light` or `dark` based on the resolved appearance.
    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }

    // Palette — one accent only (kept constant across modes, nudged a touch
    // brighter in dark so it doesn't muddy against the near-black face).
    static let red = dynamic(light: NSColor(red: 0.90, green: 0.16, blue: 0.16, alpha: 1),
                             dark:  NSColor(red: 0.98, green: 0.30, blue: 0.30, alpha: 1))

    static let face       = dynamic(light: .white,                       dark: NSColor(white: 0.16, alpha: 1)) // dial face
    static let background = dynamic(light: .white,                       dark: NSColor(white: 0.11, alpha: 1)) // window
    static let ink        = dynamic(light: .black,                       dark: NSColor(white: 0.97, alpha: 1)) // text + major ticks
    static let inkSoft    = dynamic(light: NSColor(white: 0, alpha: 0.45), dark: NSColor(white: 1, alpha: 0.55)) // minor ticks / labels
    static let hairline   = dynamic(light: NSColor(white: 0, alpha: 0.12), dark: NSColor(white: 1, alpha: 0.16)) // outlines
    static let controlIdle = dynamic(light: NSColor(white: 0, alpha: 0.65), dark: NSColor(white: 1, alpha: 0.70)) // control glyphs
    static let controlDisabled = dynamic(light: NSColor(white: 0, alpha: 0.18), dark: NSColor(white: 1, alpha: 0.22))

    // Subtle fills (chips, idle button backgrounds). Tinted off the ink so they
    // stay visible on both fields — black-wash on white, white-wash on near-black.
    static let fill       = dynamic(light: NSColor(white: 0, alpha: 0.04), dark: NSColor(white: 1, alpha: 0.07))
    static let fillStrong = dynamic(light: NSColor(white: 0, alpha: 0.06), dark: NSColor(white: 1, alpha: 0.10))

    // Spacing.
    static let windowPadding: CGFloat = 28
    static let controlsSpacing: CGFloat = 24
    static let controlsTopGap: CGFloat = 18

    // Typography.
    static func readoutFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded).monospacedDigit()
    }
    static let labelFont: Font = .system(size: 13, weight: .regular, design: .rounded)
    static let tickLabelFont: Font = .system(size: 13, weight: .medium, design: .rounded)

    // Dial geometry (fractions of the face radius).
    static let majorTickLength: CGFloat = 0.10
    static let minorTickLength: CGFloat = 0.05
    static let tickInset: CGFloat = 0.02
}
