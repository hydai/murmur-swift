#if os(macOS)
import AppKit

/// Manages global hotkey registration for toggle recording.
/// Uses NSEvent.addGlobalMonitorForEvents for key press detection.
@MainActor
final class GlobalHotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    var onHotkeyPressed: (() -> Void)?

    /// Start listening for the global hotkey (Ctrl+`).
    func start() {
        // Monitor key events when app is NOT focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Monitor key events when app IS focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    /// Stop listening for hotkey events.
    func stop() {
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
        // Ctrl + ` (backtick, keyCode 50)
        guard event.modifierFlags.contains(.control),
              event.keyCode == 50 else { return }
        onHotkeyPressed?()
    }
}
#endif
