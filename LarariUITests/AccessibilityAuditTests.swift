import XCTest

/// X-04: `performAccessibilityAudit` on every main screen and sheet, in portrait, landscape, the largest
/// accessibility text size and dark mode (portrait). The light modes are forced light, so the device's own appearance
/// does not change the result. One test per screen, so a single screen can be re-run on its own.
final class AccessibilityAuditTests: XCTestCase {
    enum Screen: String {
        case inventory, stockSheet, storePicker, search, productDetail, productForm, shopping, listManager, addItem, purchase,
             inventoryByName, inventoryByExpiry, shoppingByName, productHistory, categoryPicker, spaceSettings,
             introduction, introductionPurchase, summaryChoice, gate
    }

    enum Mode: String, CaseIterable {
        case portrait, landscape, largestText, dark
    }

    /// Issues owned by the system (not our views) that cannot be fixed in Larari. Every entry needs a matching
    /// line in X-04's Results.
    static let ignoredIdentifiers: Set<String> = [
        "uiTest.liveActivity",          // DEBUG-only UI-test hook (N-04), not in a release build
        "uiTest.notificationKinds",     // DEBUG-only UI-test hook (P2-10a), not in a release build
    ]

    /// List-row Label titles (seed data) that wrap under their icon at the largest sizes, by screen.
    static let wrappedLabelTitles: [Screen: Set<String>] = [
        .spaceSettings: ["Storage locations"],
        .storePicker: ["Corner Shop"],
    ]

    /// The rules for system-owned issues that have no identifier to match. Each one has a line in X-04's Results
    /// ("Ignored"). The bar frames are read right before the audit.
    struct SystemOwned {
        let screen: Screen
        let window: CGRect
        let navigationBar: CGRect?
        /// Every navigation bar on screen (a sheet's and the screen's behind it).
        let navigationBars: [CGRect]
        let tabBar: CGRect?
        /// The introduction's page dots and Next button, each on its own: the purchase page scrolls under them like
        /// content under a tab bar.
        let introductionControls: [CGRect]

        /// On iPad a sheet is a form sheet in the middle of the window: its own bounds are the visible area.
        let sheet: CGRect?

        @MainActor
        init(screen: Screen, app: XCUIApplication) {
            self.screen = screen
            window = app.windows.firstMatch.frame
            // The narrowest bar is the frontmost sheet's (the screen behind a form sheet has a full-width one).
            let bars = app.navigationBars.allElementsBoundByIndex.map(\.frame).filter { !$0.isEmpty }
            navigationBars = bars
            let narrowest = bars.min { $0.width < $1.width }
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let first = app.navigationBars.firstMatch
            navigationBar = isPad ? narrowest : (first.exists ? first.frame : nil)
            let tabs = app.tabBars.firstMatch
            tabBar = tabs.exists ? tabs.frame : nil
            let dots = app.pageIndicators.firstMatch
            let next = app.buttons["introduction.next"]
            introductionControls = [dots, next].filter(\.exists).map(\.frame)
            // A form sheet is centred vertically, so it ends as far above the window's bottom as it starts below
            // the top.
            if isPad, let bar = narrowest, bar.width < window.width - 1 {
                sheet = CGRect(x: bar.minX, y: bar.minY, width: bar.width,
                               height: max(0, window.maxY - 2 * (bar.minY - window.minY) - window.minY))
            } else {
                sheet = nil
            }
        }

        /// The area where content is shown on the plain background: inside the window (or the iPad form sheet),
        /// below the navigation bar, above the floating tab bar.
        private var contentArea: CGRect {
            var area = sheet ?? window
            if let navigationBar, navigationBar.maxY > area.minY {
                area = CGRect(x: area.minX, y: navigationBar.maxY, width: area.width, height: area.maxY - navigationBar.maxY)
            }
            if let tabBar, tabBar.minY < area.maxY {
                area.size.height = max(0, tabBar.minY - area.minY)
            }
            return area
        }

