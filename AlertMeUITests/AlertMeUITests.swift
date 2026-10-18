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
            format: "value CONTAINS %@ OR label CONTAINS %@", "1.4", "1.4"
        )).firstMatch
        XCTAssertTrue(version.waitForExistence(timeout: 2))
        let releaseDate = app.descendants(matching: .any).matching(NSPredicate(
            format: "value == %@ OR label == %@", "Released October 18, 2026", "Released October 18, 2026"
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
    func testOnlyPopulatedAlertSectionsAppear() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        app.buttons["createFirstAlertButton"].click()
        let editor = app.descendants(matching: .textView)["messageEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.click()
        editor.typeText("Distant appointment")
        replaceValue(in: app.textFields["alertDateField"], with: "01/01/2099")
        replaceValue(in: app.textFields["alertTimeField"], with: "12:00")
        app.buttons["saveAlertButton"].click()

        XCTAssertTrue(app.staticTexts["Distant appointment"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Future"].exists)
        XCTAssertFalse(app.staticTexts["Today"].exists)
        XCTAssertFalse(app.staticTexts["Later this week"].exists)
        XCTAssertFalse(app.staticTexts["Past"].exists)
        XCTAssertFalse(app.staticTexts["No past alerts"].exists)

        app.buttons["Delete"].click()
        XCTAssertTrue(app.staticTexts["No alerts"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Future"].exists)
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
        XCTAssertEqual(endDateField.frame.midY, app.buttons["Cancel"].frame.midY, accuracy: 1)
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
    func testNewAndEditDialogsKeepCompactLayoutAcrossRecurrenceTabs() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.activate()

        app.buttons["createFirstAlertButton"].click()
        let editor = app.descendants(matching: .textView)["messageEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 2))
        let oneTimeSize = sheet.frame.size
        XCTAssertEqual(oneTimeSize.width, 560, accuracy: 1)
        XCTAssertEqual(oneTimeSize.height, 460, accuracy: 1)

        assertRecurrenceTabsKeepLayout(oneTimeSize, in: app)

        editor.click()
        editor.typeText("Dialog size regression")
        assertRecurrenceTabsKeepLayout(oneTimeSize, in: app)
        app.buttons["saveAlertButton"].click()

        XCTAssertTrue(app.staticTexts["Dialog size regression"].waitForExistence(timeout: 2))
        app.buttons["Edit"].click()
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        XCTAssertTrue(sheet.checkBoxes["Enabled"].exists)
        assertRecurrenceTabsKeepLayout(oneTimeSize, in: app)

        editor.click()
        editor.typeKey("a", modifierFlags: .command)
        editor.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Enter a message."].waitForExistence(timeout: 2))
        replaceValue(in: app.textFields["alertDateField"], with: "01/01/2000")
        XCTAssertTrue(app.staticTexts["Choose a time in the future."].waitForExistence(timeout: 2))
        assertRecurrenceTabsKeepLayout(oneTimeSize, in: app)
    }

    @MainActor
    private func assertRecurrenceTabsKeepLayout(
        _ expectedSize: CGSize,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let referenceFrame = app.sheets.firstMatch.frame
        let messageY = app.descendants(matching: .textView)["messageEditor"].frame.minY - referenceFrame.minY
        let tabsY = app.radioButtons["One time"].frame.minY - referenceFrame.minY
        let timeY = app.textFields["alertTimeField"].frame.midY - referenceFrame.minY
        let buttonsY = app.buttons["Cancel"].frame.midY - referenceFrame.minY

        for recurrence in ["Daily", "Weekly", "Monthly", "Yearly", "One time"] {
            app.radioButtons[recurrence].click()
            let sheetFrame = app.sheets.firstMatch.frame
            XCTAssertEqual(sheetFrame.width, expectedSize.width, accuracy: 1, recurrence, file: file, line: line)
            XCTAssertEqual(sheetFrame.height, expectedSize.height, accuracy: 1, recurrence, file: file, line: line)
            let messageFrame = app.descendants(matching: .textView)["messageEditor"].frame
            XCTAssertEqual(messageFrame.height, 142, accuracy: 1, recurrence, file: file, line: line)
            XCTAssertEqual(messageFrame.minY - sheetFrame.minY, messageY, accuracy: 1, recurrence, file: file, line: line)
            XCTAssertEqual(
                app.radioButtons[recurrence].frame.minY - sheetFrame.minY, tabsY,
                accuracy: 1, recurrence, file: file, line: line
            )
            XCTAssertEqual(
                app.textFields["alertTimeField"].frame.midY - sheetFrame.minY, timeY,
                accuracy: 1, recurrence, file: file, line: line
            )
            for button in [app.buttons["Cancel"], app.buttons["saveAlertButton"]] {
                XCTAssertEqual(
                    button.frame.midY - sheetFrame.minY, buttonsY,
                    accuracy: 1, recurrence, file: file, line: line
                )
            }

            var controls = [
                app.sheets.firstMatch.staticTexts.matching(
                    NSPredicate(format: "value IN %@", ["New Alert", "Edit Alert"])
                ).firstMatch,
                app.staticTexts["Message"],
                app.descendants(matching: .textView)["messageEditor"],
                app.radioButtons[recurrence],
                app.textFields["alertTimeField"],
                app.checkBoxes["soundToggle"],
                app.buttons["Cancel"],
                app.buttons["saveAlertButton"]
            ]
            let enabledToggle = app.sheets.firstMatch.checkBoxes["Enabled"]
            if enabledToggle.exists {
                controls.append(enabledToggle)
                XCTAssertEqual(
                    enabledToggle.frame.midY, app.checkBoxes["soundToggle"].frame.midY,
                    accuracy: 1, recurrence, file: file, line: line
                )
            }
            if recurrence == "Daily" {
                controls.append(contentsOf: [
                    app.radioButtons["Weekdays"],
                    app.radioButtons["Every day"]
                ])
            } else if recurrence == "Weekly" {
                let weekday = app.descendants(matching: .any)["alertWeekdayPicker"]
                controls.append(weekday)
                XCTAssertEqual(weekday.frame.midY - sheetFrame.minY, timeY, accuracy: 1, recurrence, file: file, line: line)
            } else {
                let date = app.textFields["alertDateField"]
                controls.append(date)
                XCTAssertEqual(date.frame.midY - sheetFrame.minY, timeY, accuracy: 1, recurrence, file: file, line: line)
            }
            if recurrence != "One time" {
                controls.append(contentsOf: [
                    app.staticTexts["Until:"],
                    app.radioButtons["noEndDateRadioButton"],
                    app.radioButtons["endDateRadioButton"],
                    app.textFields["alertEndDateField"],
                    app.steppers["alertEndDateStepper"]
                ])
                let lastToggle = enabledToggle.exists ? enabledToggle : app.checkBoxes["soundToggle"]
                XCTAssertLessThan(
                    lastToggle.frame.maxY, app.staticTexts["Until:"].frame.minY,
                    recurrence, file: file, line: line
                )
                XCTAssertEqual(
                    app.textFields["alertEndDateField"].frame.midY, app.buttons["Cancel"].frame.midY,
                    accuracy: 1, recurrence, file: file, line: line
                )
                XCTAssertLessThan(
                    app.steppers["alertEndDateStepper"].frame.maxX, app.buttons["Cancel"].frame.minX,
                    recurrence, file: file, line: line
                )
                app.radioButtons["endDateRadioButton"].click()
                XCTAssertTrue(app.textFields["alertEndDateField"].isEnabled, file: file, line: line)
                XCTAssertTrue(app.textFields["alertEndDateField"].isHittable, file: file, line: line)
                XCTAssertEqual(
                    app.sheets.firstMatch.frame.size, expectedSize,
                    recurrence, file: file, line: line
                )
                app.radioButtons["noEndDateRadioButton"].click()
            }
            for element in controls {
                let controlFrame = element.frame
                XCTAssertTrue(
                    sheetFrame.contains(controlFrame),
                    "\(recurrence): \(element.identifier) at \(controlFrame) is outside \(sheetFrame)",
                    file: file,
                    line: line
                )
            }
            XCTAssertTrue(app.buttons["Cancel"].isHittable, recurrence, file: file, line: line)
            XCTAssertLessThan(
                app.checkBoxes["soundToggle"].frame.maxY,
                app.buttons["Cancel"].frame.minY,
                recurrence,
                file: file,
                line: line
            )
        }
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
