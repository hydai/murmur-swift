#if os(iOS)
import SwiftUI
import UIKit
import MurmurKit

struct MobileRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    @State private var pipelineViewModel = PipelineViewModel()
    @State private var historyViewModel = HistoryViewModel()
    @State private var permissionsViewModel = MobilePermissionsViewModel()
    @State private var selectedSection: MobileSection = .record
    @State private var hasSavedCurrentResult = false

    var body: some View {
        Group {
            if usesSplitLayout {
                splitLayout
            } else {
                tabLayout
            }
        }
        .task {
            permissionsViewModel.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            permissionsViewModel.refresh()
        }
        .onChange(of: pipelineViewModel.pipelineState) { _, state in
            if state == .recording || state == .transcribing {
                hasSavedCurrentResult = false
            }
            guard state == .done else { return }
            saveCurrentResultToHistory()
        }
    }

    private var usesSplitLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    private var tabLayout: some View {
        TabView {
            NavigationStack {
                recordView
                    .navigationTitle("Record")
            }
            .tabItem {
                Label("Record", systemImage: "mic.fill")
            }

            NavigationStack {
                HistoryView(viewModel: historyViewModel)
                    .navigationTitle("History")
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }

            NavigationStack {
                SettingsPanel(
                    viewModel: SettingsViewModel(configManager: pipelineViewModel.configManager)
                )
                .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }

    private var splitLayout: some View {
        NavigationSplitView {
            List(MobileSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(selectedSection == section ? Color.accentColor : Color.primary)
            }
            .listStyle(.sidebar)
            .navigationTitle("Murmur")
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } detail: {
            NavigationStack {
                selectedContent
                    .navigationTitle(selectedSection.title)
            }
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .record:
            recordView
        case .history:
            HistoryView(viewModel: historyViewModel)
        case .settings:
            SettingsPanel(
                viewModel: SettingsViewModel(configManager: pipelineViewModel.configManager)
            )
        }
    }

    private var recordView: some View {
        VStack(spacing: 0) {
            MobilePermissionBanner(viewModel: permissionsViewModel)
            TranscriptionView(
                viewModel: pipelineViewModel,
                recordingGate: { await permissionsViewModel.prepareForRecording() }
            )
        }
    }

    private func saveCurrentResultToHistory() {
        let result = pipelineViewModel.finalResult
        guard !result.isEmpty, !hasSavedCurrentResult else { return }

        hasSavedCurrentResult = true
        let raw = pipelineViewModel.committedSegments.joined(separator: " ")
        let entry = HistoryEntry(
            rawText: raw,
            processedText: result,
            command: pipelineViewModel.detectedCommand,
            processingTimeMs: pipelineViewModel.processingTimeMs
        )

        Task {
            await historyViewModel.addEntry(entry)
        }
        MobileLatestTranscriptStore.save(result)
    }
}

private enum MobileSection: String, CaseIterable, Identifiable {
    case record
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .record: "Record"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .record: "mic.fill"
        case .history: "clock"
        case .settings: "gearshape"
        }
    }
}
#endif