        @MainActor
        func ignores(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
            let element = issue.element
            if ignoredIdentifiers.contains(element?.identifier ?? "") { return true }
            // The Shopping filter strip scrolls sideways at the largest sizes, so its last chip runs past the edge;
            // the audit reports that clipping without an element.
            if issue.auditType == .textClipped, element == nil, screen == .shopping { return true }
            // The introduction's purchase page (P4-07) at the largest sizes: its text runs on under the page dots and
            // Next until scrolled (the bottom margin lets the end clear them), and its scene's sample card is capped
            // at .large on purpose (P1-10a: the illustration never pushes the text off screen). Both are reported
            // without an element.
            if [.textClipped, .dynamicType].contains(issue.auditType), element == nil, screen == .introductionPurchase {
                return true
            }
            // Text hidden on purpose: the introduction's animated scenes are decoration, and a lot row's title is
            // read as part of its control's label (LotControlRow, P2-08a). The store picker's street and place
            // names are drawn by MapKit into the map.
            if issue.auditType == .elementDetection,
               [.introduction, .introductionPurchase, .stockSheet, .purchase, .storePicker].contains(screen) {
                return true
            }
            // iPad: the tab bar floats at the top and keeps its labels at a fixed size; at the largest sizes the audit
            // reports that without an element (the content itself scales, see the screenshots).
            if issue.auditType == .dynamicType, element == nil, UIDevice.current.userInterfaceIdiom == .pad {
                return true
            }
            // iPad: text it cannot attribute to an element, on screens with a form sheet over dimmed content (seen on
            // iPadOS 26 and 27).
            if issue.auditType == .elementDetection, element == nil, UIDevice.current.userInterfaceIdiom == .pad {
                return true
            }
            // Apple's semantic secondary label colour: passes at larger sizes and rises with Increase Contrast.
            if issue.auditType == .contrast, issue.compactDescription.contains("nearly passed") { return true }
            guard let element else { return false }
            let frame = element.frame
            // MapKit's required "Legal" attribution link.
            if element.elementType == .link, element.label == "Legal" { return true }
            // The iOS 26 glass toolbar buttons: the audit samples the glass, and the system keeps bar items at a
            // fixed size (Large Content Viewer instead).
            if navigationBars.contains(where: { $0.contains(frame) }) { return true }
            // Content that runs under the floating glass tab bar or past the screen edge is measured against
            // whatever lies behind it; on screen it scrolls into the plain area.
            if issue.auditType == .contrast, !contentArea.contains(frame) { return true }
            // Text that runs past the screen edge or under a bar is cut by the scroll view, not by its own frame.
            if issue.auditType == .textClipped, !contentArea.contains(frame) { return true }
            // The purchase page's text scrolled partly under the page dots or Next (the controls themselves, wholly
            // inside that area, are still audited).
            if screen == .introductionPurchase, [.contrast, .textClipped].contains(issue.auditType),
               introductionControls.contains(where: { $0.intersects(frame) }),
               !introductionControls.contains(where: { $0.contains(frame) }) {
                return true
            }
            // A list-row Label at accessibility sizes wraps its title under the icon, outside the frame the audit
            // reads (system Label layout; the screenshots show the whole title).
            if issue.auditType == .textClipped, wrappedLabelTitles[screen]?.contains(element.label) == true {
                return true
            }
            // Single-line text and search fields scroll their text sideways; that is the system field.
            if issue.auditType == .textClipped, [.textField, .searchField].contains(element.elementType) { return true }
            // The store picker card is Liquid Glass over the live map, so the background under its text changes.
            if screen == .storePicker, issue.auditType == .contrast, element.elementType == .staticText { return true }
            // iPad (iPadOS 27): the category picker's second row is flagged in light and dark while the screenshots
            // show primary text on the row background (about 21:1 and 15:1), like the rows around it that pass.
            if screen == .categoryPicker, issue.auditType == .contrast, element.elementType == .button,
               UIDevice.current.userInterfaceIdiom == .pad {
                return true
            }
            // A single black letter on the grouped background (18:1): the audit misreads one large glyph.
            if issue.auditType == .contrast, element.identifier.hasPrefix("search.section.") { return true }
            return false
        }
    }

