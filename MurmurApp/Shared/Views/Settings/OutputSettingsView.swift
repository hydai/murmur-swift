import SwiftUI
import MurmurKit
#if os(iOS)
import UIKit
#endif

struct OutputSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            PageHeader("Output", subtitle: "Where Murmur sends the final processed text.")

            SettingsCard {
                Picker("Output mode", selection: $viewModel.outputMode) {
                    ForEach(PlatformCapabilities.availableOutputModes, id: \.self) { mode in
                        Text(label(for: mode)).tag(mode)
                    }
                }
                .modifier(OutputPickerStyle())

                if !PlatformCapabilities.supportsKeyboardInjection {
                    StatusRow("Available actions", value: "Copy and Share")
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            #if os(iOS)
            MobileKeyboardExtensionSettingsCard()
            #endif

            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            if !PlatformCapabilities.availableOutputModes.contains(viewModel.outputMode) {
                viewModel.outputMode = .clipboard
            }
        }
        .onChange(of: viewModel.outputMode) { _, _ in Task { await viewModel.saveConfig() } }
    }

    private var description: String {
        if PlatformCapabilities.supportsKeyboardInjection {
            return "Clipboard copies the text to the system pasteboard. Keyboard simulation types the text into whichever app currently has focus and requires Accessibility permission."
        }
        return "On iOS and iPadOS, Murmur keeps automatic output on the clipboard and exposes share actions on completed transcripts."
    }

    private func label(for mode: OutputMode) -> String {
        switch mode {
        case .clipboard: return "Clipboard only"
        case .keyboard: return "Keyboard simulation"
        case .both: return "Both"
        }
    }
}

#if os(iOS)
private struct MobileKeyboardExtensionSettingsCard: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshot = MobileLatestTranscriptStore.snapshot()

    var body: some View {
        SettingsCard {
            SectionHeader("Keyboard Extension")
            StatusRow(
                "Shared container",
                value: snapshot.isSharedContainerAvailable ? "Available" : "Unavailable",
                color: snapshot.isSharedContainerAvailable ? .green : .red
            )
            StatusRow("Latest transcript", value: latestTranscriptStatus)

            Text("Enable Murmur in iOS Keyboard settings with Full Access. Recording stays in the app; the keyboard inserts the latest processed text.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    openAppSettings()
                } label: {
                    Label("Open App Settings", systemImage: "gearshape")
                }

                Button {
                    refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Spacer()
            }
            .buttonStyle(.borderless)
        }
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refresh()
        }
    }

    private var latestTranscriptStatus: String {
        guard snapshot.text != nil else { return "Not synced yet" }
        guard let updatedAt = snapshot.updatedAt else { return "Synced" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Synced \(formatter.localizedString(for: updatedAt, relativeTo: Date()))"
    }

    private func refresh() {
        snapshot = MobileLatestTranscriptStore.snapshot()
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
#endif

private struct OutputPickerStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.pickerStyle(.radioGroup)
        #else
        content.pickerStyle(.menu)
        #endif
    }
}
