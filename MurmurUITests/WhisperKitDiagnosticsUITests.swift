import XCTest

final class WhisperKitDiagnosticsUITests: XCTestCase {
    private var temporaryConfigDirectory: URL?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        if let temporaryConfigDirectory {
            try? FileManager.default.removeItem(at: temporaryConfigDirectory)
        }
        temporaryConfigDirectory = nil
    }

    @MainActor
    func testDiagnosticsPanelDisplaysSeededMetricsAndCanReset() throws {
        let app = XCUIApplication()
        let configDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MurmurUITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        temporaryConfigDirectory = configDirectory

        app.launchEnvironment["MURMUR_CONFIG_DIR"] = configDirectory.path
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-open-settings",
            "--ui-testing-settings-stt",
            "--ui-testing-seed-whisperkit-diagnostics"
        ]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.windows["Murmur Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["whisperkit-custom-model-field"].waitForExistence(timeout: 10))
        revealDiagnosticsPanel(in: app)

        assertStaticText("whisperkit-diagnostics-title", equals: "Latest WhisperKit diagnostics", in: app)
        assertValue("model", equals: "ui-test-tiny", in: app)
        assertValue("source", equals: "Model cache", in: app)
        assertValue("audio", equals: "16000 samples (1.0 s)", in: app)
        assertValue("first-partial", equals: "321 ms", in: app)
        assertValue("realtime-pass", equals: "111 ms, 2 segments", in: app)
        assertValue("load", equals: "222 ms", in: app)
        assertValue("cache-hits", equals: "1", in: app)
        assertValue("events", equals: "3 committed, 2 partial", in: app)

        app.buttons["whisperkit-diagnostics-reset"].click()

        assertStaticText("whisperkit-diagnostics-title", equals: "No diagnostics captured", in: app, timeout: 5)
        assertValue("model", equals: "No model yet", in: app, timeout: 5)
        assertValue("source", equals: "No source yet", in: app, timeout: 5)
        assertValue("events", equals: "0 committed, 0 partial", in: app, timeout: 5)
    }

    @MainActor
    private func assertStaticText(
        _ identifier: String,
        equals expectedValue: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.staticTexts[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing static text: \(identifier)", file: file, line: line)
        XCTAssertTrue(
            waitForValue(expectedValue, in: element, timeout: timeout),
            "Expected \(identifier) value to be \(expectedValue), got \(String(describing: element.value))",
            file: file,
            line: line
        )
    }

    @MainActor
    private func assertValue(
        _ identifier: String,
        equals expectedValue: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let value = app.staticTexts["whisperkit-diagnostics-\(identifier)-value"]
        XCTAssertTrue(value.waitForExistence(timeout: timeout), "Missing diagnostics value: \(identifier)", file: file, line: line)
        XCTAssertTrue(
            waitForValue(expectedValue, in: value, timeout: timeout),
            "Expected \(identifier) value to be \(expectedValue), got \(String(describing: value.value))",
            file: file,
            line: line
        )
    }

    @MainActor
    private func waitForValue(_ expectedValue: String, in element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.value as? String == expectedValue {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return element.value as? String == expectedValue
    }

    @MainActor
    private func revealDiagnosticsPanel(in app: XCUIApplication) {
        let panel = app.descendants(matching: .any)["whisperkit-diagnostics-panel"]
        if panel.waitForExistence(timeout: 2) {
            return
        }

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Missing settings scroll view")
        for _ in 0..<8 {
            if panel.waitForExistence(timeout: 0.5) {
                return
            }
            scrollView.swipeUp()
        }

        XCTAssertTrue(panel.waitForExistence(timeout: 2))
    }

}

final class WhisperKitModelManagementUITests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories = []
    }

    @MainActor
    func testModelManagementDisplaysLocalFolderAndCacheFallback() throws {
        let configDirectory = try makeTemporaryDirectory(named: "MurmurModelUITests-config")
        let modelFolder = try makeTemporaryDirectory(named: "MurmurModelUITests-model")
        try makeModelComponents(in: modelFolder)

        let app = launchWhisperKitSettingsApp(
            configDirectory: configDirectory,
            modelFolder: modelFolder.path
        )
        defer { app.terminate() }

        XCTAssertTrue(app.windows["Murmur Settings"].waitForExistence(timeout: 10))

        assertTextField("whisperkit-custom-model-field", equals: "ui-test-local-model", in: app, timeout: 10)
        assertTextField("whisperkit-model-repo-field", equals: "ui-test/repo", in: app)
        assertTextField("whisperkit-model-folder-field", equals: modelFolder.path, in: app)

        revealModelManagementPanel(in: app)

        assertStaticText("whisperkit-model-status-value", equals: "Model not loaded in this app session", in: app)
        assertStaticText("whisperkit-model-storage-value", equals: "Local model folder is ready", in: app)
        assertStaticText("whisperkit-model-storage-path-value", equals: modelFolder.path, in: app)
        assertStaticTextDoesNotEqual("whisperkit-model-cache-size-value", "Not cached", in: app)
        XCTAssertFalse(app.buttons["whisperkit-model-delete-cache"].isEnabled)
        XCTAssertTrue(app.buttons["whisperkit-model-open-storage"].isEnabled)
        XCTAssertTrue(app.buttons["whisperkit-model-load-button"].isEnabled)
        XCTAssertTrue(app.buttons["whisperkit-model-use-cache"].isEnabled)

        app.terminate()

        let fallbackConfigDirectory = try makeTemporaryDirectory(named: "MurmurModelUITests-cache-config")
        let fallbackApp = launchWhisperKitSettingsApp(
            configDirectory: fallbackConfigDirectory,
            modelFolder: ""
        )
        defer { fallbackApp.terminate() }

        XCTAssertTrue(fallbackApp.windows["Murmur Settings"].waitForExistence(timeout: 10))

        assertTextField("whisperkit-custom-model-field", equals: "ui-test-local-model", in: fallbackApp, timeout: 10)
        assertTextField("whisperkit-model-repo-field", equals: "ui-test/repo", in: fallbackApp)
        revealModelManagementPanel(in: fallbackApp)

        assertStaticText(
            "whisperkit-model-status-value",
            equals: "Model not loaded in this app session",
            in: fallbackApp
        )
        assertStaticText(
            "whisperkit-model-storage-value",
            equals: "Selected model is not cached",
            in: fallbackApp,
            timeout: 5
        )
        assertStaticText("whisperkit-model-cache-size-value", equals: "Not cached", in: fallbackApp, timeout: 5)
        XCTAssertTrue(waitForButtonDisabled("whisperkit-model-use-cache", in: fallbackApp, timeout: 5))
        XCTAssertTrue(waitForButtonDisabled("whisperkit-model-delete-cache", in: fallbackApp, timeout: 5))
        XCTAssertTrue(fallbackApp.buttons["whisperkit-model-open-storage"].isEnabled)
    }

    private func launchWhisperKitSettingsApp(configDirectory: URL, modelFolder: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MURMUR_CONFIG_DIR"] = configDirectory.path
        app.launchEnvironment["MURMUR_UI_TEST_WHISPERKIT_MODEL"] = "ui-test-local-model"
        app.launchEnvironment["MURMUR_UI_TEST_WHISPERKIT_MODEL_REPO"] = "ui-test/repo"
        if !modelFolder.isEmpty {
            app.launchEnvironment["MURMUR_UI_TEST_WHISPERKIT_MODEL_FOLDER"] = modelFolder
        }
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-open-settings",
            "--ui-testing-settings-stt",
            "--ui-testing-whisperkit-model-management"
        ]
        app.launch()
        return app
    }

    private func makeTemporaryDirectory(named prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        return directory
    }

    private func makeModelComponents(in folder: URL) throws {
        for name in ["MelSpectrogram.mlmodelc", "AudioEncoder.mlmodelc", "TextDecoder.mlmodelc"] {
            let component = folder.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: component, withIntermediateDirectories: true)
            try Data([0, 1, 2, 3]).write(to: component.appendingPathComponent("weights.bin"))
        }
    }

    @MainActor
    private func assertTextField(
        _ identifier: String,
        equals expectedValue: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: timeout), "Missing text field: \(identifier)", file: file, line: line)
        XCTAssertTrue(
            waitForTextFieldValue(expectedValue, in: field, timeout: timeout),
            "Expected \(identifier) value to be \(expectedValue), got \(String(describing: field.value))",
            file: file,
            line: line
        )
    }

    @MainActor
    private func assertStaticText(
        _ identifier: String,
        equals expectedValue: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.staticTexts[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing static text: \(identifier)", file: file, line: line)
        XCTAssertTrue(
            waitForElementString(expectedValue, in: element, timeout: timeout),
            "Expected \(identifier) to be \(expectedValue), got value \(String(describing: element.value)) label \(element.label)",
            file: file,
            line: line
        )
    }

    @MainActor
    private func assertStaticTextDoesNotEqual(
        _ identifier: String,
        _ unexpectedValue: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.staticTexts[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing static text: \(identifier)", file: file, line: line)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if elementString(element) != unexpectedValue {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertNotEqual(elementString(element), unexpectedValue, file: file, line: line)
    }

    @MainActor
    private func waitForTextFieldValue(_ expectedValue: String, in element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (element.value as? String) == expectedValue {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return (element.value as? String) == expectedValue
    }

    @MainActor
    private func waitForElementString(_ expectedValue: String, in element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if elementString(element) == expectedValue {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return elementString(element) == expectedValue
    }

    @MainActor
    private func waitForButtonDisabled(_ identifier: String, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let button = app.buttons[identifier]
        guard button.waitForExistence(timeout: timeout) else { return false }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !button.isEnabled {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return !button.isEnabled
    }

    @MainActor
    private func elementString(_ element: XCUIElement) -> String? {
        if let value = element.value as? String, !value.isEmpty {
            return value
        }
        if !element.label.isEmpty {
            return element.label
        }
        return element.value as? String
    }

    @MainActor
    private func revealModelManagementPanel(in app: XCUIApplication) {
        let panel = app.descendants(matching: .any)["whisperkit-model-management-panel"]
        if panel.waitForExistence(timeout: 2) {
            return
        }

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Missing settings scroll view")
        for _ in 0..<8 {
            if panel.waitForExistence(timeout: 0.5) {
                return
            }
            scrollView.swipeUp()
        }

        XCTAssertTrue(panel.waitForExistence(timeout: 2))
    }
}
