import SwiftUI
import MurmurKit

/// Embedded inside ProviderSettingsView when the user selects Apple Speech.
/// Mirrors the Rust Apple STT model UI: shows installed status, lets the
/// user trigger a download with an inline progress bar.
struct AppleSttModelStatusView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(statusText)
                Spacer()
                if case .notInstalled = viewModel.appleSttModelStatus {
                    Button("Download Model") {
                        Task { await viewModel.downloadAppleSttModel() }
                    }
                    .buttonStyle(.bordered)
                } else if case .error = viewModel.appleSttModelStatus {
                    Button("Retry") {
                        Task { await viewModel.downloadAppleSttModel() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            if case .downloading(let progress) = viewModel.appleSttModelStatus {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
            if let err = viewModel.appleSttDownloadError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        }
        .task { await viewModel.refreshAppleSttModelStatus() }
        .onChange(of: viewModel.appleSttLocale) { _, _ in
            Task { await viewModel.refreshAppleSttModelStatus() }
        }
    }

    private var icon: String {
        switch viewModel.appleSttModelStatus {
        case .installed:        return "checkmark.circle.fill"
        case .notInstalled:     return "arrow.down.circle"
        case .downloading:      return "arrow.down.circle.dotted"
        case .error:            return "exclamationmark.triangle.fill"
        case .unsupportedLocale: return "exclamationmark.circle"
        }
    }

    private var iconColor: Color {
        switch viewModel.appleSttModelStatus {
        case .installed:        return .green
        case .notInstalled:     return .secondary
        case .downloading:      return .accentColor
        case .error, .unsupportedLocale: return .red
        }
    }

    private var statusText: String {
        switch viewModel.appleSttModelStatus {
        case .installed:                return "Model installed for \(viewModel.appleSttLocale)"
        case .notInstalled:             return "Model not installed for \(viewModel.appleSttLocale)"
        case .downloading(let progress): return "Downloading… \(Int(progress * 100))%"
        case .error(let message):       return "Error: \(message)"
        case .unsupportedLocale:        return "Locale '\(viewModel.appleSttLocale)' is not supported"
        }
    }
}
