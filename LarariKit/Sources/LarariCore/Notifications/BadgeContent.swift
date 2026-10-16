import Foundation

/// Which expiring items the app icon badge counts (Settings ▸ Larari ▸ Ikonjelvény ▸ Lejáró tételek, P2-10b).
/// Raw values are the Settings.bundle `Values`.
public enum ExpiryBadgeMode: String, Sendable, CaseIterable {
    /// Expired, and expiring within `ExpirationStatus.soonDays`. The badge before P2-10b.
    case soon
    /// Expired, and expiring within `ExpirationStatus.criticalDays`.
    case critical
    /// Expired only; an item expiring today is not expired yet.
    case expired
    /// No expiring items.
    case off
}

/// What the app icon badge adds up: the chosen expiring items, plus the unpurchased shopping list items when
/// `includesShopping` is on. Both parts count every space.
public struct BadgeContent: Sendable, Hashable {
    public var expiry: ExpiryBadgeMode
    public var includesShopping: Bool

    public init(expiry: ExpiryBadgeMode, includesShopping: Bool) {
        self.expiry = expiry
        self.includesShopping = includesShopping
    }

    /// The defaults, which are the badge before the setting existed.
    public static let standard = BadgeContent(expiry: .soon, includesShopping: false)
}
