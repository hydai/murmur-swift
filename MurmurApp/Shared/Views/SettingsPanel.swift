import SwiftUI
import MurmurKit

/// Settings shell. Uses `NavigationSplitView` with a fixed sidebar listing
/// every section so we match the Rust v0.2.11 layout.
struct SettingsPanel: View {
    @State var viewModel: SettingsViewModel
    @State private var selection: SettingsSection = .general

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            detail
                .background(Color.settingsBackground)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 720, idealWidth: 760, minHeight: 560, idealHeight: 600)
        .task { await viewModel.loadConfig() }
    }

    private var sidebar: some View {
        List(SettingsSection.allCases, id: \.self, selection: $selection) { section in
            Label(section.title, systemImage: section.systemImage)
                .tag(section)
        }
        .listStyle(.sidebar)
        .navigationTitle("Murmur")
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
}