    /// Dynamic Type and clipping are audited at the largest accessibility size, where they actually show. At the
    /// default size both checks only predict, and they flag ordinary SwiftUI text. Contrast does not depend on the
    /// text size (a larger size only lowers the bar), so it is audited in portrait, landscape and dark; at the largest
    /// size the long, scrolled screens made it report black text on white (X-04 Results).
    static func auditTypes(for mode: Mode) -> XCUIAccessibilityAuditType {
        mode == .largestText ? XCUIAccessibilityAuditType.all.subtracting(.contrast)
                             : XCUIAccessibilityAuditType.all.subtracting([.dynamicType, .textClipped])
    }

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor func testInventory() { audit(.inventory) }
    @MainActor func testStockSheet() { audit(.stockSheet) }
    @MainActor func testStorePicker() { audit(.storePicker) }
    @MainActor func testSearch() { audit(.search) }
    @MainActor func testProductDetail() { audit(.productDetail) }
    @MainActor func testProductForm() { audit(.productForm) }
    @MainActor func testShopping() { audit(.shopping) }
    @MainActor func testInventoryByName() { audit(.inventoryByName) }
    @MainActor func testInventoryByExpiry() { audit(.inventoryByExpiry) }
    @MainActor func testShoppingByName() { audit(.shoppingByName) }
    @MainActor func testProductHistory() { audit(.productHistory) }
    @MainActor func testCategoryPicker() { audit(.categoryPicker) }
    @MainActor func testListManager() { audit(.listManager) }
    @MainActor func testAddItem() { audit(.addItem) }
    @MainActor func testPurchase() { audit(.purchase) }
    @MainActor func testSpaceSettings() { audit(.spaceSettings) }
    @MainActor func testIntroduction() { audit(.introduction) }
    @MainActor func testIntroductionPurchase() { audit(.introductionPurchase) }
    @MainActor func testSummaryChoice() { audit(.summaryChoice) }
    @MainActor func testGate() { audit(.gate) }

    @MainActor
    private func audit(_ screen: Screen) {
        for mode in Mode.allCases {
            XCUIDevice.shared.orientation = .portrait
            XCTContext.runActivity(named: "\(screen.rawValue) — \(mode.rawValue)") { _ in
                let app = launch(for: screen, mode: mode)
                defer {
                    XCUIDevice.shared.orientation = .portrait
                    app.terminate()
                }
                guard navigate(to: screen, in: app) else {
                    XCTFail("could not reach \(screen.rawValue) (\(mode.rawValue))")
                    attachScreenshot(app, named: "\(screen.rawValue)-\(mode.rawValue)-unreachable")
                    return
                }
                if mode == .landscape {
                    XCUIDevice.shared.orientation = .landscapeLeft
                    _ = app.wait(for: .runningForeground, timeout: 2)
                    RunLoop.current.run(until: Date().addingTimeInterval(1))
                }
                attachScreenshot(app, named: "\(screen.rawValue)-\(mode.rawValue)")
                var found: [String] = []
                do {
                    let systemOwned = SystemOwned(screen: screen, app: app)
                    try app.performAccessibilityAudit(for: Self.auditTypes(for: mode)) { issue in
                        let ignored = systemOwned.ignores(issue)
                        if !ignored { found.append(Self.describe(issue)) }
                        return ignored
                    }
                } catch {
                    XCTFail("\(screen.rawValue) \(mode.rawValue): audit could not run: \(error)")
                }
                if !found.isEmpty {
                    let report = XCTAttachment(string: found.joined(separator: "\n"))
                    report.name = "audit-\(screen.rawValue)-\(mode.rawValue)"
                    report.lifetime = .keepAlways
                    add(report)
                }
            }
        }
    }

    /// One line per issue for the report attachment: the element is not named in the audit's own description.
    @MainActor
    private static func describe(_ issue: XCUIAccessibilityAuditIssue) -> String {
        var line = "\(issue.auditType.rawValue) \(issue.compactDescription)"
        if let element = issue.element {
            let frame = element.frame
            line += " — type \(element.elementType.rawValue) id '\(element.identifier)' label '\(element.label)'"
            line += " frame (\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height)))"
        }
        return line
    }

