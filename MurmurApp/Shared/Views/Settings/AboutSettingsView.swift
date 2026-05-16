import SwiftUI
import MurmurKit

struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            PageHeader("About", subtitle: "Murmur — privacy-first voice typing for macOS.")

            SettingsCard {
                StatusRow("Version", value: appVersion)
                StatusRow("Build", value: buildNumber)
                StatusRow("Platform", value: "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
            }

            SettingsCard {
                SectionHeader("Updates")
                Text("Auto-update is integrated via Sparkle. Use the Murmur menu in the system tray or the button below to check now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Check for Updates") {
                        NotificationCenter.default.post(name: .murmurCheckForUpdates, object: nil)
                    }
                    Spacer()
                }
            }

            SettingsCard {
                SectionHeader("Links")
                Link("Project repository", destination: URL(string: "https://github.com/hydai/murmur-swift")!)
                Link("Report an issue", destination: URL(string: "https://github.com/hydai/murmur-swift/issues")!)
            }

            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
