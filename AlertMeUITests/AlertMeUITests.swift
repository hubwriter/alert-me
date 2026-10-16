import XCTest

final class AlertMeUITests: XCTestCase {
    @MainActor
    func testAboutDialogShowsReleaseVersionAndDate() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.windows["Alert Me"].waitForExistence(timeout: 3))
        app.menuBars.firstMatch.menuBarItems.element(boundBy: 1).click()
        app.menuItems["About Alert Me"].click()

        let version = app.staticTexts.matching(NSPredicate(
            format: "value CONTAINS %@ OR label CONTAINS %@", "1.1", "1.1"
        )).firstMatch
        XCTAssertTrue(version.waitForExistence(timeout: 2))
        let releaseDate = app.descendants(matching: .any).matching(NSPredicate(
            format: "value == %@ OR label == %@", "Released October 16, 2026", "Released October 16, 2026"
        )).firstMatch
        XCTAssertTrue(releaseDate.waitForExistence(timeout: 2))
    }

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
        app.activate()

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
        app.activate()

        app.buttons["createFirstAlertButton"].click()
        XCTAssertTrue(app.textFields["alertDateField"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["alertSelectedWeekday"].exists)
        XCTAssertFalse(app.radioButtons["noEndDateRadioButton"].exists)
        XCTAssertFalse(app.radioButtons["Weekdays"].exists)

        app.radioButtons["Daily"].click()
        XCTAssertFalse(app.textFields["alertDateField"].exists)
        XCTAssertTrue(app.textFields["alertTimeField"].exists)
        XCTAssertFalse(app.buttons["alertNowButton"].exists)
        XCTAssertTrue(app.radioButtons["noEndDateRadioButton"].exists)
        XCTAssertEqual(app.radioButtons["noEndDateRadioButton"].value as? Int, 1)
        XCTAssertFalse(app.textFields["alertEndDateField"].isEnabled)
        XCTAssertTrue(app.radioButtons["Weekdays"].exists)
        XCTAssertTrue(app.radioButtons["Every day"].exists)

        app.radioButtons["Weekly"].click()
        XCTAssertFalse(app.textFields["alertDateField"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["alertWeekdayPicker"].exists)
        XCTAssertTrue(app.textFields["alertTimeField"].exists)
        XCTAssertTrue(app.radioButtons["noEndDateRadioButton"].exists)
        XCTAssertFalse(app.radioButtons["Weekdays"].exists)
        XCTAssertFalse(app.radioButtons["Every day"].exists)

        app.radioButtons["Monthly"].click()
        XCTAssertTrue(app.textFields["alertDateField"].exists)
        XCTAssertFalse(app.staticTexts["alertSelectedWeekday"].exists)
        XCTAssertTrue(app.radioButtons["noEndDateRadioButton"].exists)
        XCTAssertFalse(app.radioButtons["Weekdays"].exists)

        app.radioButtons["Yearly"].click()
        XCTAssertTrue(app.textFields["alertDateField"].exists)
        XCTAssertFalse(app.staticTexts["alertSelectedWeekday"].exists)
        XCTAssertTrue(app.radioButtons["noEndDateRadioButton"].exists)
        XCTAssertFalse(app.radioButtons["Weekdays"].exists)
    }

    @MainActor
    func testRecurringEndDateCanBeEnabledSavedEditedAndRemoved() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.activate()

        app.buttons["createFirstAlertButton"].click()
        let editor = app.descendants(matching: .textView)["messageEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.click()
        editor.typeText("Monthly cutoff")
        app.radioButtons["Monthly"].click()
        replaceValue(in: app.textFields["alertDateField"], with: "10/06/2090")
        let endDateField = app.textFields["alertEndDateField"]
        XCTAssertFalse(endDateField.isEnabled)
        XCTAssertGreaterThan(app.staticTexts["Until:"].frame.minY, app.checkBoxes["soundToggle"].frame.maxY)
        XCTAssertLessThan(endDateField.frame.maxY, app.buttons["Cancel"].frame.minY)
        app.radioButtons["endDateRadioButton"].click()
        XCTAssertTrue(endDateField.isEnabled)
        XCTAssertEqual(app.radioButtons["noEndDateRadioButton"].value as? Int, 0)
        XCTAssertEqual(endDateField.value as? String, "10/06/2090")

        replaceValue(in: endDateField, with: "09/06/2090")
        XCTAssertEqual(endDateField.value as? String, "10/06/2090")
        app.steppers["alertEndDateStepper"].descendants(matching: .decrementArrow).firstMatch.click()
        XCTAssertEqual(endDateField.value as? String, "10/06/2090")
        replaceValue(in: endDateField, with: "30/06/2090")
        XCTAssertEqual(endDateField.value as? String, "30/06/2090")
        app.buttons["saveAlertButton"].click()

        let description = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@", "until 30 June 2090", "until 30 June 2090"
        ))
            .firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 2))
        app.buttons["Edit"].click()
        XCTAssertTrue(endDateField.waitForExistence(timeout: 2))
        XCTAssertEqual(app.radioButtons["endDateRadioButton"].value as? Int, 1)
        XCTAssertEqual(endDateField.value as? String, "30/06/2090")

        replaceValue(in: app.textFields["alertDateField"], with: "10/07/2090")
        XCTAssertEqual(endDateField.value as? String, "10/07/2090")
        app.radioButtons["noEndDateRadioButton"].click()
        XCTAssertFalse(endDateField.isEnabled)
        app.buttons["saveAlertButton"].click()
        XCTAssertTrue(app.staticTexts["Monthly cutoff"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@", "until ", "until "
        )).firstMatch.exists)
    }

    @MainActor
    func testCreatesAndEditsDailySchedule() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.activate()

        app.buttons["createFirstAlertButton"].click()
        let editor = app.descendants(matching: .textView)["messageEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.click()
        editor.typeText("Daily reminder")
        app.radioButtons["Daily"].click()

        let weekdays = app.radioButtons["Weekdays"]
        let everyDay = app.radioButtons["Every day"]
        XCTAssertTrue(weekdays.waitForExistence(timeout: 2))
        XCTAssertEqual(weekdays.value as? Int, 1)
        XCTAssertEqual(everyDay.value as? Int, 0)
        XCTAssertGreaterThan(weekdays.frame.minX, app.steppers["alertTimeStepper"].frame.maxX)
        XCTAssertGreaterThan(everyDay.frame.minX, weekdays.frame.maxX)
        XCTAssertEqual(weekdays.frame.midY, everyDay.frame.midY, accuracy: 2)
        XCTAssertEqual(weekdays.frame.midY, app.textFields["alertTimeField"].frame.midY, accuracy: 4)

        app.buttons["saveAlertButton"].click()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "value BEGINSWITH %@", "Weekdays at ")
        ).firstMatch.waitForExistence(timeout: 2))

        app.buttons["Edit"].click()
        XCTAssertTrue(weekdays.waitForExistence(timeout: 2))
        XCTAssertEqual(weekdays.value as? Int, 1)
        everyDay.click()
        XCTAssertEqual(weekdays.value as? Int, 0)
        XCTAssertEqual(everyDay.value as? Int, 1)
        app.buttons["saveAlertButton"].click()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "value BEGINSWITH %@", "Every day at ")
        ).firstMatch.waitForExistence(timeout: 2))

        app.buttons["Edit"].click()
        XCTAssertTrue(everyDay.waitForExistence(timeout: 2))
        XCTAssertEqual(everyDay.value as? Int, 1)
        weekdays.click()
        app.buttons["saveAlertButton"].click()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "value BEGINSWITH %@", "Weekdays at ")
        ).firstMatch.waitForExistence(timeout: 2))

        app.buttons["Edit"].click()
        XCTAssertTrue(weekdays.waitForExistence(timeout: 2))
        XCTAssertEqual(weekdays.value as? Int, 1)
        app.buttons["Cancel"].click()
    }

    @MainActor
    func testEditsDateAndTimeByTypingSteppersAndArrowKeys() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.activate()

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
