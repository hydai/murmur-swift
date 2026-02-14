#if os(macOS)
import AppKit
import SwiftUI

/// Floating NSPanel overlay for displaying transcription during recording.
/// Non-activating so it doesn't steal focus from other apps.
@MainActor
final class OverlayWindow {
    private var panel: NSPanel?

    /// Show the overlay panel with the given SwiftUI view.
    func show<V: View>(_ view: V) {
        if let panel {
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

    /// Update the panel's opacity.
    func setOpacity(_ opacity: CGFloat) {
        panel?.alphaValue = opacity
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}
#endif
