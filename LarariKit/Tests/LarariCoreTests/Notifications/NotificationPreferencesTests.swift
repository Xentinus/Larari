import Foundation
import Testing
@testable import LarariCore

@MainActor
@Suite("NotificationPreferences")
struct NotificationPreferencesTests {
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "NotificationPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    @Test func missingValuesMeanBoth() {
        withDefaults { #expect(NotificationPreferences(defaults: $0).kinds == .all) }
    }

    @Test func eachSwitchOffDropsItsKind() {
        withDefaults { defaults in
            defaults.set(false, forKey: NotificationPreferences.dailyKey)
            #expect(NotificationPreferences(defaults: defaults).kinds == .weekly)
            defaults.set(true, forKey: NotificationPreferences.dailyKey)
            defaults.set(false, forKey: NotificationPreferences.weeklyKey)
            #expect(NotificationPreferences(defaults: defaults).kinds == .daily)
        }
    }

    @Test func aLaunchArgumentStringIsRead() {
        withDefaults { defaults in
            defaults.set("NO", forKey: NotificationPreferences.weeklyKey)
            #expect(NotificationPreferences(defaults: defaults).kinds == .daily)
        }
    }

    @Test func setRoundTrips() {
        withDefaults { defaults in
            let preferences = NotificationPreferences(defaults: defaults)
            for kinds in [NotificationKinds.daily, .weekly, .all, []] {
                preferences.set(kinds)
                #expect(preferences.kinds == kinds)
            }
        }
    }

    // MARK: Badge (P2-10b)

    @Test func missingBadgeValuesMeanTodaysBadge() {
        withDefaults { #expect(NotificationPreferences(defaults: $0).badge == .standard) }
        #expect(BadgeContent.standard == BadgeContent(expiry: .soon, includesShopping: false))
    }

    @Test func unknownExpiryValueMeansSoon() {
        withDefaults { defaults in
            defaults.set("week", forKey: NotificationPreferences.badgeExpiryKey)
            #expect(NotificationPreferences(defaults: defaults).badge.expiry == .soon)
        }
    }

    @Test func everyExpiryValueIsRead() {
        withDefaults { defaults in
            for mode in ExpiryBadgeMode.allCases {
                defaults.set(mode.rawValue, forKey: NotificationPreferences.badgeExpiryKey)
                #expect(NotificationPreferences(defaults: defaults).badge.expiry == mode)
            }
        }
    }

    @Test func shoppingSwitchIsRead() {
        withDefaults { defaults in
            defaults.set(true, forKey: NotificationPreferences.badgeShoppingKey)
            #expect(NotificationPreferences(defaults: defaults).badge.includesShopping)
            defaults.set(false, forKey: NotificationPreferences.badgeShoppingKey)
            #expect(!NotificationPreferences(defaults: defaults).badge.includesShopping)
        }
    }

    @Test func shoppingSwitchReadsALaunchArgumentString() {
        withDefaults { defaults in
            defaults.set("YES", forKey: NotificationPreferences.badgeShoppingKey)
            #expect(NotificationPreferences(defaults: defaults).badge.includesShopping)
        }
    }
}
