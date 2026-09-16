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
    func testRepeatedOpenCommandsReuseMainWindow() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.windows["Alert Me"].waitForExistence(timeout: 3))

        app.typeKey("n", modifierFlags: .command)
        app.typeKey("n", modifierFlags: .command)

        XCTAssertEqual(app.windows.matching(identifier: "Alert Me").count, 1)
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
    func testEditsDateAndTimeByTypingSteppersAndArrowKeys() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        app.buttons["createFirstAlertButton"].click()
        let dateField = app.textFields["alertDateField"]
        let timeField = app.textFields["alertTimeField"]
        XCTAssertTrue(dateField.waitForExistence(timeout: 2))
        XCTAssertTrue(timeField.waitForExistence(timeout: 2))

        replaceValue(in: dateField, with: "20/09/2026")
        replaceValue(in: timeField, with: "14:30")
        XCTAssertEqual(dateField.value as? String, "20/09/2026")
        XCTAssertEqual(timeField.value as? String, "14:30")

        let dateIncrement = app.steppers["alertDateStepper"]
            .descendants(matching: .incrementArrow)
            .firstMatch
        let timeDecrement = app.steppers["alertTimeStepper"]
            .descendants(matching: .decrementArrow)
            .firstMatch
        XCTAssertTrue(dateIncrement.waitForExistence(timeout: 2))
        XCTAssertTrue(timeDecrement.waitForExistence(timeout: 2))
        dateIncrement.click()
        timeDecrement.click()
        XCTAssertEqual(dateField.value as? String, "21/09/2026")
        XCTAssertEqual(timeField.value as? String, "14:29")

        dateField.click()
        dateField.typeKey("a", modifierFlags: .command)
        dateField.typeKey(.leftArrow, modifierFlags: [])
        dateField.typeKey(.downArrow, modifierFlags: [])

        timeField.click()
        timeField.typeKey("a", modifierFlags: .command)
        timeField.typeKey(.rightArrow, modifierFlags: [])
        timeField.typeKey(.upArrow, modifierFlags: [])

        XCTAssertEqual(dateField.value as? String, "20/09/2026")
        XCTAssertEqual(timeField.value as? String, "14:30")
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

    @MainActor
    private func replaceValue(in field: XCUIElement, with value: String) {
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(value)
        field.typeKey(.tab, modifierFlags: [])
    }

}
