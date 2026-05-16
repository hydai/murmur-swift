import SwiftUI

/// Design tokens used by the redesigned Settings panel. Match the spacing,
/// color, and corner-radius scale from the Rust v0.2.11 Svelte settings.
enum Spacing {
    static let xs: CGFloat = 4
    static let s:  CGFloat = 8
    static let m:  CGFloat = 12
    static let l:  CGFloat = 16
    static let xl: CGFloat = 24
}

enum CornerRadius {
    static let s: CGFloat = 6
    static let m: CGFloat = 10
}

extension Color {
    /// Background of the detail pane.
    static var settingsBackground: Color { Color(NSColor.windowBackgroundColor) }
    /// Background of grouped form sections.
    static var settingsSectionBackground: Color { Color(NSColor.controlBackgroundColor) }
    /// Sidebar text and icons.
    static var settingsSidebarMuted: Color { Color(NSColor.secondaryLabelColor) }
}
