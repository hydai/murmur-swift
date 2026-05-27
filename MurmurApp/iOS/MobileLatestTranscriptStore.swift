#if os(iOS)
import Foundation

enum MobileLatestTranscriptStore {
    struct Snapshot {
        let text: String?
        let updatedAt: Date?
        let isSharedContainerAvailable: Bool
    }

    static let suiteName = "group.com.hydai.Murmur"
    static let latestTextKey = "latestProcessedTranscript"
    static let latestUpdatedAtKey = "latestProcessedTranscriptUpdatedAt"

    @discardableResult
    static func save(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, let defaults = sharedDefaults else { return false }

        defaults.set(trimmedText, forKey: latestTextKey)
        defaults.set(Date().timeIntervalSince1970, forKey: latestUpdatedAtKey)
        return defaults.synchronize()
    }

    static func snapshot() -> Snapshot {
        guard let defaults = sharedDefaults else {
            return Snapshot(text: nil, updatedAt: nil, isSharedContainerAvailable: false)
        }

        let text = defaults.string(forKey: latestTextKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let timestamp = defaults.double(forKey: latestUpdatedAtKey)
        return Snapshot(
            text: text?.isEmpty == false ? text : nil,
            updatedAt: timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil,
            isSharedContainerAvailable: true
        )
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}
#endif
