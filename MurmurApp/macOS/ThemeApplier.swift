#if os(macOS)
import AppKit

/// Applies the `uiPreferences.theme` setting to `NSApp.appearance`.
@MainActor
enum ThemeApplier {
    static func apply(_ theme: String) {
        let appearance: NSAppearance?
        switch theme.lowercased() {
        case "dark":  appearance = NSAppearance(named: .darkAqua)
        case "light": appearance = NSAppearance(named: .aqua)
        default:      appearance = nil  // system follows OS preference
        }
        NSApp.appearance = appearance
    }
}
#endif
