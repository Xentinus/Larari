import XCTest

/// P1-10 introduction, animated in P1-10a (user pick 1I · 2C · 3B · 4B · 5C · 8H · 6C, 2026-09-26).
final class IntroductionUITests: XCTestCase {
    /// Titles after the welcome page, in order.
    private let laterTitles = ["Completely free", "Know what's at home", "Shopping made simple",
                               "When you buy something…", "Personal and shared", "Your data is yours",
                               "Stay ahead of expiry dates"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(accountState: String = "noAccount") -> XCUIApplication {
        let app = XCUIApplication.larari(accountState: accountState, skipIntroduction: false,
                                          extraArguments: ["-resetIntroduction"])
        app.launch()
        return app
    }

    @MainActor
    func testFreeIsTheSecondPage() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Welcome to Larari"].waitForExistence(timeout: 10))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Completely free"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Every feature is for everyone, with no subscription, no ads and no premium tier."].exists)
    }

    @MainActor
    func testFirstLaunchShowsIntroductionOnceThenTheGate() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Welcome to Larari"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Skip"].exists)
        XCTAssertFalse(app.staticTexts["iCloud is required"].exists)

        for title in laterTitles {
            app.swipeLeft()
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 3), "Page \(title) not shown")
        }
        XCTAssertFalse(app.buttons["Skip"].exists)

        app.buttons["Get started"].tap()
        XCTAssertTrue(app.staticTexts["iCloud is required"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["When should we notify you?"].exists, "declined: no summary choice (D-B)")

        app.terminate()
        let relaunched = XCUIApplication.larari(accountState: "noAccount", skipIntroduction: false)
        relaunched.launch()
        XCTAssertTrue(relaunched.staticTexts["iCloud is required"].waitForExistence(timeout: 10))
        XCTAssertFalse(relaunched.staticTexts["Welcome to Larari"].exists)
    }

    @MainActor
    func testSkipGoesStraightToTheMainShell() throws {
        let app = launch(accountState: "available")
        let skip = app.buttons["introduction.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        XCTAssertEqual(skip.label, "Skip")
        skip.tap()
        XCTAssertTrue(app.navigationBars["Inventory"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testLandscapeShowsTheSamePage() throws {
        let app = launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.staticTexts["Welcome to Larari"].waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts["Welcome to Larari"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Next"].isHittable)
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Completely free"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Next"].isHittable)
    }

    /// Device review aid (previews time out in Xcode 27): one screenshot per page after its scene has finished.
    /// Export with `xcrun xcresulttool export attachments`.
    @MainActor
    func testEveryPageFinishesItsScene() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Welcome to Larari"].waitForExistence(timeout: 10))
        let names = ["welcome", "free", "inventory", "shopping", "purchase", "spaces", "privacy", "notifications"]
        for (index, name) in names.enumerated() {
            if index > 0 {
                app.buttons["Next"].tap()
                XCTAssertTrue(app.staticTexts[laterTitles[index - 1]].waitForExistence(timeout: 3))
            }
            sleep(4)
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "intro-\(index + 1)-\(name)"
            shot.lifetime = .keepAlways
            add(shot)
        }
        XCTAssertTrue(app.buttons["Get started"].exists)
    }

    /// Device review aid (P2-08d): the three card pages in landscape, where the scene is only 260 pt high.
    @MainActor
    func testCardPagesInLandscape() throws {
        let app = launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.staticTexts["Welcome to Larari"].waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .landscapeLeft
        for (index, name) in ["welcome", "free", "inventory", "shopping"].enumerated() {
            if index > 0 {
                app.buttons["Next"].tap()
                XCTAssertTrue(app.staticTexts[laterTitles[index - 1]].waitForExistence(timeout: 3))
            }
            guard name != "free" else { continue }
            sleep(4)
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "intro-landscape-\(name)"
            shot.lifetime = .keepAlways
            add(shot)
        }
    }

    /// P4-07 (I-A): the page after Shopping asks whether purchases go into inventory; the answer is the purchase
    /// sheet's default.
    @MainActor
    func testThePurchaseQuestionSetsThePurchaseSheetDefault() throws {
        let app = XCUIApplication.larari(skipIntroduction: false,
                                          extraArguments: ["-resetIntroduction", "-uiTestSeed", "-uiTestSeedStoreItems"])
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Larari"].waitForExistence(timeout: 10))
        for _ in 0..<4 { app.buttons["Next"].tap() }
        XCTAssertTrue(app.staticTexts["When you buy something…"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["You can change this any time in Settings ▸ Larari."].exists)
        let inventory = app.buttons["introduction.purchase.inventory"]
        let listOnly = app.buttons["introduction.purchase.listOnly"]
        XCTAssertTrue(inventory.isSelected, "into inventory is the default")
        XCTAssertFalse(listOnly.isSelected)
        listOnly.tap()
        XCTAssertTrue(listOnly.isSelected)
        XCTAssertFalse(inventory.isSelected)

        while !app.buttons["Get started"].exists { app.buttons["Next"].tap() }
        app.buttons["Get started"].tap()
        app.openTab("Shopping")
        let soap = app.buttons["shopping.item.Soap"]
        XCTAssertTrue(soap.waitForExistence(timeout: 15))
        soap.tap()
        let toggle = app.switches["shopping.purchase.addToInventory"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0", "the introduction's answer is the sheet's default")
    }

    /// P2-10a (G-A): "Get started" with notifications allowed asks for daily, weekly or both; "Done" writes the
    /// Settings switches.
    @MainActor
    func testAllowedNotificationsAskWhichSummaries() throws {
        let app = launchToSummaryChoice()
        XCTAssertTrue(app.staticTexts["We check in at 7 am, and only when something expires."].exists)
        let daily = app.buttons["introduction.summary.daily"]
        let weekly = app.buttons["introduction.summary.weekly"]
        let both = app.buttons["introduction.summary.both"]
        XCTAssertTrue(both.isSelected, "both is preselected")
        XCTAssertFalse(daily.isSelected)
        weekly.tap()
        XCTAssertTrue(weekly.isSelected)
        XCTAssertFalse(both.isSelected)

        app.buttons["introduction.summary.done"].tap()
        XCTAssertTrue(app.navigationBars["Inventory"].waitForExistence(timeout: 10))
        let kinds = app.staticTexts["uiTest.notificationKinds"]
        XCTAssertTrue(kinds.waitForExistence(timeout: 5))
        XCTAssertEqual(kinds.label, "weekly")
    }

    /// P2-10a: swiping the choice away closes the introduction and keeps both summaries on.
    @MainActor
    func testSwipingTheSummaryChoiceAwayKeepsBoth() throws {
        let app = launchToSummaryChoice()
        app.buttons["introduction.summary.daily"].tap()
        let grabber = app.buttons["Sheet Grabber"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grabber.press(forDuration: 0.1,
                      thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        XCTAssertTrue(app.navigationBars["Inventory"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["uiTest.notificationKinds"].label, "daily weekly")
    }

    @MainActor
    private func launchToSummaryChoice() -> XCUIApplication {
        let app = XCUIApplication.larari(skipIntroduction: false,
                                          extraArguments: ["-resetIntroduction", "-uiTestNotificationsGranted"])
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Larari"].waitForExistence(timeout: 10))
        while !app.buttons["Get started"].exists { app.buttons["Next"].tap() }
        app.buttons["Get started"].tap()
        XCTAssertTrue(app.staticTexts["When should we notify you?"].waitForExistence(timeout: 5))
        return app
    }
}
