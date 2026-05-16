import SwiftUI
import MurmurKit

struct PromptsSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            PageHeader(
                "Prompts",
                subtitle: "Customize the LLM templates Murmur sends for post-processing, shortening, tone change, translation, and reply generation."
            )

            SettingsCard {
                Picker("Template", selection: Binding(
                    get: { viewModel.selectedPrompt },
                    set: { viewModel.selectPrompt($0) }
                )) {
                    ForEach(PromptName.allCases, id: \.self) { name in
                        Text(label(for: name)).tag(name)
                    }
                }
                .pickerStyle(.menu)

                if !viewModel.selectedPrompt.requiredPlaceholders.isEmpty {
                    placeholderChips
                }
            }

            SettingsCard {
                SectionHeader("Edit template")
                TextEditor(text: $viewModel.draftPromptContent)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 320)
                    .border(Color.secondary.opacity(0.3))

                HStack {
                    if !viewModel.missingPlaceholders.isEmpty {
                        Text("Missing required placeholders: \(viewModel.missingPlaceholders.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if let err = viewModel.promptSaveError {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                    Spacer()
                    Button("Reset to Default") {
                        Task { await viewModel.resetPrompt() }
                    }
                    .disabled(!viewModel.promptSet.hasOverride(viewModel.selectedPrompt))

                    Button("Save Override") {
                        Task { await viewModel.savePrompt() }
                    }
                    .disabled(!viewModel.missingPlaceholders.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task { await viewModel.loadPrompts() }
    }

    private var placeholderChips: some View {
        HStack(spacing: Spacing.s) {
            Text("Required placeholders:")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(viewModel.selectedPrompt.requiredPlaceholders, id: \.self) { token in
                let missing = !viewModel.draftPromptContent.contains(token)
                Text(token)
                    .font(.caption.monospaced())
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.xs)
                    .background(missing ? Color.red.opacity(0.2) : Color.green.opacity(0.18))
                    .clipShape(Capsule())
            }
        }
    }

    private func label(for name: PromptName) -> String {
        let title: String = {
            switch name {
            case .postProcess:   return "Post-Process"
            case .shorten:       return "Shorten"
            case .changeTone:    return "Change Tone"
            case .generateReply: return "Generate Reply"
            case .translate:     return "Translate"
            }
        }()
        return viewModel.promptSet.hasOverride(name) ? "\(title) ●" : title
    }
}
