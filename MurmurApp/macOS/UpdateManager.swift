#if os(macOS)
import AppKit
import MurmurKit

#if canImport(Sparkle)
import Sparkle

/// Sparkle-backed auto-updater. Wires `SPUStandardUpdaterController` to the
/// app and exposes `checkForUpdates()` for the system tray and About panel.
@MainActor
final class UpdateManager: NSObject {
    private let controller: SPUStandardUpdaterController

    override init() {
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        // UpdateManager lives for the app's lifetime; the observer is torn
        // down at process exit, so we don't need to remove it in deinit
        // (which would require accessing MainActor state from a nonisolated
        // context under Swift 6 strict concurrency).
        _ = NotificationCenter.default.addObserver(
            forName: .murmurCheckForUpdates,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.checkForUpdates() }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }
}
#else
/// Sparkle isn't linked yet — register a placeholder that listens for the
/// notification and logs a hint. To enable updates, add the Sparkle Swift
/// Package to the Murmur target in Xcode (see DISTRIBUTION.md).
@MainActor
final class UpdateManager {
    init() {
        // Lives for the app's lifetime — observer is torn down at process
        // exit so no deinit cleanup is needed.
        _ = NotificationCenter.default.addObserver(
            forName: .murmurCheckForUpdates,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                let alert = NSAlert()
                alert.messageText = "Auto-update is not configured"
                alert.informativeText = """
                Sparkle has not been added to this build. Open Murmur.xcodeproj, \
                File → Add Package Dependencies, paste \
                https://github.com/sparkle-project/Sparkle, and rebuild.
                """
                alert.alertStyle = .informational
                alert.runModal()
            }
        }
    }

    func checkForUpdates() {
        NotificationCenter.default.post(name: .murmurCheckForUpdates, object: nil)
    }

    var automaticallyChecksForUpdates: Bool {
        get { false }
        set { _ = newValue }
    }
}
#endif
#endif