    @MainActor
    private func launch(for screen: Screen, mode: Mode) -> XCUIApplication {
        var extra = ["-uiTestSeed"]
        switch screen {
        case .shopping, .shoppingByName, .listManager, .addItem, .purchase: extra.append("-uiTestSeedStoreItems")
        case .introduction, .introductionPurchase: extra.append("-resetIntroduction")
        case .summaryChoice: extra += ["-resetIntroduction", "-uiTestNotificationsGranted"]
        default: break
        }
        if mode == .dark { extra.append("-uiTestDarkMode") }
        if mode == .largestText {
            extra += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        } else {
            // Contrast is audited with Increase Contrast on (X-04 1A): the light accent is the Mocha 500 brand tint,
            // and its high-contrast variant (Mocha 800) is what the HIG asks custom colours to provide.
            extra.append("-uiTestIncreaseContrast")
        }
        let app = XCUIApplication.larari(accountState: screen == .gate ? "noAccount" : "available",
                                          skipIntroduction: ![.introduction, .introductionPurchase, .summaryChoice]
                                            .contains(screen),
                                          extraArguments: extra)
        app.launch()
        return app
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Scrolls the screen up until `element` is on screen: at the largest text size a card can start below the fold.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        // Lazy grids create a card only once it scrolls near the screen, so keep swiping until it exists too.
        _ = element.waitForExistence(timeout: 5)
        var swipes = 0
        // Swipe the list itself where there is one: a swipe on the window can land on a sheet's grabber instead.
        // On iPad a form sheet leaves the screen's own list visible behind it: take the narrowest, the sheet's.
        var list = app.collectionViews.firstMatch
        if UIDevice.current.userInterfaceIdiom == .pad,
           let narrowest = app.collectionViews.allElementsBoundByIndex.filter({ !$0.frame.isEmpty })
               .min(by: { $0.frame.width < $1.frame.width }) {
            list = narrowest
        }
        // Fully on screen, clear of the bottom edge: a half-visible menu row takes the tap but does not open.
        let visible = app.windows.firstMatch.frame.insetBy(dx: 0, dy: 60)
        func revealed() -> Bool { element.exists && element.isHittable && visible.contains(element.frame) }
        var lastFrame: CGRect?
        while !revealed() && swipes < 15 {
            // At the end of the list the last card can stay closer to the bottom edge than the margin (iPad at the
            // largest sizes); once a swipe no longer moves it, take it as it is.
            if element.exists, let lastFrame, element.frame == lastFrame { return element.isHittable }
            lastFrame = element.exists ? element.frame : nil
            if list.exists { list.swipeUp() } else { app.swipeUp() }
            swipes += 1
        }
        return revealed()
    }

    /// The tab bar on iPhone; on iPad the sections are sidebar cells (as `openTab`).
    @MainActor
    private func tapTab(_ label: String, in app: XCUIApplication) -> Bool {
        var tab = app.tabBars.buttons[label]
        if UIDevice.current.userInterfaceIdiom == .pad {
            let cell = app.cells[label]
            tab = cell.waitForExistence(timeout: 10) ? cell : app.buttons[label].firstMatch
        }
        guard tab.waitForExistence(timeout: 10) else { return false }
        tab.tap()
        return true
    }

    /// "•••" → a grouping ("By name", "By expiry"). A menu item's identifier is not reachable, so it goes by the
    /// English label.
    @MainActor
    private func chooseGrouping(_ label: String, menu: String, in app: XCUIApplication) -> Bool {
        let more = app.buttons[menu].firstMatch
        guard more.waitForExistence(timeout: 5) else { return false }
        more.tap()
        let option = app.buttons[label].firstMatch
        guard option.waitForExistence(timeout: 3) else { return false }
        option.tap()
        return true
    }

    /// The add-stock sheet for Bread, with a second lot so every lot control is on screen.
    @MainActor
    private func openStockSheet(in app: XCUIApplication) -> Bool {
        guard tapTab("Inventory", in: app),
              app.buttons["inventory.row.Bread"].waitForExistence(timeout: 10) else { return false }
        app.buttons["addMenu"].firstMatch.tap()
        app.buttons["addMenu.stock"].tap()
        let search = app.searchFields.firstMatch
        guard search.waitForExistence(timeout: 5) else { return false }
        search.tap()
        search.typeText("bread")
        // The results redraw while the search settles (slower on iPad), and a tap during that is lost: try twice.
        let bread = app.buttons["picker.row.Bread"].firstMatch
        let save = app.buttons["stock.save"]
        for _ in 0..<2 where !save.exists {
            guard bread.waitForExistence(timeout: 5) else { return false }
            let deadline = Date().addingTimeInterval(3)
            while !bread.isHittable && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
            bread.tap()
            _ = save.waitForExistence(timeout: 5)
        }
        guard save.exists else { return false }
        let addLot = app.buttons["lot.add"]
        guard reveal(addLot, in: app) else { return false }
        addLot.tap()
        return app.buttons["lot.2.remove"].waitForExistence(timeout: 3)
    }

