import XCTest
import CoreLocation

final class SpotClickerUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func allowLocationIfAsked() {
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = system.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 2) { allow.tap() }
    }

    func testCaptureBothListsAndUndo() throws {
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 40.7322, longitude: -74.0025))
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launch()
        allowLocationIfAsked()
        app.buttons["saveLiked"].tap()
        allowLocationIfAsked()
        XCTAssertTrue(app.staticTexts["Saved to Liked"].waitForExistence(timeout: 20))
        app.buttons["saveWantToGo"].tap()
        XCTAssertTrue(app.staticTexts["Saved to Want to go"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["2 saved"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Map with two captures"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.tabBars.buttons["Clicker"].tap()
        XCTAssertTrue(app.navigationBars["Your clicker"].waitForExistence(timeout: 5))
        let undo = app.buttons["undoCapture"]
        for _ in 0..<4 {
            if undo.exists && undo.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        XCTAssertTrue(app.staticTexts["Last spot removed"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Map"].tap()
        XCTAssertTrue(app.staticTexts["1 saved"].exists)
    }

    func testExampleEditAndSearchPersistAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launch()
        allowLocationIfAsked()
        app.tabBars.buttons["Clicker"].tap()
        XCTAssertTrue(app.navigationBars["Your clicker"].waitForExistence(timeout: 5))
        let examples = app.buttons["addExamples"]
        for _ in 0..<8 {
            if examples.exists && examples.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(examples.waitForExistence(timeout: 5))
        examples.tap()
        app.tabBars.buttons["Spots"].tap()
        let row = app.buttons.containing(.staticText, identifier: "A quiet corner").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let name = app.textFields["spotName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.press(forDuration: 1.2)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        else { name.tap(withNumberOfTaps: 3, numberOfTouches: 1) }
        name.typeText("A favorite corner")
        app.buttons["saveSpotDetails"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.tabBars.buttons["Spots"].tap()
        XCTAssertTrue(app.staticTexts["A favorite corner"].waitForExistence(timeout: 5))
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("favorite")
        XCTAssertTrue(app.staticTexts["A favorite corner"].exists)
        XCTAssertFalse(app.staticTexts["A coffee stop"].exists)
    }
}
