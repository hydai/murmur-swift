import Foundation

public extension Notification.Name {
    /// Posted when `AppConfig` is persisted via `ConfigManager.setConfig` or
    /// `update`. Observers (e.g. the AppDelegate hotkey/theme/opacity wiring)
    /// re-read the config from `ConfigManager` to apply runtime changes.
    static let murmurConfigDidChange = Notification.Name("com.hydai.Murmur.configDidChange")
}
