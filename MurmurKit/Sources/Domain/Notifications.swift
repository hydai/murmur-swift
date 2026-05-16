import Foundation

public extension Notification.Name {
    /// Posted when `AppConfig` is persisted via `ConfigManager.setConfig` or
    /// `update`. Observers (e.g. the AppDelegate hotkey/theme/opacity wiring)
    /// re-read the config from `ConfigManager` to apply runtime changes.
    static let murmurConfigDidChange = Notification.Name("com.hydai.Murmur.configDidChange")

    /// Posted by the Settings panel or the system tray when the user wants
    /// to trigger an immediate update check. Observed by the Sparkle-backed
    /// UpdateManager (added in Phase 2.2).
    static let murmurCheckForUpdates = Notification.Name("com.hydai.Murmur.checkForUpdates")
}
