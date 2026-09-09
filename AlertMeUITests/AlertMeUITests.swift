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
}
