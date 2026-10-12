import XCTest

/// X-04 §6.2: rotating keeps the selected tab, open sheets, form drafts and the scroll position.
final class RotationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Every test starts and ends in portrait.
    @MainActor
    private func startInPortrait() {
        XCUIDevice.shared.orientation = .portrait
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
    }

    @MainActor
    private func rotate(_ app: XCUIApplication, to orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        _ = app.wait(for: .runningForeground, timeout: 2)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// The add-item sheet stays open with its typed text, on the Shopping tab, through landscape and back.
    @MainActor
    func testAnOpenSheetAndItsTextSurviveRotation() {
        startInPortrait()
        let app = XCUIApplication.launchedOnShoppingTab(extraArguments: ["-uiTestSeedStoreItems"])
        app.buttons["addMenu"].firstMatch.tap()
        app.buttons["addMenu.shoppingItem"].firstMatch.tap()
        let query = app.textFields["shopping.add.query"]
        XCTAssertTrue(query.waitForExistence(timeout: 5))
        query.tap()
        query.typeText("Alma")

        rotate(app, to: .landscapeLeft)
        attachScreenshot(app, named: "add-item-landscape")
        XCTAssertTrue(query.exists, "the sheet closed on rotation")
        XCTAssertEqual(query.value as? String, "Alma")

        rotate(app, to: .portrait)
        XCTAssertTrue(query.exists, "the sheet closed on rotating back")
        XCTAssertEqual(query.value as? String, "Alma")
    }

    /// An edited, unsaved product name survives rotation, and the product form stays open.
    @MainActor
    func testAProductFormDraftSurvivesRotation() {
        startInPortrait()
        let app = XCUIApplication.larari(extraArguments: ["-uiTestSeed"])
        app.launch()
        app.openTab("Search")
        let milk = app.buttons["product.row.Milk"]
        XCTAssertTrue(milk.waitForExistence(timeout: 10))
        milk.tap()
        let edit = app.buttons["product.detail.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let name = app.textFields["product.form.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(" bio")

        rotate(app, to: .landscapeRight)
        attachScreenshot(app, named: "product-form-landscape")
        XCTAssertEqual(name.value as? String, "Milk bio")

        rotate(app, to: .portrait)
        XCTAssertEqual(name.value as? String, "Milk bio")
    }

    /// Scrolled down to the last card at the largest text size: after landscape and back the last card is on screen
    /// again (not the top of the list), and the Inventory tab stays selected.
    @MainActor
    func testTheScrollPositionAndTabSurviveRotation() {
        startInPortrait()
        let app = XCUIApplication.larari(extraArguments: [
            "-uiTestSeed", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        app.launch()
        app.openTab("Inventory")
        let apples = app.buttons["inventory.row.Apples"]
        let milk = app.buttons["inventory.row.Milk"]
        XCTAssertTrue(apples.waitForExistence(timeout: 10))
        var swipes = 0
        while !(milk.exists && milk.isHittable) && swipes < 10 {
            app.swipeUp()                                            // the Inventory is a scroll view, not a list
            swipes += 1
        }
        XCTAssertTrue(milk.isHittable, "Milk never scrolled into view")
        XCTAssertFalse(apples.isHittable, "the list is too short to test the scroll position")

        // Landscape is shorter, so the same offset shows the cards above Milk there (the system keeps the offset);
        // the round trip must bring the same place back, not the top of the list.
        rotate(app, to: .landscapeLeft)
        attachScreenshot(app, named: "inventory-scrolled-landscape")

        rotate(app, to: .portrait)
        attachScreenshot(app, named: "inventory-scrolled-portrait")
        XCTAssertTrue(milk.exists && milk.isHittable, "rotating back lost the scroll position")
        XCTAssertFalse(apples.isHittable, "rotating back scrolled to the top")
        XCTAssertTrue(app.buttons["addMenu"].firstMatch.exists)
    }
}
