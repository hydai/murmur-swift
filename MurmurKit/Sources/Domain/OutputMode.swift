import Foundation

/// How processed text is delivered to the user.
public enum OutputMode: String, Codable, Sendable, CaseIterable, Hashable {
    case clipboard
    case keyboard
    case both

    public func normalized(
        supportsKeyboardInjection: Bool = PlatformCapabilities.supportsKeyboardInjection
    ) -> OutputMode {
        supportsKeyboardInjection ? self : .clipboard
    }

    public static func availableModes(
        supportsKeyboardInjection: Bool = PlatformCapabilities.supportsKeyboardInjection
    ) -> [OutputMode] {
        supportsKeyboardInjection ? allCases : [.clipboard]
    }
}
