import SwiftUI
import MurmurKit
#if canImport(UIKit)
import UIKit
#endif

struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            PageHeader("About", subtitle: "Murmur — privacy-first voice typing for Apple platforms.")

            SettingsCard {
                StatusRow("Version", value: appVersion)
                StatusRow("Build", value: buildNumber)
                StatusRow("Platform", value: "\(platformName) \(ProcessInfo.processInfo.operatingSystemVersionString)")
            }

            if PlatformCapabilities.supportsSparkleUpdates {
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

    private var platformName: String {
        #if os(macOS)
        "macOS"
        #elseif os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
        #else
        "Apple platform"
        #endif
    }
}
