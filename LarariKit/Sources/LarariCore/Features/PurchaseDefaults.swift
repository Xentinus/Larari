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
        get { defaults.object(forKey: Self.key) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }
}
