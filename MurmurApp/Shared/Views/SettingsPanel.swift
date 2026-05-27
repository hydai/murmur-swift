import SwiftUI
import MurmurKit

/// Settings shell. Uses `NavigationSplitView` with a fixed sidebar listing
/// every section so we match the Rust v0.2.11 layout.
struct SettingsPanel: View {
    @State var viewModel: SettingsViewModel
    @State private var selection: SettingsSection

    init(
        viewModel: SettingsViewModel,
        initialSelection: SettingsSection = .general
    ) {
        _viewModel = State(initialValue: viewModel)
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            detail
                .background(Color.settingsBackground)
        }
        .navigationSplitViewStyle(.balanced)
        .modifier(SettingsPanelSizing())
        .task { await viewModel.loadConfig() }
    }

    private var sidebar: some View {
        #if os(macOS)
        List(SettingsSection.allCases, id: \.self, selection: $selection) { section in
            Label(section.title, systemImage: section.systemImage)
                .tag(section)
                .accessibilityIdentifier(section.accessibilityIdentifier)
        }
        .listStyle(.sidebar)
        .navigationTitle("Murmur")
        #else
        List(SettingsSection.allCases, id: \.self) { section in
            Button {
                selection = section
            } label: {
                Label(section.title, systemImage: section.systemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(selection == section ? Color.accentColor : Color.primary)
            .accessibilityIdentifier(section.accessibilityIdentifier)
        }
        .listStyle(.sidebar)
        .navigationTitle("Murmur")
        #endif
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general:    GeneralSettingsView(viewModel: viewModel)
        case .stt:        ProviderSettingsView(viewModel: viewModel)
        case .llm:        LlmSettingsView(viewModel: viewModel)
        case .output:     OutputSettingsView(viewModel: viewModel)
        case .hotkey:     HotkeySettingsView(viewModel: viewModel)
        case .dictionary: DictionarySettingsView(viewModel: viewModel)
        case .prompts:    PromptsSettingsView(viewModel: viewModel)
        case .about:      AboutSettingsView()
        }
    }
}

private struct SettingsPanelSizing: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.frame(minWidth: 720, idealWidth: 760, minHeight: 560, idealHeight: 600)
        #else
        content
        #endif
    }
}

/// The 8 settings sections shown in the sidebar.
enum SettingsSection: CaseIterable, Hashable {
    case general, stt, llm, output, hotkey, dictionary, prompts, about

    var title: String {
        switch self {
        case .general:    return "General"
        case .stt:        return "Speech-to-Text"
        case .llm:        return "LLM Processor"
        case .output:     return "Output"
        case .hotkey:     return "Hotkey"
        case .dictionary: return "Dictionary"
        case .prompts:    return "Prompts"
        case .about:      return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general:    return "gearshape"
        case .stt:        return "mic"
        case .llm:        return "cpu"
        case .output:     return "keyboard"
        case .hotkey:     return "command"
        case .dictionary: return "book.closed"
        case .prompts:    return "text.alignleft"
        case .about:      return "info.circle"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .general:    return "settings-section-general"
        case .stt:        return "settings-section-stt"
        case .llm:        return "settings-section-llm"
        case .output:     return "settings-section-output"
        case .hotkey:     return "settings-section-hotkey"
        case .dictionary: return "settings-section-dictionary"
        case .prompts:    return "settings-section-prompts"
        case .about:      return "settings-section-about"
        }
    }
}
