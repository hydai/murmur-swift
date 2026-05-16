#if os(macOS)
import AppKit
import SwiftUI

/// Floating NSPanel overlay for displaying transcription during recording.
/// Non-activating so it doesn't steal focus from other apps.
@MainActor
final class OverlayWindow {
    private var panel: NSPanel?
    private var opacity: CGFloat = 1.0

    /// Show the overlay panel with the given SwiftUI view.
    func show<V: View>(_ view: V) {
        if let panel {
            panel.alphaValue = opacity
            panel.orderFront(nil)
            return
        }

        let hostingView = NSHostingView(rootView: view)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 200),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        // Position at top-center of the main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 300
            let y = screenFrame.maxY - 220
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = opacity
        panel.orderFront(nil)
        self.panel = panel
    }

    /// Hide the overlay panel.
    func hide() {
        panel?.orderOut(nil)
    }

    /// Close and release the panel.
    func close() {
        panel?.close()
        panel = nil
    }

    /// Update the panel's opacity. Persists across show/hide cycles.
    func setOpacity(_ opacity: CGFloat) {
        self.opacity = opacity
        panel?.alphaValue = opacity
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}
#endif
