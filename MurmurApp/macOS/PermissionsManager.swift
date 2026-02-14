#if os(macOS)
@preconcurrency import AppKit
import AVFoundation

/// Checks and requests microphone and accessibility permissions.
@MainActor
final class PermissionsManager {
    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
    }

    // MARK: - Microphone

    var microphoneStatus: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    func requestMicrophoneAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    // MARK: - Accessibility (for keyboard output)

    var accessibilityStatus: PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    func promptAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Combined check

    /// Check all permissions and return issues if any.
    func checkPermissions() async -> [String] {
        var issues: [String] = []

        switch microphoneStatus {
        case .notDetermined:
            let granted = await requestMicrophoneAccess()
            if !granted {
                issues.append("Microphone access is required for voice recording.")
            }
        case .denied:
            issues.append("Microphone access denied. Open System Settings > Privacy & Security > Microphone to grant access.")
        case .granted:
            break
        }

        if accessibilityStatus == .denied {
            issues.append("Accessibility access is needed for keyboard output mode. Open System Settings > Privacy & Security > Accessibility.")
        }

        return issues
    }

    /// Show an alert with permission issues.
    func showPermissionAlert(issues: [String]) {
        let alert = NSAlert()
        alert.messageText = "Permissions Required"
        alert.informativeText = issues.joined(separator: "\n\n")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Continue Anyway")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
#endif
