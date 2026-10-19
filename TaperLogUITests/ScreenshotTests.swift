import XCTest

/// Captures App Store screenshots. Run with scripts/screenshots.sh TaperLog.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAppScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-resetData", "-sampleData", "-skipOnboarding", "-uiTesting"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Today's doses"].waitForExistence(timeout: 10))
        snap("01-today", app)

        app.buttons["How do I use this app"].tap()
        XCTAssertTrue(app.staticTexts["Add the medicine"].waitForExistence(timeout: 5))
        snap("06-how-to", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        tab("Plan", app)
        XCTAssertTrue(app.navigationBars["Plan"].waitForExistence(timeout: 5))
        app.swipeUp()
        snap("02-plan", app)

        tab("Symptoms", app)
        XCTAssertTrue(app.navigationBars["Symptoms"].waitForExistence(timeout: 5))
        snap("03-symptoms", app)

        app.buttons["New check-in"].tap()
        XCTAssertTrue(app.staticTexts["How was today overall?"].waitForExistence(timeout: 5))
        app.swipeUp()
        snap("04-check-in", app)
        app.buttons["Cancel"].tap()

        tab("Report", app)
        XCTAssertTrue(app.navigationBars["Report"].waitForExistence(timeout: 5))
        snap("05-report", app)
    }

    func testPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-uiTesting", "-mockPrices"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Lifetime"].waitForExistence(timeout: 10))
        snap("paywall", app)
    }

    /// iPhone shows a bottom tab bar; iPad shows a floating segmented control.
    private func tab(_ name: String, _ app: XCUIApplication) {
        let inTabBar = app.tabBars.buttons[name]
        if inTabBar.waitForExistence(timeout: 2) { inTabBar.tap() } else { app.buttons[name].firstMatch.tap() }
    }

    private func snap(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
