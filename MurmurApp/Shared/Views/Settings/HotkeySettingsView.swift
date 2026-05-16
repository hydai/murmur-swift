import SwiftUI
import MurmurKit

struct HotkeySettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            PageHeader("Hotkey", subtitle: "Global shortcut that toggles recording.")

            SettingsCard {
                #if os(macOS)
                HotkeyCaptureField(hotkeyString: $viewModel.hotkey)
                #else
                TextField("Hotkey", text: $viewModel.hotkey)
                    .textFieldStyle(.roundedBorder)
                #endif

                Text("Default: Ctrl+`. Click the field above and press your desired key combination. At least one modifier (Ctrl, Cmd, Alt, or Shift) is required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onChange(of: viewModel.hotkey) { _, _ in Task { await viewModel.saveConfig() } }
    }
}
