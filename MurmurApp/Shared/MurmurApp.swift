import SwiftUI
import MurmurKit

@main
struct MurmurApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            TranscriptionView()
        }
        .defaultSize(width: 500, height: 400)
    }
}

#if os(macOS)
/// App delegate that manages the system tray, global hotkey, and overlay.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let viewModel = PipelineViewModel()
    private let trayManager = SystemTrayManager()
    private let hotkeyManager = GlobalHotkeyManager()
    private let overlayWindow = OverlayWindow()
    private let soundManager = SoundManager.shared
    private let historyViewModel = HistoryViewModel()
    private var settingsWindow: NSWindow?
    private var historyWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory app (no dock icon, tray only)
        NSApplication.shared.setActivationPolicy(.accessory)

        setupTray()
        setupHotkey()
        observePipelineState()
    }

    private func setupTray() {
        trayManager.setup()

        trayManager.onToggleRecording = { [weak self] in
            await self?.toggleRecording()
        }

        trayManager.onOpenSettings = { [weak self] in
            self?.openSettingsWindow()
        }

        trayManager.onOpenHistory = { [weak self] in
            self?.openHistoryWindow()
        }

        trayManager.onQuit = {
            NSApplication.shared.terminate(nil)
        }
    }

    private func setupHotkey() {
        hotkeyManager.onHotkeyPressed = { [weak self] in
            Task { @MainActor in
                await self?.toggleRecording()
            }
        }
        hotkeyManager.start()
    }

    private func toggleRecording() async {
        if viewModel.isRecording {
            soundManager.playStopSound()
            await viewModel.stopRecording()
        } else {
            soundManager.playStartSound()
            overlayWindow.show(OverlayView(viewModel: viewModel))
            await viewModel.startRecording()
        }
    }

    private func observePipelineState() {
        // Watch for state changes to update tray and overlay
        Task { [weak self] in
            var previousState: PipelineState = .idle
            while !Task.isCancelled {
                guard let self else { break }
                let state = viewModel.pipelineState

                if state != previousState {
                    previousState = state
                    trayManager.updateRecordingState(isRecording: viewModel.isRecording)

                    switch state {
                    case .done:
                        soundManager.playDoneSound()
                        // Save to history
                        self.saveToHistory()
                        // Hide overlay after a brief delay
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            self.overlayWindow.hide()
                        }
                    case .error:
                        soundManager.playErrorSound()
                    default:
                        break
                    }
                }

                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func saveToHistory() {
        let result = viewModel.finalResult
        let raw = viewModel.committedSegments.joined(separator: " ")
        guard !result.isEmpty else { return }

        let entry = HistoryEntry(
            rawText: raw,
            processedText: result,
            command: viewModel.detectedCommand,
            processingTimeMs: viewModel.processingTimeMs
        )
        Task { await historyViewModel.addEntry(entry) }
    }

    private func openSettingsWindow() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsPanel(
            viewModel: SettingsViewModel(configManager: viewModel.configManager)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Murmur Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    private func openHistoryWindow() {
        if let window = historyWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let historyView = HistoryView(viewModel: historyViewModel)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Murmur History"
        window.contentView = NSHostingView(rootView: historyView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        historyWindow = window
    }
}
#endif
