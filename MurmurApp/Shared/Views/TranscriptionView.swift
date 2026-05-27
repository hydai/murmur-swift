import SwiftUI
import MurmurKit

/// Main transcription view with record button and text display.
struct TranscriptionView: View {
    @State private var viewModel: PipelineViewModel
    @State private var didCopyFinalResult = false
    private let recordingGate: (() async -> Bool)?

    init(
        viewModel: PipelineViewModel = PipelineViewModel(),
        recordingGate: (() async -> Bool)? = nil
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.recordingGate = recordingGate
    }

    var body: some View {
        VStack(spacing: 20) {
            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Transcription display
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if !viewModel.displayText.isEmpty {
                        Text(viewModel.displayText)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !viewModel.finalResult.isEmpty {
                        Divider()
                        HStack {
                            Text("Processed:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            MobileShareButton(text: viewModel.finalResult)
                                .font(.caption)
                            Button {
                                copyFinalResult()
                            } label: {
                                Label(
                                    didCopyFinalResult ? "Copied" : "Copy",
                                    systemImage: didCopyFinalResult ? "checkmark" : "doc.on.doc"
                                )
                            }
                            .font(.caption)
                        }
                        Text(viewModel.finalResult)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if viewModel.processingTimeMs > 0 {
                            Text("Processed in \(viewModel.processingTimeMs)ms")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if viewModel.displayText.isEmpty && viewModel.finalResult.isEmpty {
                        Text("Press the button and start speaking...")
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Audio level indicator
            if viewModel.isRecording {
                AudioLevelBar(rms: viewModel.currentRMS, voiceActive: viewModel.voiceActive)
                    .frame(height: 4)
            }

            // Error display
            if let error = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button {
                            viewModel.resetError()
                        } label: {
                            Label("Dismiss", systemImage: "xmark.circle")
                        }

                        if !viewModel.isRecording {
                            Button {
                                retryRecording()
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Detected command badge
            if let command = viewModel.detectedCommand {
                Text("Command: \(command)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())
            }

            // Record button
            Button {
                toggleRecording()
            } label: {
                HStack {
                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                    Text(viewModel.isRecording ? "Stop" : "Record")
                }
                .frame(minWidth: 120)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isRecording ? .red : .accentColor)
        }
        .padding()
        .modifier(TranscriptionViewSizing())
    }

    private var statusColor: Color {
        switch viewModel.pipelineState {
        case .idle: .gray
        case .recording: .red
        case .transcribing: .orange
        case .processing: .blue
        case .done: .green
        case .error: .red
        }
    }

    private var statusText: String {
        switch viewModel.pipelineState {
        case .idle: "Ready"
        case .recording: "Recording..."
        case .transcribing: "Transcribing..."
        case .processing: "Processing..."
        case .done: "Done"
        case .error: "Error"
        }
    }

    private func copyFinalResult() {
        let text = viewModel.finalResult
        guard !text.isEmpty else { return }
        Task {
            try? await ClipboardOutput().outputText(text)
            didCopyFinalResult = true
            try? await Task.sleep(for: .seconds(1))
            didCopyFinalResult = false
        }
    }

    private func toggleRecording() {
        Task {
            if !viewModel.isRecording, let recordingGate {
                guard await recordingGate() else { return }
            }
            await viewModel.toggleRecording()
        }
    }

    private func retryRecording() {
        Task {
            viewModel.resetError()
            if let recordingGate {
                guard await recordingGate() else { return }
            }
            await viewModel.startRecording()
        }
    }
}

private struct MobileShareButton: View {
    let text: String

    var body: some View {
        #if os(iOS)
        if !text.isEmpty {
            ShareLink(item: text) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        #else
        EmptyView()
        #endif
    }
}

private struct TranscriptionViewSizing: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.frame(minWidth: 400, minHeight: 300)
        #else
        content
        #endif
    }
}

/// Simple horizontal bar showing audio RMS level.
struct AudioLevelBar: View {
    let rms: Float
    let voiceActive: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))

                RoundedRectangle(cornerRadius: 2)
                    .fill(voiceActive ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: geo.size.width * CGFloat(min(rms * 5, 1.0)))
                    .animation(.linear(duration: 0.05), value: rms)
            }
        }
    }
}
