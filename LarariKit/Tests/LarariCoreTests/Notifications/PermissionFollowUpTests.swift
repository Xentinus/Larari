import Foundation
import Testing
@testable import LarariCore

/// P1-10b (2A): "Not now" in the introduction, then a switch turned on in Settings ▸ Larari, asks for the permission
/// once on the next foreground.
@MainActor
@Suite("PermissionFollowUp")
struct PermissionFollowUpTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "PermissionFollowUpTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func followUp(_ defaults: UserDefaults, notifications: FakeNotificationAuthorizer,
                          location: FakeLocation? = nil) -> PermissionFollowUp {
        PermissionFollowUp(defaults: defaults, notifications: notifications, location: location)
    }

    @Test func nothingArmedAsksNothing() async {
        let defaults = freshDefaults()
        let notifications = FakeNotificationAuthorizer()
        let location = FakeLocation()
        await followUp(defaults, notifications: notifications, location: location).check()
        #expect(await notifications.requests == 0)
        #expect(location.requests == 0)
    }

    @Test func armedButStillOffWaits() async {
        let defaults = freshDefaults()
        NotificationPreferences(defaults: defaults).set([])
        StoreReminderPreference(defaults: defaults).isEnabled = false
        PermissionFollowUpFlags(defaults: defaults).asksNotifications = true
        let notifications = FakeNotificationAuthorizer()
        await followUp(defaults, notifications: notifications).check()
        #expect(await notifications.requests == 0)
        #expect(PermissionFollowUpFlags(defaults: defaults).asksNotifications)
    }

    @Test func aSummaryTurnedOnAsksForNotificationsOnce() async {
        let defaults = freshDefaults()
        NotificationPreferences(defaults: defaults).set(.daily)
        StoreReminderPreference(defaults: defaults).isEnabled = false
        PermissionFollowUpFlags(defaults: defaults).asksNotifications = true
        let notifications = FakeNotificationAuthorizer()
        let followUp = followUp(defaults, notifications: notifications)
        await followUp.check()
        await followUp.check()
        #expect(await notifications.requests == 1)
        #expect(!PermissionFollowUpFlags(defaults: defaults).asksNotifications)
    }

    @Test func storeRemindersTurnedOnAskForNotificationsToo() async {
        let defaults = freshDefaults()
        NotificationPreferences(defaults: defaults).set([])
        StoreReminderPreference(defaults: defaults).isEnabled = true
        PermissionFollowUpFlags(defaults: defaults).asksNotifications = true
        let notifications = FakeNotificationAuthorizer()
        await followUp(defaults, notifications: notifications).check()
        #expect(await notifications.requests == 1)
    }

    @Test func storeRemindersTurnedOnAskForLocationOnce() async {
        let defaults = freshDefaults()
        StoreReminderPreference(defaults: defaults).isEnabled = true
        PermissionFollowUpFlags(defaults: defaults).asksLocation = true
        let location = FakeLocation()
        let followUp = followUp(defaults, notifications: FakeNotificationAuthorizer(), location: location)
        await followUp.check()
        await followUp.check()
        #expect(location.requests == 1)
        #expect(!PermissionFollowUpFlags(defaults: defaults).asksLocation)
    }

    @Test func storeRemindersStillOffAskNoLocation() async {
        let defaults = freshDefaults()
        StoreReminderPreference(defaults: defaults).isEnabled = false
        PermissionFollowUpFlags(defaults: defaults).asksLocation = true
        let location = FakeLocation()
        await followUp(defaults, notifications: FakeNotificationAuthorizer(), location: location).check()
        #expect(location.requests == 0)
        #expect(PermissionFollowUpFlags(defaults: defaults).asksLocation)
    }

    @Test func overlappingChecksAskOnce() async {
        let defaults = freshDefaults()
        NotificationPreferences(defaults: defaults).set(.all)
        PermissionFollowUpFlags(defaults: defaults).asksNotifications = true
        let notifications = FakeNotificationAuthorizer()
        let followUp = followUp(defaults, notifications: notifications)
        async let first: Void = followUp.check()
        async let second: Void = followUp.check()
        _ = await (first, second)
        #expect(await notifications.requests == 1)
    }

    @Test func storeReminderPreferenceMissingMeansOn() {
        let defaults = freshDefaults()
        #expect(StoreReminderPreference(defaults: defaults).isEnabled)
        defaults.set("NO", forKey: StoreReminderPreference.key)        // as a launch argument arrives
        #expect(!StoreReminderPreference(defaults: defaults).isEnabled)
    }
}
