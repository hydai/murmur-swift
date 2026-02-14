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

        trayManager.onOpenSettings = {
            // Phase 4: Settings window
        }

        trayManager.onOpenHistory = {
            // Phase 4: History window
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
}
#endif
