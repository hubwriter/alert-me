import XCTest

final class AlertMeUITests: XCTestCase {
    @MainActor
    func testEmptyStateAppears() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.staticTexts["No alerts"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCreatesAndDeletesOneTimeAlert() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        app.buttons["createFirstAlertButton"].click()
        let editor = app.descendants(matching: .textView)["messageEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["alertDateField"].exists)
        XCTAssertTrue(app.textFields["alertTimeField"].exists)
        XCTAssertTrue(app.buttons["alertNowButton"].exists)
        editor.click()
        editor.typeText("Dentist appointment")
        app.buttons["saveAlertButton"].click()

        XCTAssertTrue(app.staticTexts["Dentist appointment"].waitForExistence(timeout: 2))
        app.buttons["Delete"].click()
        XCTAssertTrue(app.staticTexts["No alerts"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testRecurrenceSpecificDateControls() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        app.buttons["createFirstAlertButton"].click()
        XCTAssertTrue(app.textFields["alertDateField"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["alertSelectedWeekday"].exists)

        app.radioButtons["Daily"].click()
        XCTAssertFalse(app.textFields["alertDateField"].exists)
        XCTAssertTrue(app.textFields["alertTimeField"].exists)
        XCTAssertFalse(app.buttons["alertNowButton"].exists)

        app.radioButtons["Weekly"].click()
        XCTAssertFalse(app.textFields["alertDateField"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["alertWeekdayPicker"].exists)
        XCTAssertTrue(app.textFields["alertTimeField"].exists)

        app.radioButtons["Monthly"].click()
        XCTAssertTrue(app.textFields["alertDateField"].exists)
        XCTAssertFalse(app.staticTexts["alertSelectedWeekday"].exists)

        app.radioButtons["Yearly"].click()
        XCTAssertTrue(app.textFields["alertDateField"].exists)
        XCTAssertFalse(app.staticTexts["alertSelectedWeekday"].exists)
    }

    @MainActor
    func testCapturesReadmeScreenshot() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let marker = repositoryRoot.appendingPathComponent(
            ".build/capture-readme-screenshot"
        )
        guard FileManager.default.fileExists(atPath: marker.path) else {
            throw XCTSkip("README screenshot generation is opt-in.")
        }

        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        app.buttons["createFirstAlertButton"].click()
        let editor = app.descendants(matching: .textView)["messageEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.click()
        editor.typeText("Dentist appointment")
        app.buttons["saveAlertButton"].click()
        XCTAssertTrue(app.staticTexts["Dentist appointment"].waitForExistence(timeout: 2))

        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "alert-me-main-window"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
