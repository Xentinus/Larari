import XCTest

/// P1-10 introduction, four pages since P1-10b (user picks A and X, 2026-10-14): Apple Welcome rows, the purchase
/// question, the summary choice, the store reminders; the last two ask for their permission and have "Not Now".
final class IntroductionUITests: XCTestCase {
    /// Titles after the welcome page, in order.
    private let laterTitles = ["When you buy something…", "Stay ahead of expiry dates", "Remind you at the store?"]

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
    func testWelcomeListsWhatLarariDoes() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Welcome to Larari"].waitForExistence(timeout: 10))
        for title in ["Know what's at home", "Shopping made simple", "Personal and shared", "Your data is yours"] {
            XCTAssertTrue(app.staticTexts[title].exists, "Row \(title) not shown")
        }
        XCTAssertTrue(app.staticTexts["Stored in your own iCloud, so you need an iCloud account. Free, with no ads and no tracking."].exists)
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
        XCTAssertFalse(app.buttons["Skip"].exists, "the permission pages have Not Now instead")
        XCTAssertTrue(app.buttons["Not Now"].exists)

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
        XCTAssertTrue(app.staticTexts["When you buy something…"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Next"].isHittable)
    }

    /// Device review aid (previews time out in Xcode 27): one screenshot per page, portrait and landscape.
    /// Export with `xcrun xcresulttool export attachments`.
    @MainActor
    func testEveryPageScreenshot() throws {
        let app = launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.staticTexts["Welcome to Larari"].waitForExistence(timeout: 10))
        for (index, name) in ["welcome", "purchase", "notifications", "stores"].enumerated() {
            if index > 0 {
                app.buttons["Next"].tap()
                XCTAssertTrue(app.staticTexts[laterTitles[index - 1]].waitForExistence(timeout: 3))
            }
            for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
                XCUIDevice.shared.orientation = orientation
                sleep(1)
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "intro-\(index + 1)-\(name)-\(orientation == .portrait ? "portrait" : "landscape")"
                shot.lifetime = .keepAlways
                add(shot)
            }
            XCUIDevice.shared.orientation = .portrait
        }
        XCTAssertTrue(app.buttons["Get started"].exists)
    }

    /// P4-07 (I-A): the page after the welcome asks whether purchases go into inventory; the answer is the purchase
    /// sheet's default.
    @MainActor
    func testThePurchaseQuestionSetsThePurchaseSheetDefault() throws {
        let app = XCUIApplication.larari(skipIntroduction: false,
                                          extraArguments: ["-resetIntroduction", "-uiTestSeed", "-uiTestSeedStoreItems"])
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Larari"].waitForExistence(timeout: 10))
        app.buttons["Next"].tap()
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

    /// P2-10a on the third page (P1-10b, X): Next asks for permission and, allowed, writes the choice; Get started on
    /// the store page turns the store reminders on.
    @MainActor
    func testAllowedNotificationsWriteTheSummaryChoice() throws {
        let app = launchToSummaryChoice(granted: true)
        XCTAssertTrue(app.staticTexts["We check in at 7 am, and only when something expires."].exists)
        let daily = app.buttons["introduction.summary.daily"]
        let weekly = app.buttons["introduction.summary.weekly"]
        let both = app.buttons["introduction.summary.both"]
        XCTAssertTrue(both.isSelected, "both is preselected")
        XCTAssertFalse(daily.isSelected)
        weekly.tap()
        XCTAssertTrue(weekly.isSelected)
        XCTAssertFalse(both.isSelected)

        app.buttons["introduction.notifications.next"].tap()
        XCTAssertTrue(app.staticTexts["Remind you at the store?"].waitForExistence(timeout: 3))
        app.buttons["Get started"].tap()
        XCTAssertTrue(app.navigationBars["Inventory"].waitForExistence(timeout: 10))
        let kinds = app.staticTexts["uiTest.notificationKinds"]
        XCTAssertTrue(kinds.waitForExistence(timeout: 5))
        XCTAssertEqual(kinds.label, "weekly")
        XCTAssertEqual(app.staticTexts["uiTest.storeReminders"].label, "on")
    }

    /// P2-10a (D-B): declined, the choice is not written and both summaries stay on.
    @MainActor
    func testDeclinedNotificationsKeepBoth() throws {
        let app = launchToSummaryChoice(granted: false)
        app.buttons["introduction.summary.daily"].tap()
        app.buttons["introduction.notifications.next"].tap()
        XCTAssertTrue(app.staticTexts["Remind you at the store?"].waitForExistence(timeout: 3))
        app.buttons["Get started"].tap()
        XCTAssertTrue(app.navigationBars["Inventory"].waitForExistence(timeout: 10))
        let kinds = app.staticTexts["uiTest.notificationKinds"]
        XCTAssertTrue(kinds.waitForExistence(timeout: 5))
        XCTAssertEqual(kinds.label, "daily weekly")
    }

    /// P1-10b (X): "Not Now" on both permission pages turns the summaries and the store reminders off.
    @MainActor
    func testNotNowTurnsEverythingOff() throws {
        let app = launchToSummaryChoice(granted: true)
        app.buttons["introduction.notifications.notNow"].tap()
        XCTAssertTrue(app.staticTexts["Remind you at the store?"].waitForExistence(timeout: 3))
        app.buttons["introduction.stores.notNow"].tap()
        XCTAssertTrue(app.navigationBars["Inventory"].waitForExistence(timeout: 10))
        let kinds = app.staticTexts["uiTest.notificationKinds"]
        XCTAssertTrue(kinds.waitForExistence(timeout: 5))
        XCTAssertEqual(kinds.label, "none")
        XCTAssertEqual(app.staticTexts["uiTest.storeReminders"].label, "off")
    }

    @MainActor
    private func launchToSummaryChoice(granted: Bool) -> XCUIApplication {
        let app = XCUIApplication.larari(skipIntroduction: false,
                                          extraArguments: ["-resetIntroduction"]
                                            + (granted ? ["-uiTestNotificationsGranted"] : []))
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Larari"].waitForExistence(timeout: 10))
        for _ in 0..<2 { app.buttons["introduction.next"].tap() }
        XCTAssertTrue(app.staticTexts["Stay ahead of expiry dates"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Skip"].exists)
        return app
    }
}
