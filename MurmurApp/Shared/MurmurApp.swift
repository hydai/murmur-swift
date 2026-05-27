import SwiftUI
import MurmurKit

@main
struct MurmurApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @SceneBuilder
    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            TranscriptionView()
        }
        .defaultSize(width: 500, height: 400)
        #else
        WindowGroup {
            MobileRootView()
        }
        #endif
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
    private let permissionsManager = PermissionsManager()
    private let updateManager = UpdateManager()
    private var settingsWindow: NSWindow?
    private var historyWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory app (no dock icon, tray only)
        NSApplication.shared.setActivationPolicy(.accessory)

        setupTray()
        installHotkeyCallback()
        observePipelineState()
        checkPermissions()

        // AppDelegate lives for the app's lifetime; the observer is torn
        // down at process exit, so we don't store/remove it (deinit can't
        // access MainActor state under Swift 6 strict concurrency).
        _ = NotificationCenter.default.addObserver(
            forName: .murmurConfigDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.applyRuntimePreferences()
            }
        }

        // Load config, then apply runtime-driven prefs (hotkey, opacity, theme).
        Task { @MainActor in
            try? await viewModel.configManager.load()
            await applyRuntimePreferences()
            openSettingsOnFirstLaunch()
        }
    }

    /// Open the Settings window the first time the app is launched on this
    /// machine so the user can configure providers/keys. Matches the Rust
    /// v0.1.4 commit 0fa8a62 behavior.
    private static let firstLaunchKey = "com.hydai.Murmur.didShowFirstLaunchSettings"

    private func openSettingsOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.firstLaunchKey) else { return }
        defaults.set(true, forKey: Self.firstLaunchKey)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            openSettingsWindow()
        }
    }

    /// Read the current config and apply runtime-driven prefs: hotkey,
    /// overlay opacity, theme, plus the pipeline orchestrator's hot-swappable
    /// LLM processor + output mode + dictionary terms. Called at launch and
    /// on every `.murmurConfigDidChange`.
    private func applyRuntimePreferences() async {
        let config = await viewModel.configManager.getConfig()
        let spec = HotkeySpec.parse(config.hotkey) ?? GlobalHotkeyManager.defaultSpec
        hotkeyManager.reregister(spec: spec)
        overlayWindow.setOpacity(CGFloat(config.uiPreferences.opacity))
        ThemeApplier.apply(config.uiPreferences.theme)
        await viewModel.updateRuntimeConfig()
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

        trayManager.onCheckForUpdates = { [weak self] in
            self?.updateManager.checkForUpdates()
        }

        trayManager.onQuit = {
            NSApplication.shared.terminate(nil)
        }
    }

    /// Install the hotkey callback only. The spec is applied later by
    /// `applyRuntimePreferences` once the config is loaded.
    private func installHotkeyCallback() {
        hotkeyManager.onHotkeyPressed = { [weak self] in
            Task { @MainActor in
                await self?.toggleRecording()
            }
        }
        hotkeyManager.start(spec: GlobalHotkeyManager.defaultSpec)
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

    private func checkPermissions() {
        Task {
            let issues = await permissionsManager.checkPermissions()
            if !issues.isEmpty {
                permissionsManager.showPermissionAlert(issues: issues)
            }
        }
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
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
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
