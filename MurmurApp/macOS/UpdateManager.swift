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
    private var observer: NSObjectProtocol?

    override init() {
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        observer = NotificationCenter.default.addObserver(
            forName: .murmurCheckForUpdates,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.checkForUpdates() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
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
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .murmurCheckForUpdates,
            object: nil,
            queue: .main
        ) { _ in
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

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
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
