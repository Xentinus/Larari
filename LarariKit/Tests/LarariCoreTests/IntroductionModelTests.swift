import Foundation
import Testing
@testable import LarariCore

actor FakeNotificationAuthorizer: NotificationAuthorizing {
    private(set) var requests = 0
    private let granted: Bool
    private let fails: Bool

    init(granted: Bool = true, fails: Bool = false) {
        self.granted = granted
        self.fails = fails
    }

    func requestAuthorization() async throws -> Bool {
        requests += 1
        if fails { throw CocoaError(.featureUnsupported) }
        return granted
    }
}

@MainActor
@Suite("IntroductionModel")
struct IntroductionModelTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "IntroductionModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// P1-10b (user picks A, X, 2026-10-14): the Apple Welcome page, the purchase question (P4-07), the summary
    /// choice (P2-10a), then the store reminders (P4-06); each permission is asked on its own page.
    @Test func hasFourPagesInOrder() {
        #expect(IntroductionPage.allCases == [.welcome, .purchase, .notifications, .stores])
    }

    @Test func showsOnFirstLaunch() {
        let model = IntroductionModel(defaults: freshDefaults(), notifications: FakeNotificationAuthorizer())
        #expect(model.shouldShow)
        #expect(model.currentPage == .welcome)
        #expect(!model.isOnLastPage)
    }

    @Test func nextWalksToTheLastPageAndStops() {
        let model = IntroductionModel(defaults: freshDefaults(), notifications: FakeNotificationAuthorizer())
        for _ in 0..<10 { model.next() }
        #expect(model.currentPage == .stores)
        #expect(model.isOnLastPage)
    }

    @Test func finishPersistsAndNeverShowsAgain() async {
        let defaults = freshDefaults()
        let model = IntroductionModel(defaults: defaults, notifications: FakeNotificationAuthorizer(granted: false))
        await model.finish()

        #expect(!model.shouldShow)
        #expect(defaults.bool(forKey: "hasSeenIntroduction"))
        let relaunched = IntroductionModel(defaults: defaults, notifications: FakeNotificationAuthorizer())
        #expect(!relaunched.shouldShow)
    }

    @Test func skipPersistsWithoutAskingForPermission() async {
        let defaults = freshDefaults()
        let notifications = FakeNotificationAuthorizer()
        let model = IntroductionModel(defaults: defaults, notifications: notifications)
        model.skip()

        #expect(!model.shouldShow)
        #expect(defaults.bool(forKey: "hasSeenIntroduction"))
        #expect(await notifications.requests == 0)
        #expect(!IntroductionModel(defaults: defaults, notifications: notifications).shouldShow)
    }

    @Test func finishAsksForPermissionExactlyOnce() async {
        let notifications = FakeNotificationAuthorizer()
        let model = IntroductionModel(defaults: freshDefaults(), notifications: notifications)
        async let first: Void = model.finish()
        async let second: Void = model.finish()
        _ = await (first, second)
        await model.finish()

        #expect(await notifications.requests == 1)
    }

    @Test func declinedOrFailedPermissionStillFinishes() async {
        for notifications in [FakeNotificationAuthorizer(granted: false), FakeNotificationAuthorizer(fails: true)] {
            let defaults = freshDefaults()
            let model = IntroductionModel(defaults: defaults, notifications: notifications)
            await model.finish()
            #expect(!model.shouldShow)
            #expect(defaults.bool(forKey: "hasSeenIntroduction"))
        }
    }

    @Test func alreadySeenNeverAsks() async {
        let defaults = freshDefaults()
        defaults.set(true, forKey: "hasSeenIntroduction")
        let notifications = FakeNotificationAuthorizer()
        let model = IntroductionModel(defaults: defaults, notifications: notifications)

        #expect(!model.shouldShow)
        await model.finish()
        #expect(await notifications.requests == 0)
    }

    @Test func thePurchaseChoiceStartsIntoInventory() {
        let model = IntroductionModel(defaults: freshDefaults(), notifications: FakeNotificationAuthorizer())
        #expect(model.addsToInventory)
    }

    @Test func choosingOffTheListOnlyWritesTheSetting() async {
        let defaults = freshDefaults()
        let model = IntroductionModel(defaults: defaults, notifications: FakeNotificationAuthorizer(granted: false))
        model.addsToInventory = false
        #expect(defaults.object(forKey: PurchaseDefaults.key) as? Bool == false)
        await model.finish()
        #expect(!PurchaseDefaults(defaults: defaults).addsToInventory)
    }

    @Test func skipWritesNoPurchaseSetting() {
        let defaults = freshDefaults()
        let model = IntroductionModel(defaults: defaults, notifications: FakeNotificationAuthorizer())
        model.skip()
        #expect(defaults.object(forKey: PurchaseDefaults.key) == nil)
    }

    @Test func thePurchaseChoiceStartsFromTheStoredSetting() {
        let defaults = freshDefaults()
        defaults.set(false, forKey: PurchaseDefaults.key)
        #expect(!IntroductionModel(defaults: defaults, notifications: FakeNotificationAuthorizer()).addsToInventory)
    }

    // MARK: P2-10a summary choice, the third page since P1-10b (X: "Next" asks, "Not now" turns them off)

    @Test func allowedWritesTheChoiceAndMovesOn() async {
        let defaults = freshDefaults()
        let notifications = FakeNotificationAuthorizer(granted: true)
        let model = IntroductionModel(defaults: defaults, notifications: notifications)
        model.currentPage = .notifications
        #expect(model.summaryChoice == .all, "both is preselected")
        model.summaryChoice = .daily
        await model.allowNotifications()

        #expect(await notifications.requests == 1)
        #expect(model.currentPage == .stores)
        #expect(model.shouldShow, "the store page is still ahead")
        #expect(defaults.object(forKey: NotificationPreferences.dailyKey) as? Bool == true)
        #expect(defaults.object(forKey: NotificationPreferences.weeklyKey) as? Bool == false)
    }

    @Test func allowedWithBothLeavesBothOn() async {
        let defaults = freshDefaults()
        let model = IntroductionModel(defaults: defaults, notifications: FakeNotificationAuthorizer(granted: true))
        model.currentPage = .notifications
        await model.allowNotifications()
        #expect(NotificationPreferences(defaults: defaults).kinds == .all)
    }

    @Test func deniedWritesNoChoiceAndMovesOn() async {
        for notifications in [FakeNotificationAuthorizer(granted: false), FakeNotificationAuthorizer(fails: true)] {
            let defaults = freshDefaults()
            let model = IntroductionModel(defaults: defaults, notifications: notifications)
            model.currentPage = .notifications
            model.summaryChoice = .weekly
            await model.allowNotifications()
            #expect(model.currentPage == .stores)
            #expect(defaults.object(forKey: NotificationPreferences.dailyKey) == nil)
            #expect(defaults.object(forKey: NotificationPreferences.weeklyKey) == nil)
        }
    }

    @Test func swipingBackAndChangingTheChoiceRewritesIt() async {
        let defaults = freshDefaults()
        let notifications = FakeNotificationAuthorizer(granted: true)
        let model = IntroductionModel(defaults: defaults, notifications: notifications)
        model.currentPage = .notifications
        await model.allowNotifications()
        model.currentPage = .notifications
        model.summaryChoice = .weekly
        await model.allowNotifications()
        #expect(await notifications.requests == 1)
        #expect(model.currentPage == .stores)
        #expect(NotificationPreferences(defaults: defaults).kinds == .weekly)
    }

    @Test func allowNotificationsAsksOnce() async {
        let notifications = FakeNotificationAuthorizer()
        let model = IntroductionModel(defaults: freshDefaults(), notifications: notifications)
        model.currentPage = .notifications
        async let first: Void = model.allowNotifications()
        async let second: Void = model.allowNotifications()
        _ = await (first, second)
        await model.finish()
        #expect(await notifications.requests == 1, "Get started does not ask again")
    }

    @Test func notNowTurnsTheSummariesOffAndRemembersToAskLater() async {
        let defaults = freshDefaults()
        let notifications = FakeNotificationAuthorizer()
        let model = IntroductionModel(defaults: defaults, notifications: notifications)
        model.currentPage = .notifications
        model.declineNotifications()

        #expect(await notifications.requests == 0)
        #expect(model.currentPage == .stores)
        #expect(NotificationPreferences(defaults: defaults).kinds == [])
        #expect(PermissionFollowUpFlags(defaults: defaults).asksNotifications)
    }

    // MARK: P4-06 store reminders, the last page (P1-10b, X)

    @Test func getStartedTurnsStoreRemindersOnAndAsksForLocation() async {
        let defaults = freshDefaults()
        let location = FakeLocation()
        let model = IntroductionModel(defaults: defaults, notifications: FakeNotificationAuthorizer(),
                                      location: location)
        await model.finish()

        #expect(location.requests == 1)
        #expect(StoreReminderPreference(defaults: defaults).isEnabled)
        #expect(defaults.object(forKey: StoreReminderPreference.key) as? Bool == true)
        #expect(!model.shouldShow)
    }

    @Test func getStartedAsksForNotificationsWhenThirdPageSaidNotNow() async {
        let defaults = freshDefaults()
        let notifications = FakeNotificationAuthorizer()
        let model = IntroductionModel(defaults: defaults, notifications: notifications, location: FakeLocation())
        model.currentPage = .notifications
        model.declineNotifications()
        await model.finish()

        #expect(await notifications.requests == 1, "store reminders are notifications too")
        #expect(!PermissionFollowUpFlags(defaults: defaults).asksNotifications, "asked now, never again later")
        #expect(NotificationPreferences(defaults: defaults).kinds == [], "the summaries stay off")
    }

    @Test func getStartedWithoutLocationStillFinishes() async {
        let model = IntroductionModel(defaults: freshDefaults(), notifications: FakeNotificationAuthorizer())
        await model.finish()
        #expect(!model.shouldShow)
    }

    @Test func storeNotNowTurnsRemindersOffAndRemembersToAskLater() async {
        let defaults = freshDefaults()
        let location = FakeLocation()
        let notifications = FakeNotificationAuthorizer()
        let model = IntroductionModel(defaults: defaults, notifications: notifications, location: location)
        model.declineStoreReminders()

        #expect(location.requests == 0)
        #expect(await notifications.requests == 0)
        #expect(!StoreReminderPreference(defaults: defaults).isEnabled)
        #expect(PermissionFollowUpFlags(defaults: defaults).asksLocation)
        #expect(!model.shouldShow)
    }

    @Test func skipAsksNoChoiceAndLeavesTheSwitches() async {
        let defaults = freshDefaults()
        let notifications = FakeNotificationAuthorizer(granted: true)
        let location = FakeLocation()
        let model = IntroductionModel(defaults: defaults, notifications: notifications, location: location)
        model.summaryChoice = .daily
        model.skip()
        #expect(await notifications.requests == 0)
        #expect(location.requests == 0)
        #expect(defaults.object(forKey: NotificationPreferences.dailyKey) == nil)
        #expect(defaults.object(forKey: StoreReminderPreference.key) == nil)
        #expect(!PermissionFollowUpFlags(defaults: defaults).asksNotifications)
    }

    @Test func theChoiceStartsFromTheStoredSwitches() {
        let defaults = freshDefaults()
        NotificationPreferences(defaults: defaults).set(.weekly)
        #expect(IntroductionModel(defaults: defaults, notifications: FakeNotificationAuthorizer()).summaryChoice == .weekly)
        NotificationPreferences(defaults: defaults).set([])
        #expect(IntroductionModel(defaults: defaults, notifications: FakeNotificationAuthorizer()).summaryChoice == .all)
    }
}
