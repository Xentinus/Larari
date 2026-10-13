import Foundation

/// Whether a purchase goes into inventory by default (P4-07): the purchase sheet's "Add to inventory" switch starts
/// from it, and the Shopping list widget's tick follows it. Set in Settings ▸ Larari ▸ Shopping and asked once in the
/// introduction; per device. A missing value means on, the behaviour before the setting existed.
@MainActor
public struct PurchaseDefaults {
    public static let key = "purchaseAddsToInventory"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var addsToInventory: Bool {
        // `bool(forKey:)` also reads "NO" from a launch argument; only a missing value means on.
        get { defaults.object(forKey: Self.key) == nil ? true : defaults.bool(forKey: Self.key) }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }
}
