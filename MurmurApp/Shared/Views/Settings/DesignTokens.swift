import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

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
    static var settingsBackground: Color {
        #if canImport(AppKit)
        Color(NSColor.windowBackgroundColor)
        #elseif canImport(UIKit)
        Color(UIColor.systemBackground)
        #else
        Color(.background)
        #endif
    }

    /// Background of grouped form sections.
    static var settingsSectionBackground: Color {
        #if canImport(AppKit)
        Color(NSColor.controlBackgroundColor)
        #elseif canImport(UIKit)
        Color(UIColor.secondarySystemGroupedBackground)
        #else
        Color(.secondary.opacity(0.1))
        #endif
    }

    /// Sidebar text and icons.
    static var settingsSidebarMuted: Color {
        #if canImport(AppKit)
        Color(NSColor.secondaryLabelColor)
        #elseif canImport(UIKit)
        Color(UIColor.secondaryLabel)
        #else
        Color.secondary
        #endif
    }
}
