import SwiftUI
import MurmurKit

/// Embedded inside ProviderSettingsView when the user selects WhisperKit.
/// Shows the native runtime load state and lets the user proactively download,
/// specialize, and load the selected Core ML model.
struct WhisperKitModelStatusView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(statusText)
                Spacer()
                if viewModel.whisperKitModelStatus != .ready {
                    Button(buttonTitle) {
                        Task { await viewModel.preloadWhisperKitModel() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.whisperKitModelStatus.isBusy)
                }
            }

            if case .downloading(let progress) = viewModel.whisperKitModelStatus {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }

            Divider().padding(.vertical, Spacing.xs)

            HStack {
                Image(systemName: storageIcon)
                    .foregroundStyle(storageColor)
                Text(storageText)
                Spacer()
                Text(viewModel.whisperKitCacheSizeText)
                    .foregroundStyle(.secondary)
            }

            Text(viewModel.whisperKitStorageStatus.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)

            if let message = storageErrorText {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button {
                    viewModel.openWhisperKitStorageLocation()
                } label: {
                    Label(openStorageButtonTitle, systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canOpenWhisperKitStorageLocation)

                Button {
                    Task { await viewModel.refreshWhisperKitModelInventory() }
                } label: {
                    Label("Refresh Cache", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isDeletingWhisperKitCachedModel)

                Button(role: .destructive) {
                    Task { await viewModel.deleteWhisperKitCachedModel() }
                } label: {
                    if viewModel.isDeletingWhisperKitCachedModel {
                        HStack(spacing: Spacing.xs) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Deleting")
                        }
                    } else {
                        Label("Delete Cache", systemImage: "trash")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canDeleteWhisperKitCachedModel)
            }

            if let err = viewModel.whisperKitModelManagementError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        }
        .task { await viewModel.refreshWhisperKitModelStatus() }
        .task { await viewModel.refreshWhisperKitModelInventory() }
        .task(id: viewModel.whisperKitModelStatus.isBusy) {
            await viewModel.pollWhisperKitModelStatusWhileBusy()
        }
        .onChange(of: viewModel.whisperKitModel) { _, _ in
            Task { await viewModel.refreshWhisperKitModelStatus() }
            Task { await viewModel.refreshWhisperKitModelInventory() }
        }
        .onChange(of: viewModel.whisperKitModelRepo) { _, _ in
            Task { await viewModel.refreshWhisperKitModelStatus() }
            Task { await viewModel.refreshWhisperKitModelInventory() }
        }
        .onChange(of: viewModel.whisperKitModelFolder) { _, _ in
            Task { await viewModel.refreshWhisperKitModelStatus() }
            Task { await viewModel.refreshWhisperKitModelInventory() }
        }
    }

    private var buttonTitle: String {
        switch viewModel.whisperKitModelStatus {
        case .error:
            return "Retry"
        case .idle, .downloading, .loading, .prewarming, .ready:
            return "Load Model"
        }
    }

    private var icon: String {
        switch viewModel.whisperKitModelStatus {
        case .idle:        return "arrow.down.circle"
        case .downloading: return "arrow.down.circle.dotted"
        case .loading:     return "memorychip"
        case .prewarming:  return "bolt.circle"
        case .ready:       return "checkmark.circle.fill"
        case .error:       return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch viewModel.whisperKitModelStatus {
        case .ready:
            return .green
        case .downloading, .loading, .prewarming:
            return .accentColor
        case .error:
            return .red
        case .idle:
            return .secondary
        }
    }

    private var statusText: String {
        switch viewModel.whisperKitModelStatus {
        case .idle:
            return "Model not loaded in this app session"
        case .downloading(let progress):
            return "Downloading model \(Int(progress * 100))%"
        case .loading:
            return "Loading model"
        case .prewarming:
            return "Prewarming and loading model"
        case .ready:
            return "Model loaded and ready"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    private var storageIcon: String {
        switch viewModel.whisperKitStorageStatus {
        case .localReady, .remoteCached:
            return "externaldrive.fill.badge.checkmark"
        case .localMissing:
            return "exclamationmark.triangle.fill"
        case .notCached:
            return "externaldrive.badge.questionmark"
        }
    }

    private var storageColor: Color {
        switch viewModel.whisperKitStorageStatus {
        case .localReady, .remoteCached:
            return .green
        case .localMissing:
            return .red
        case .notCached:
            return .secondary
        }
    }

    private var storageText: String {
        switch viewModel.whisperKitStorageStatus {
        case .localReady:
            return "Local model folder is ready"
        case .localMissing:
            return "Local model folder is invalid"
        case .remoteCached:
            return "Selected model is cached"
        case .notCached:
            return "Selected model is not cached"
        }
    }

    private var openStorageButtonTitle: String {
        switch viewModel.whisperKitStorageStatus {
        case .localReady, .localMissing:
            return "Open Folder"
        case .remoteCached, .notCached:
            return "Open Cache"
        }
    }

    private var storageErrorText: String? {
        if case .localMissing(_, let reason) = viewModel.whisperKitStorageStatus {
            return reason
        }
        return nil
    }
}