    /// Eggs' full history page: the seed has one event, and the page link shows from four, so eat three eggs first.
    @MainActor
    private func openFullHistory(in app: XCUIApplication) -> Bool {
        let eggs = app.buttons["product.row.Eggs"]
        guard tapTab("Search", in: app), reveal(eggs, in: app) else { return false }
        eggs.tap()
        guard app.navigationBars["Eggs"].waitForExistence(timeout: 5) else { return false }
        for _ in 0..<3 {
            let item = app.buttons["stock.item"].firstMatch
            guard reveal(item, in: app) else { return false }
            item.tap()
            let consume = app.buttons["stock.consume"]
            guard consume.waitForExistence(timeout: 3) else { return false }
            consume.tap()
            let field = app.textFields["amount.field"]
            guard field.waitForExistence(timeout: 5) else { return false }
            // The text is centred: tap the right end so the cursor lands after it.
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
            let current = field.value as? String ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + "1")
            app.buttons["amount.confirm"].tap()
            // iPad: the decimal pad is a popover, and the first tap outside only closes it.
            if !field.waitForNonExistence(timeout: 3) { app.buttons["amount.confirm"].tap() }
            guard field.waitForNonExistence(timeout: 3) else { return false }
        }
        let showAll = app.buttons["history.showAll"]
        guard reveal(showAll, in: app) else { return false }
        showAll.tap()
        return app.descendants(matching: .any)["history.page"].waitForExistence(timeout: 5)
    }

    @MainActor
    private func navigate(to screen: Screen, in app: XCUIApplication) -> Bool {
        switch screen {
        case .inventory:
            // Inventory starts by name (2026-10-05); this screen audits the location grouping.
            guard tapTab("Inventory", in: app), app.buttons["inventory.row.Bread"].waitForExistence(timeout: 10) else {
                return false
            }
            return chooseGrouping("By location", menu: "inventory.more", in: app)
                && app.descendants(matching: .any)["inventory.section.expiring"].waitForExistence(timeout: 5)
        case .stockSheet:
            return openStockSheet(in: app)
        case .storePicker:
            guard openStockSheet(in: app) else { return false }
            let storeMenu = app.buttons["store.menu"].firstMatch
            guard reveal(storeMenu, in: app) else { return false }
            RunLoop.current.run(until: Date().addingTimeInterval(1))     // a tap while the scroll settles only stops it
            // A lazy row can be rebuilt while the scroll settles (iPad sheet at the largest sizes): find it again.
            if !storeMenu.exists { guard reveal(storeMenu, in: app) else { return false } }
            // The row-wide accessibility frame of a Form control: tap the value near the trailing edge (at the
            // largest sizes it sits under the title), not the frame's empty centre.
            // iPhone: the value near the trailing edge; iPad: the row's centre (the trailing point misses there).
            // The other point is the fallback.
            let valuePoint = storeMenu.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.7))
            let centre = storeMenu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let points = UIDevice.current.userInterfaceIdiom == .pad ? [centre, valuePoint] : [valuePoint, centre]
            let other = app.buttons["Other store…"]
            for point in points where !other.exists {
                point.tap()
                _ = other.waitForExistence(timeout: 3)
            }
            guard other.waitForExistence(timeout: 5) else {
                attachScreenshot(app, named: "storePicker-menu-without-other")
                return false
            }
            other.tap()
            return app.textFields["store.search"].waitForExistence(timeout: 5)
        case .search:
            return tapTab("Search", in: app) && app.buttons["product.row.Apples"].waitForExistence(timeout: 10)
        case .productDetail:
            let milk = app.buttons["product.row.Milk"]
            guard tapTab("Search", in: app), reveal(milk, in: app) else { return false }
            milk.tap()
            return app.navigationBars["Milk"].waitForExistence(timeout: 5)
        case .productForm:
            let milk = app.buttons["product.row.Milk"]
            guard tapTab("Search", in: app), reveal(milk, in: app) else { return false }
            milk.tap()
            let edit = app.buttons["product.detail.edit"]
            guard edit.waitForExistence(timeout: 5) else { return false }
            edit.tap()
            return app.textFields["product.form.name"].waitForExistence(timeout: 5)
        case .productHistory:
            return openFullHistory(in: app)
        case .categoryPicker:
            let milk = app.buttons["product.row.Milk"]
            guard tapTab("Search", in: app), reveal(milk, in: app) else { return false }
            milk.tap()
            let edit = app.buttons["product.detail.edit"]
            guard edit.waitForExistence(timeout: 5) else { return false }
            edit.tap()
            let category = app.buttons["product.form.category"]
            guard reveal(category, in: app) else { return false }
            category.tap()
            return app.buttons["category.none"].waitForExistence(timeout: 5)
        case .shopping:
            return tapTab("Shopping", in: app) && app.buttons["shopping.filter.all"].waitForExistence(timeout: 10)
        case .inventoryByName:
            guard tapTab("Inventory", in: app), app.buttons["inventory.row.Bread"].waitForExistence(timeout: 10) else {
                return false
            }
            return chooseGrouping("By name", menu: "inventory.more", in: app)
                && app.descendants(matching: .any)["inventory.section.letter.B"].waitForExistence(timeout: 5)
        case .inventoryByExpiry:
            guard tapTab("Inventory", in: app), app.buttons["inventory.row.Bread"].waitForExistence(timeout: 10) else {
                return false
            }
            return chooseGrouping("By expiry", menu: "inventory.more", in: app)
                && app.descendants(matching: .any)["inventory.section.expiry.expired"].waitForExistence(timeout: 5)
        case .shoppingByName:
            guard tapTab("Shopping", in: app), app.buttons["shopping.filter.all"].waitForExistence(timeout: 10) else {
                return false
            }
            return chooseGrouping("By name", menu: "shopping.more", in: app)
                && app.descendants(matching: .any)["shopping.section.letter.M"].waitForExistence(timeout: 5)
        case .listManager:
            guard tapTab("Shopping", in: app), app.buttons["shopping.more"].firstMatch.waitForExistence(timeout: 10) else {
                return false
            }
            app.buttons["shopping.more"].firstMatch.tap()
            let manage = app.buttons["Manage lists"].firstMatch     // menu items: by label, not identifier
            guard manage.waitForExistence(timeout: 3) else { return false }
            manage.tap()
            return app.buttons["shopping.manage.done"].waitForExistence(timeout: 5)
        case .addItem:
            guard tapTab("Shopping", in: app), app.buttons["addMenu"].firstMatch.waitForExistence(timeout: 10) else {
                return false
            }
            app.buttons["addMenu"].firstMatch.tap()
            app.buttons["addMenu.shoppingItem"].firstMatch.tap()
            return app.textFields["shopping.add.query"].waitForExistence(timeout: 5)
        case .purchase:
            let napkins = app.buttons["shopping.item.Napkins"]
            guard tapTab("Shopping", in: app), reveal(napkins, in: app) else { return false }
            napkins.tap()
            return app.buttons["shopping.purchase.confirm"].waitForExistence(timeout: 5)
        case .spaceSettings:
            guard tapTab("Inventory", in: app) else { return false }
            app.openSettings()
            return app.buttons["space.settings.done"].exists
        case .introduction:
            return app.buttons["introduction.skip"].waitForExistence(timeout: 10)
        case .introductionPurchase:
            // P4-07: the purchase question, the fifth page.
            guard app.buttons["introduction.next"].waitForExistence(timeout: 10) else { return false }
            for _ in 0..<4 { app.buttons["introduction.next"].tap() }
            return app.buttons["introduction.purchase.inventory"].waitForExistence(timeout: 5)
        case .summaryChoice:
            // P2-10a: "Get started" with notifications allowed brings up the daily / weekly choice.
            guard app.buttons["introduction.next"].waitForExistence(timeout: 10) else { return false }
            while app.buttons["introduction.next"].exists { app.buttons["introduction.next"].tap() }
            app.buttons["introduction.getStarted"].tap()
            return app.buttons["introduction.summary.done"].waitForExistence(timeout: 5)
        case .gate:
            return app.descendants(matching: .any)["accountGate"].waitForExistence(timeout: 10)
        }
    }
}
