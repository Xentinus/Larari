import XCTest

/// App Store screenshots (T-02): the `-uiTestDemo` data in English, Hungarian and German, one attachment per
/// screen, named `<language>-<order>-<screen>`. Run on the physical iPhone, then the iPad; the frames and captions
/// are added on the Mac.
final class AppStoreScreenshotTests: XCTestCase {
    struct Language {
        let code: String, locale: String
        /// The product opened on the detail screen (it has six months of prices).
        let milk: String
        /// The demo household's name in the space menu.
        let household: String
    }

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor func testEnglish() { capture(Language(code: "en", locale: "en_US", milk: "Milk", household: "Our home")) }
    @MainActor func testHungarian() { capture(Language(code: "hu", locale: "hu_HU", milk: "Tej", household: "Otthon")) }
    @MainActor func testGerman() { capture(Language(code: "de", locale: "de_DE", milk: "Milch", household: "Zuhause")) }

    @MainActor
    private func capture(_ language: Language) {
        XCUIDevice.shared.orientation = .portrait
        shoot(language, "1-inventory", grouping: "location") { _ in true }
        shoot(language, "2-expiry", grouping: "expiry") { _ in true }
        shoot(language, "3-detail", grouping: "location") { app in
            let row = app.buttons["inventory.row.\(language.milk)"].firstMatch
            guard row.waitForExistence(timeout: 10) else { return false }
            row.tap()
            guard app.navigationBars[language.milk].waitForExistence(timeout: 5) else { return false }
            // Scroll so the whole price trend chart is above the tab bar.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
            return true
        }
        shoot(language, "4-shopping", grouping: "location") { app in self.tab(1, in: app) }
        shoot(language, "5-family", grouping: "location") { app in
            let switcher = app.buttons["spaceSwitcher"].firstMatch
            guard switcher.waitForExistence(timeout: 10) else { return false }
            switcher.tap()
            let home = app.buttons[language.household].firstMatch
            guard home.waitForExistence(timeout: 5) else { return false }
            home.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(1))
            app.openSettings()
            return app.descendants(matching: .any)["member.row.me"].firstMatch.waitForExistence(timeout: 5)
        }
    }

    /// One fresh launch per screen, so every screenshot starts from the same data and scroll position.
    @MainActor
    private func shoot(_ language: Language, _ name: String, grouping: String,
                       navigate: (XCUIApplication) -> Bool) {
        let app = XCUIApplication.larari(language: language.code, locale: language.locale,
                                          extraArguments: ["-uiTestDemo", "-uiTestInventoryGrouping", grouping])
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "\(name): no tab bar")
        guard navigate(app) else {
            XCTFail("\(language.code) \(name): could not reach the screen")
            return
        }
        // Product photos load asynchronously; give the cards a moment to show them.
        RunLoop.current.run(until: Date().addingTimeInterval(2.5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "\(language.code)-\(name)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Tabs by position, because their titles are localised.
    @MainActor
    private func tab(_ index: Int, in app: XCUIApplication) -> Bool {
        let button = app.tabBars.buttons.element(boundBy: index)
        guard button.waitForExistence(timeout: 10) else { return false }
        button.tap()
        return true
    }
}
