import SwiftUI
import MurmurKit

struct GeneralSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            PageHeader("General", subtitle: "Appearance and core preferences for the floating overlay.")

            SettingsCard {
                SectionHeader("Overlay")
                HStack {
                    Text("Opacity")
                    Spacer()
                    Text("\(Int(viewModel.opacity * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $viewModel.opacity, in: 0.3...1.0, step: 0.05)
                Toggle("Show waveform during recording", isOn: $viewModel.showWaveform)
            }

            SettingsCard {
                SectionHeader("Theme")
                Picker("Theme", selection: $viewModel.theme) {
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                    Text("System").tag("system")
                }
                .pickerStyle(.segmented)
            }

            if let error = viewModel.saveError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onChange(of: viewModel.opacity)       { _, _ in Task { await viewModel.saveConfig() } }
        .onChange(of: viewModel.showWaveform)  { _, _ in Task { await viewModel.saveConfig() } }
        .onChange(of: viewModel.theme)         { _, _ in Task { await viewModel.saveConfig() } }
    }
}
