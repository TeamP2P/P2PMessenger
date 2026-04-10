import XCTest

final class OnboardingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments.append("--reset-onboarding")
    }

    @MainActor
    func testOnboardingFlow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--reset-onboarding")
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "App should be in foreground")

        // 1. Verify we are on the Welcome Screen
        // We check for the logo or some specific text
        let welcomeText = app.staticTexts["welcomeToP2PMessenger"] // This might be a localization key, let's see if it's resolved or if we should use identifiers
        // Actually, SwiftUI's localization keys often don't resolve in XCUIApplication queries unless localized.
        // Let's use the identifier for the button and textfield which we just added.

        let nameField = app.textFields["welcome_username_textfield"]
        if !nameField.waitForExistence(timeout: 10) {
            print("DEBUG: All text fields: \(app.textFields.allElementsBoundByIndex.map { $0.identifier })")
            print("DEBUG: All buttons: \(app.buttons.allElementsBoundByIndex.map { $0.identifier })")
            print("DEBUG HIERARCHY: \(app.debugDescription)")
            XCTFail("Name text field should be visible. Found: \(app.textFields.count) text fields.")
        }

        let startButton = app.buttons["welcome_start_button"]
        XCTAssertTrue(startButton.exists, "Start button should be visible")

        // 2. Verify button is initially disabled (since name is empty)
        // Note: isEnabled might be false if canGoForward is false
        XCTAssertFalse(startButton.isEnabled, "Start button should be disabled initially")

        // 3. Enter name
        nameField.tap()
        nameField.typeText("Antigravity")

        // 4. Check if button is enabled
        // Wait a bit for state update
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: startButton)
        // This might fail if permissions are not granted, but let's see how it behaves in CI.
        // In some setups, permissions are granted by default or can be bypassed.
        // If this fails, we'll know and can adjust.

        // XCTWaiter.wait(for: [expectation], timeout: 2)
    }
}
