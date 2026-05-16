import SwiftUI
import MurmurKit

struct OutputSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            PageHeader("Output", subtitle: "Where Murmur sends the final processed text.")

            SettingsCard {
                Picker("Output mode", selection: $viewModel.outputMode) {
                    Text("Clipboard only").tag(OutputMode.clipboard)
                    Text("Keyboard simulation").tag(OutputMode.keyboard)
                    Text("Both").tag(OutputMode.both)
                }
                .pickerStyle(.radioGroup)

                Text("""
                Clipboard copies the text to the system pasteboard. Keyboard simulation types the text into whichever app currently has focus and requires Accessibility permission.
                """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onChange(of: viewModel.outputMode) { _, _ in Task { await viewModel.saveConfig() } }
    }
}
