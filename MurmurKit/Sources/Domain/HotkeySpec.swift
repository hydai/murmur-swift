import Foundation

/// A parsed global hotkey description.
///
/// Stored in a platform-neutral form so the parser can be unit-tested
/// without AppKit. macOS callers (e.g. `GlobalHotkeyManager`) translate
/// `Modifiers` into `NSEvent.ModifierFlags` and `keyCode` is used directly.
public struct HotkeySpec: Sendable, Equatable {
    public struct Modifiers: OptionSet, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option  = Modifiers(rawValue: 1 << 1)
        public static let shift   = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public let modifiers: Modifiers
    /// macOS virtual key code (matches `kVK_ANSI_*` constants).
    public let keyCode: UInt16
    /// Canonical text form used for displaying the spec back to the user.
    public let displayString: String

    public init(modifiers: Modifiers, keyCode: UInt16, displayString: String) {
        self.modifiers = modifiers
        self.keyCode = keyCode
        self.displayString = displayString
    }
}

public extension HotkeySpec {
    /// Parse an accelerator-style string such as `"Ctrl+\`"`, `"Cmd+Shift+Space"`,
    /// `"Alt+F1"`. Tokens are split on `+` and stripped; the final token is the
    /// key, everything before it is a modifier. Modifier and key names are
    /// case-insensitive. Returns nil if the string is empty, has no modifier,
    /// has an unknown modifier/key, or specifies the same modifier twice.
    static func parse(_ raw: String) -> HotkeySpec? {
        let tokens = raw.split(separator: "+", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard tokens.count >= 2 else { return nil }
        guard !tokens.contains(where: \.isEmpty) else { return nil }

        var modifiers = Modifiers()
        for token in tokens.dropLast() {
            guard let m = Self.modifier(for: token) else { return nil }
            if modifiers.contains(m) { return nil }
            modifiers.insert(m)
        }
        guard !modifiers.isEmpty else { return nil }

        let keyToken = tokens.last!
        guard let keyCode = Self.keyCode(for: keyToken) else { return nil }

        return HotkeySpec(
            modifiers: modifiers,
            keyCode: keyCode,
            displayString: Self.canonicalize(modifiers: modifiers, key: keyToken)
        )
    }

    private static func modifier(for token: String) -> Modifiers? {
        switch token.lowercased() {
        case "ctrl", "control":    return .control
        case "alt", "option", "opt": return .option
        case "shift":              return .shift
        case "cmd", "command", "meta", "super": return .command
        default:                   return nil
        }
    }

    private static func canonicalize(modifiers: Modifiers, key: String) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("Ctrl") }
        if modifiers.contains(.option)  { parts.append("Alt") }
        if modifiers.contains(.shift)   { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Cmd") }
        parts.append(key)
        return parts.joined(separator: "+")
    }

    /// macOS virtual key codes (HIToolbox `kVK_ANSI_*` / `kVK_*`).
    /// Case-insensitive lookup over a fixed alias table.
    private static func keyCode(for token: String) -> UInt16? {
        let key = token.lowercased()
        if let code = singleCharKeyCodes[key] { return code }
        if let code = namedKeyCodes[key] { return code }
        return nil
    }

    private static let singleCharKeyCodes: [String: UInt16] = [
        "a": 0,  "s": 1,  "d": 2,  "f": 3,  "h": 4,  "g": 5,
        "z": 6,  "x": 7,  "c": 8,  "v": 9,  "b": 11, "q": 12,
        "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "u": 32,
        "i": 34, "o": 31, "p": 35, "l": 37, "j": 38, "k": 40,
        "n": 45, "m": 46,
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22,
        "7": 26, "8": 28, "9": 25, "0": 29,
        "-": 27, "=": 24, "[": 33, "]": 30, "\\": 42,
        ";": 41, "'": 39, ",": 43, ".": 47, "/": 44,
        "`": 50,
    ]

    private static let namedKeyCodes: [String: UInt16] = [
        "space": 49, "tab": 48,
        "return": 36, "enter": 36,
        "escape": 53, "esc": 53,
        "backspace": 51, "delete": 117,
        "left": 123, "right": 124, "down": 125, "up": 126,
        "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
        "backquote": 50, "grave": 50,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118,
        "f5": 96,  "f6": 97,  "f7": 98, "f8": 100,
        "f9": 101, "f10": 109, "f11": 103, "f12": 111,
        "f13": 105, "f14": 107, "f15": 113,
    ]
}
