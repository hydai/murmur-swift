#if os(macOS)
import AppKit

/// Plays system sound cues for pipeline events.
@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private init() {}

    func playStartSound() {
        NSSound(named: "Tink")?.play()
    }

    func playStopSound() {
        NSSound(named: "Pop")?.play()
    }

    func playErrorSound() {
        NSSound(named: "Basso")?.play()
    }

    func playDoneSound() {
        NSSound(named: "Glass")?.play()
    }
}
#endif
