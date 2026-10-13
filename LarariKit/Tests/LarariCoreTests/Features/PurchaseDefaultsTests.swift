import CoreData
import Foundation
import Testing
@testable import LarariCore

@MainActor
@Suite("Purchase defaults")
struct PurchaseDefaultsTests {
    let defaults: UserDefaults
    init() throws { defaults = try #require(UserDefaults(suiteName: "test.purchaseDefaults.\(UUID().uuidString)")) }

    @Test func aMissingValueMeansIntoInventory() {
        #expect(PurchaseDefaults(defaults: defaults).addsToInventory)
    }

    @Test func readsTheStoredSwitch() {
        defaults.set(false, forKey: PurchaseDefaults.key)
        #expect(!PurchaseDefaults(defaults: defaults).addsToInventory)
        defaults.set(true, forKey: PurchaseDefaults.key)
        #expect(PurchaseDefaults(defaults: defaults).addsToInventory)
    }

    /// A launch argument (`-purchaseAddsToInventory NO`) arrives as a string in the argument domain.
    @Test func readsAStringFromTheArgumentDomain() {
        defaults.set("NO", forKey: PurchaseDefaults.key)
        #expect(!PurchaseDefaults(defaults: defaults).addsToInventory)
        defaults.set("YES", forKey: PurchaseDefaults.key)
        #expect(PurchaseDefaults(defaults: defaults).addsToInventory)
    }

    @Test func writesTheSwitch() {
        let purchase = PurchaseDefaults(defaults: defaults)
        purchase.addsToInventory = false
        #expect(defaults.object(forKey: "purchaseAddsToInventory") as? Bool == false)
        #expect(!PurchaseDefaults(defaults: defaults).addsToInventory)
    }

    @Test func theContainerHandsTheSettingToTheLockScreenTick() async throws {
        let env = try ServiceTestEnvironment()
        let purchase = PurchaseDefaults(defaults: defaults)
        purchase.addsToInventory = false
        let services = ServiceContainer(spaceStore: env.spaceStore, context: env.context,
                                        userRecordName: ServiceTestEnvironment.user, purchaseDefaults: purchase)
        #expect(!services.purchaseDefaults.addsToInventory)
        let list = try services.shopping.createList(name: "Heti", in: env.personal)
        let item = try services.shopping.addItem(to: list, customName: "Tej")
        await services.shoppingActivity.tick(itemIDs: [item.publicId])
        #expect(try services.shopping.unpurchasedItems(in: list).isEmpty)
        #expect(try env.context.count(for: NSFetchRequest<InventoryItem>(entityName: "InventoryItem")) == 0)
    }
}
