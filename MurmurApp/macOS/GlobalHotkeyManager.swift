#if os(macOS)
import AppKit
import MurmurKit
import os

/// Manages global hotkey registration for toggle recording.
/// Uses `NSEvent.addGlobalMonitorForEvents` for key press detection.
@MainActor
final class GlobalHotkeyManager {
    private static let log = Logger(subsystem: "com.hydai.Murmur", category: "GlobalHotkey")

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var spec: HotkeySpec = Self.defaultSpec

    var onHotkeyPressed: (() -> Void)?

    static let defaultSpec = HotkeySpec(modifiers: .control, keyCode: 50, displayString: "Ctrl+`")

    /// Start listening with the provided spec (defaults to Ctrl+`).
    func start(spec: HotkeySpec = Self.defaultSpec) {
        self.spec = spec
        installMonitors()
    }

    /// Replace the current spec at runtime.
    func reregister(spec: HotkeySpec) {
        removeMonitors()
        self.spec = spec
        installMonitors()
    }

    /// Convenience: parse a string from `AppConfig.hotkey`. Falls back to the
    /// default Ctrl+` when parsing fails, after logging a warning.
    func reregister(rawHotkey: String) {
        if let parsed = HotkeySpec.parse(rawHotkey) {
            reregister(spec: parsed)
        } else {
            Self.log.warning("Unparsable hotkey '\(rawHotkey, privacy: .public)', falling back to Ctrl+`")
            reregister(spec: Self.defaultSpec)
        }
    }

    func stop() {
        removeMonitors()
    }

    // MARK: - Private

    private func installMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    private func removeMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard event.keyCode == spec.keyCode else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard Self.appKitFlags(for: spec.modifiers) == flags else { return }
        onHotkeyPressed?()
    }

    private static func appKitFlags(for modifiers: HotkeySpec.Modifiers) -> NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags()
        if modifiers.contains(.control) { flags.insert(.control) }
        if modifiers.contains(.option)  { flags.insert(.option) }
        if modifiers.contains(.shift)   { flags.insert(.shift) }
        if modifiers.contains(.command) { flags.insert(.command) }
        return flags
    }
}
#endif
