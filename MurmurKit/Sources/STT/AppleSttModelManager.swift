import Foundation
import Speech

/// Status of the on-device Apple Speech model for a given locale.
public enum AppleSttModelStatus: Sendable, Equatable {
    case installed
    case notInstalled
    case downloading(Double) // progress 0.0...1.0
    case error(String)
    case unsupportedLocale
}

/// Standalone manager for querying / downloading Apple Speech models.
/// Mirrors the Rust `download_apple_stt_model` IPC: returns progress so
/// the UI can show a bar instead of an opaque "downloading…" log line.
public actor AppleSttModelManager {
    public init() {}

    /// Check whether the model for a given locale (or its language fallback)
    /// is installed locally.
    public func status(for locale: Locale) async -> AppleSttModelStatus {
        let supported = await SpeechTranscriber.supportedLocales
        let resolved = Self.resolve(locale: locale, in: supported)
        guard let resolved else {
            return .unsupportedLocale
        }
        let installed = await SpeechTranscriber.installedLocales
        if installed.contains(where: { $0.identifier == resolved.identifier }) {
            return .installed
        }
        let lang = resolved.language.languageCode?.identifier
        if installed.contains(where: { $0.language.languageCode?.identifier == lang }) {
            return .installed
        }
        return .notInstalled
    }

    /// Download and install the model for `locale`. `onProgress` is called on
    /// every progress update from `AssetInventory`.
    public func download(
        for locale: Locale,
        onProgress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws {
        let supported = await SpeechTranscriber.supportedLocales
        guard let resolved = Self.resolve(locale: locale, in: supported) else {
            throw MurmurError.stt("Locale '\(locale.identifier)' is not supported by Apple Speech.")
        }
        let stt = SpeechTranscriber(locale: resolved, preset: .progressiveTranscription)
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [stt]) else {
            // No assets needed — already installed.
            onProgress(1.0)
            return
        }
        // Spawn an observer that polls the Foundation Progress object. We
        // can't await individual progress callbacks because AssetInventory
        // hides them — but `request.progress` is a standard NSProgress.
        let observerTask = Task {
            let progress = request.progress
            while !Task.isCancelled, !progress.isFinished {
                onProgress(progress.fractionCompleted)
                try? await Task.sleep(for: .milliseconds(250))
            }
            onProgress(1.0)
        }
        do {
            try await request.downloadAndInstall()
        } catch {
            observerTask.cancel()
            throw MurmurError.stt("Download failed: \(error.localizedDescription)")
        }
        observerTask.cancel()
    }

    private static func resolve(locale: Locale, in supported: [Locale]) -> Locale? {
        if supported.contains(where: { $0.identifier == locale.identifier }) {
            return locale
        }
        let lang = locale.language.languageCode?.identifier
        return supported.first(where: { $0.language.languageCode?.identifier == lang })
    }
}
