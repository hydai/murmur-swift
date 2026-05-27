#if os(iOS)
import AVFoundation
import Speech
import SwiftUI
import UIKit

@MainActor
@Observable
final class MobilePermissionsViewModel {
    enum PermissionState: Equatable {
        case notDetermined
        case authorized
        case denied
        case restricted
        case unknown

        var isAuthorized: Bool {
            self == .authorized
        }

        var needsRequest: Bool {
            self == .notDetermined
        }

        var isBlocked: Bool {
            switch self {
            case .denied, .restricted, .unknown:
                true
            case .notDetermined, .authorized:
                false
            }
        }

        var label: String {
            switch self {
            case .notDetermined: "Not Asked"
            case .authorized: "Allowed"
            case .denied: "Denied"
            case .restricted: "Restricted"
            case .unknown: "Unknown"
            }
        }

        var color: Color {
            switch self {
            case .authorized: .green
            case .notDetermined: .orange
            case .denied, .restricted, .unknown: .red
            }
        }

        init(_ status: AVAuthorizationStatus) {
            switch status {
            case .notDetermined:
                self = .notDetermined
            case .authorized:
                self = .authorized
            case .denied:
                self = .denied
            case .restricted:
                self = .restricted
            @unknown default:
                self = .unknown
            }
        }

        init(_ status: SFSpeechRecognizerAuthorizationStatus) {
            switch status {
            case .notDetermined:
                self = .notDetermined
            case .authorized:
                self = .authorized
            case .denied:
                self = .denied
            case .restricted:
                self = .restricted
            @unknown default:
                self = .unknown
            }
        }
    }

    var microphone: PermissionState = .notDetermined
    var speechRecognition: PermissionState = .notDetermined
    var errorMessage: String?

    var isReady: Bool {
        microphone.isAuthorized && speechRecognition.isAuthorized
    }

    var shouldShowBanner: Bool {
        !isReady
    }

    var hasBlockedPermission: Bool {
        microphone.isBlocked || speechRecognition.isBlocked
    }

    var requiredPermissionNames: String {
        var names: [String] = []
        if !microphone.isAuthorized { names.append("Microphone") }
        if !speechRecognition.isAuthorized { names.append("Speech Recognition") }
        return names.joined(separator: " and ")
    }

    init() {
        refresh()
    }

    func refresh() {
        microphone = PermissionState(AVCaptureDevice.authorizationStatus(for: .audio))
        speechRecognition = PermissionState(SFSpeechRecognizer.authorizationStatus())
    }

    @discardableResult
    func prepareForRecording() async -> Bool {
        await requestMissingPermissions()
        refresh()

        guard isReady else {
            if hasBlockedPermission {
                errorMessage = "\(requiredPermissionNames) access is blocked. Update permissions in Settings."
            } else {
                errorMessage = "\(requiredPermissionNames) access is required before recording."
            }
            return false
        }

        errorMessage = nil
        return true
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func requestMissingPermissions() async {
        if microphone.needsRequest {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }

        if speechRecognition.needsRequest {
            _ = await requestSpeechRecognitionAuthorization()
        }
    }

    private func requestSpeechRecognitionAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

struct MobilePermissionBanner: View {
    @Bindable var viewModel: MobilePermissionsViewModel

    var body: some View {
        if viewModel.shouldShowBanner {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: viewModel.hasBlockedPermission ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                        .foregroundStyle(viewModel.hasBlockedPermission ? .red : .orange)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.hasBlockedPermission ? "Permission Blocked" : "Permissions Required")
                            .font(.headline)
                        Text(viewModel.hasBlockedPermission ? "Enable access in Settings before recording." : "Allow access before recording.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                VStack(spacing: 6) {
                    permissionRow("Microphone", state: viewModel.microphone)
                    permissionRow("Speech Recognition", state: viewModel.speechRecognition)
                }

                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    if viewModel.hasBlockedPermission {
                        Button {
                            viewModel.openSystemSettings()
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } else {
                        Button {
                            Task { await viewModel.prepareForRecording() }
                        } label: {
                            Label("Allow Access", systemImage: "checkmark.circle")
                        }
                    }

                    Spacer()
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.top)
        }
    }

    private func permissionRow(_ title: String, state: MobilePermissionsViewModel.PermissionState) -> some View {
        HStack {
            Text(title)
                .font(.caption)
            Spacer()
            Text(state.label)
                .font(.caption)
                .foregroundStyle(state.color)
        }
    }
}
#endif
