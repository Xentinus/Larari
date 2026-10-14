import Foundation

/// The Settings ▸ Larari "Store reminders" switch (P4-06), also answered on the introduction's last page (P1-10b).
/// A missing value means on. `@MainActor` like `NotificationPreferences`, since `UserDefaults` is not `Sendable` on
/// this SDK.
@MainActor
public struct StoreReminderPreference {
    public static let key = "storeRemindersEnabled"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// `bool(forKey:)` also reads "NO" from a launch argument; only a missing value means on.
    public var isEnabled: Bool {
        get { defaults.object(forKey: Self.key) == nil ? true : defaults.bool(forKey: Self.key) }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }
}
