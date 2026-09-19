import XCTest

final class MoneyLogLaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesIntoSeededStore() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-MoneyLogInMemoryStore"]
        app.launch()

        XCTAssertTrue(app.navigationBars["MoneyLog"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Cash"].exists)
    }
}
