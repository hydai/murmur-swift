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
        for _ in 0..<8 where !panel.exists {
            scrollView.swipeUp()
        }

        XCTAssertTrue(panel.waitForExistence(timeout: 2))
    }

}
