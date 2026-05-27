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
        #if DEBUG
        if AppUITestSupport.isEnabled {
            NSApplication.shared.setActivationPolicy(.regular)
        } else {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        #else
        NSApplication.shared.setActivationPolicy(.accessory)
        #endif

        setupTray()
        installHotkeyCallback()
        observePipelineState()
        #if DEBUG
        if !AppUITestSupport.isEnabled {
            checkPermissions()
        }
        #else
        checkPermissions()
        #endif

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
            #if DEBUG
            if AppUITestSupport.isEnabled {
                await AppUITestSupport.prepare(configManager: viewModel.configManager)
            }
            #endif
            await applyRuntimePreferences()
            #if DEBUG
            if AppUITestSupport.shouldOpenSettings {
                openSettingsWindow(initialSelection: AppUITestSupport.initialSettingsSection)
                return
            }
            #endif
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

    private func openSettingsWindow(initialSelection: SettingsSection = .general) {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsPanel(
            viewModel: SettingsViewModel(configManager: viewModel.configManager),
            initialSelection: initialSelection
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

#if DEBUG
@MainActor
private enum AppUITestSupport {
    static var isEnabled: Bool {
        CommandLine.arguments.contains("--ui-testing")
    }

    static var shouldOpenSettings: Bool {
        CommandLine.arguments.contains("--ui-testing-open-settings")
    }

    static var initialSettingsSection: SettingsSection {
        CommandLine.arguments.contains("--ui-testing-settings-stt") ? .stt : .general
    }

    static func prepare(configManager: ConfigManager) async {
        if CommandLine.arguments.contains("--ui-testing-whisperkit-config")
            || CommandLine.arguments.contains("--ui-testing-seed-whisperkit-diagnostics") {
            try? await configManager.setConfig(whisperKitConfig())
        }

        if CommandLine.arguments.contains("--ui-testing-seed-whisperkit-diagnostics") {
            seedWhisperKitDiagnostics()
        }
    }

    private static func whisperKitConfig() -> AppConfig {
        var config = AppConfig()
        config.sttProvider = .whisperKit
        config.whisperKitSttConfig = WhisperKitSttConfig(
            model: "ui-test-tiny",
            modelRepo: "ui-test/repo",
            prewarm: false,
            realtimeIntervalMilliseconds: 500,
            realtimeMinimumSamples: 8_000,
            realtimeRequiredSegmentsForConfirmation: 1
        )
        return config
    }

    private static func seedWhisperKitDiagnostics() {
        let whisperConfig = whisperKitConfig().whisperKitSttConfig
        let key = WhisperKitRuntimeKey(config: whisperConfig)
        WhisperKitDiagnosticsStore.shared.reset()
        WhisperKitDiagnosticsStore.shared.record(.runtime(.loadFinished(key: key, durationMs: 222)))
        WhisperKitDiagnosticsStore.shared.record(.runtime(.cacheHit(key: key)))
        WhisperKitDiagnosticsStore.shared.record(.sessionStarted(
            model: whisperConfig.model,
            intervalMs: 500,
            minimumSamples: 8_000,
            requiredSegmentsForConfirmation: 1
        ))
        WhisperKitDiagnosticsStore.shared.record(.audioReceived(
            totalSamples: 16_000,
            chunkSamples: 4_000,
            timestampMs: 10
        ))
        WhisperKitDiagnosticsStore.shared.record(.realtimePassFinished(
            sampleCount: 16_000,
            segmentCount: 2,
            emittedEventCount: 1,
            durationMs: 111
        ))
        WhisperKitDiagnosticsStore.shared.record(.firstPartialLatency(durationMs: 321))
        WhisperKitDiagnosticsStore.shared.record(.sessionFinished(
            totalSamples: 16_000,
            partialEvents: 2,
            committedEvents: 3,
            errorEvents: 0
        ))
    }
}
#endif
#endif
