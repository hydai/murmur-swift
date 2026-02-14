#if os(macOS)
import SwiftUI
import MurmurKit

/// SwiftUI content view displayed in the floating overlay panel.
struct OverlayView: View {
    @Bindable var viewModel: PipelineViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Waveform when recording
            if viewModel.isRecording {
                WaveformIndicator(
                    levels: viewModel.recentLevels,
                    voiceActive: viewModel.voiceActive,
                    barCount: 50
                )
                .frame(height: 40)
                .transition(.opacity)
            }

            // Transcription text
            if !viewModel.displayText.isEmpty {
                ScrollView {
                    Text(viewModel.displayText)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 80)
            }

            // Final result
            if !viewModel.finalResult.isEmpty {
                Text(viewModel.finalResult)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
            }

            // Status bar
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let command = viewModel.detectedCommand {
                    Text(command)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2))
                        .clipShape(Capsule())
                }

                if viewModel.processingTimeMs > 0 {
                    Text("\(viewModel.processingTimeMs)ms")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(4)
        .animation(.easeInOut(duration: 0.2), value: viewModel.pipelineState)
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
#endif
