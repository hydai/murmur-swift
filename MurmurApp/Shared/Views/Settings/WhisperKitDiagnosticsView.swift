import Foundation
import MurmurKit
import SwiftUI

struct WhisperKitDiagnosticsView: View {
    @Bindable var viewModel: SettingsViewModel

    private var diagnostics: WhisperKitDiagnosticsSnapshot {
        viewModel.whisperKitDiagnostics
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Image(systemName: diagnostics.hasData ? "waveform.path.ecg" : "waveform.path")
                    .foregroundStyle(diagnostics.hasData ? Color.accentColor : Color.secondary)
                Text(diagnostics.hasData ? "Latest WhisperKit diagnostics" : "No diagnostics captured")
                Spacer()
                Button {
                    viewModel.resetWhisperKitDiagnostics()
                } label: {
                    Label("Reset", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(!diagnostics.hasData)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.s) {
                DiagnosticsTile("Model", value: diagnostics.modelText)
                DiagnosticsTile("Source", value: diagnostics.modelSourceText)
                DiagnosticsTile("Last update", value: timeText(diagnostics.updatedAt))
                DiagnosticsTile("Audio", value: samplesText(diagnostics.totalSamples))
                DiagnosticsTile("First partial", value: millisecondsText(diagnostics.firstPartialLatencyMs))
                DiagnosticsTile("Realtime pass", value: passText(
                    durationMs: diagnostics.lastRealtimeDurationMs,
                    segmentCount: diagnostics.lastRealtimeSegmentCount
                ))
                DiagnosticsTile("Final pass", value: passText(
                    durationMs: diagnostics.lastFinalDurationMs,
                    segmentCount: diagnostics.lastFinalSegmentCount
                ))
                DiagnosticsTile("Native pass", value: nativePassText)
                DiagnosticsTile("Download", value: millisecondsText(diagnostics.lastDownloadDurationMs))
                DiagnosticsTile("Load", value: millisecondsText(diagnostics.lastLoadDurationMs))
                DiagnosticsTile("Cache hits", value: "\(diagnostics.cacheHitCount)")
                DiagnosticsTile("Events", value: eventCountsText)
            }

            if let lastError = diagnostics.lastError {
                HStack(alignment: .top, spacing: Spacing.s) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(lastError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            if !diagnostics.recentEvents.isEmpty {
                Divider().padding(.vertical, Spacing.xs)
                SectionHeader("Recent events")
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(diagnostics.recentEvents) { event in
                        DiagnosticsEventRow(event: event)
                    }
                }
            }
        }
        .task { viewModel.refreshWhisperKitDiagnostics() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                viewModel.refreshWhisperKitDiagnostics()
            }
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 150), spacing: Spacing.s, alignment: .leading)
        ]
    }

    private var nativePassText: String {
        guard let duration = diagnostics.lastNativeTranscriptionDurationMs else { return "Not run" }
        if let sampleCount = diagnostics.lastNativeTranscriptionSampleCount {
            return "\(duration) ms, \(sampleCount) samples"
        }
        return "\(duration) ms"
    }

    private var eventCountsText: String {
        "\(diagnostics.committedEventCount) committed, \(diagnostics.partialEventCount) partial"
    }

    private func passText(durationMs: UInt64?, segmentCount: Int?) -> String {
        guard let durationMs else { return "Not run" }
        if let segmentCount {
            return "\(durationMs) ms, \(segmentCount) segments"
        }
        return "\(durationMs) ms"
    }

    private func samplesText(_ samples: Int?) -> String {
        guard let samples else { return "No audio" }
        let seconds = Double(samples) / 16_000
        return "\(samples) samples (\(String(format: "%.1f", seconds)) s)"
    }

    private func millisecondsText(_ milliseconds: UInt64?) -> String {
        guard let milliseconds else { return "Not run" }
        return "\(milliseconds) ms"
    }

    private func timeText(_ date: Date?) -> String {
        guard let date else { return "Never" }
        return date.formatted(date: .omitted, time: .standard)
    }
}

private struct DiagnosticsTile: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .textSelection(.enabled)
        }
        .frame(minHeight: 44, alignment: .topLeading)
    }
}

private struct DiagnosticsEventRow: View {
    let event: WhisperKitDiagnosticsEvent

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.title)
                        .font(.caption)
                    Spacer()
                    Text(event.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(event.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
    }

    private var icon: String {
        switch event.level {
        case .info:
            return "circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch event.level {
        case .info:
            return .secondary
        case .error:
            return .red
        }
    }
}
