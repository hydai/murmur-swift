#if os(macOS)
import AppKit
import SwiftUI

/// Manages the NSStatusItem (system tray icon) and its menu.
@MainActor
final class SystemTrayManager {
    private var statusItem: NSStatusItem?
    private var startStopItem: NSMenuItem?

    var onToggleRecording: (() async -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenHistory: (() -> Void)?
    var onQuit: (() -> Void)?

    func setup() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Murmur")
        }

        let menu = NSMenu()

        let startStop = NSMenuItem(title: "Start Recording", action: #selector(toggleRecording), keyEquivalent: "")
        startStop.target = self
        menu.addItem(startStop)
        self.startStopItem = startStop

        menu.addItem(NSMenuItem.separator())

        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let history = NSMenuItem(title: "History", action: #selector(openHistory), keyEquivalent: "")
        history.target = self
        menu.addItem(history)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit Murmur", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    /// Update the menu item title based on recording state.
    func updateRecordingState(isRecording: Bool) {
        startStopItem?.title = isRecording ? "Stop Recording" : "Start Recording"

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: isRecording ? "mic.fill" : "mic",
                accessibilityDescription: "Murmur"
            )
            // Tint the icon red when recording
            button.contentTintColor = isRecording ? .red : nil
        }
    }

    @objc private func toggleRecording() {
        Task {
            await onToggleRecording?()
        }
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func openHistory() {
        onOpenHistory?()
    }

    @objc private func quitApp() {
        onQuit?()
    }
}
#endif
