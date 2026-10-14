import Foundation

/// Which summaries the planner makes: the 07:00 daily summary, the Monday overview, or both.
public struct NotificationKinds: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let daily = NotificationKinds(rawValue: 1 << 0)
    public static let weekly = NotificationKinds(rawValue: 1 << 1)
    public static let all: NotificationKinds = [.daily, .weekly]
}

/// The Settings ▸ Larari ▸ Notifications switches (P2-10a), first set by the choice after "Get started". Per device.
/// A missing value means on, the behaviour before the switches existed. `@MainActor` like `PurchaseDefaults`, since
/// `UserDefaults` is not `Sendable` on this SDK.
@MainActor
public struct NotificationPreferences {
    public static let dailyKey = "dailySummaryEnabled"
    public static let weeklyKey = "weeklySummaryEnabled"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var kinds: NotificationKinds {
        var kinds: NotificationKinds = []
        if isOn(Self.dailyKey) { kinds.insert(.daily) }
        if isOn(Self.weeklyKey) { kinds.insert(.weekly) }
        return kinds
    }

    public func set(_ kinds: NotificationKinds) {
        defaults.set(kinds.contains(.daily), forKey: Self.dailyKey)
        defaults.set(kinds.contains(.weekly), forKey: Self.weeklyKey)
    }

    /// `bool(forKey:)` also reads "NO" from a launch argument; only a missing value means on.
    private func isOn(_ key: String) -> Bool {
        defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }
}
