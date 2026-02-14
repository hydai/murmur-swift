import SwiftUI

/// Main transcription view with record button and text display.
struct TranscriptionView: View {
    @State private var viewModel = PipelineViewModel()

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
                        Text("Processed:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
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
                Task {
                    await viewModel.toggleRecording()
                }
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
        .frame(minWidth: 400, minHeight: 300)
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
