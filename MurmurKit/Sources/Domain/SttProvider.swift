import Foundation

/// Protocol for speech-to-text providers.
///
/// Implementations feed audio chunks and receive transcription events
/// via an AsyncStream.
public protocol SttProvider: Sendable {
    /// Start a new transcription session.
    func startSession() async throws

    /// Feed audio data to the provider.
    func sendAudio(_ chunk: AudioChunk) async throws

    /// Signal end of audio input.
    func stopSession() async throws

    /// Stream of transcription events (partial + committed results).
    var events: AsyncStream<TranscriptionEvent> { get }
}
