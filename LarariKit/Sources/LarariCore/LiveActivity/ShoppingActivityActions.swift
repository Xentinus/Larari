import CoreData
import Foundation

/// The Lock Screen tick (N-04 D3 1): every list item of the row is bought whole, into inventory at the product's
/// usual storage location, at the item's own store, without price or expiry, like the purchase sheet's defaults.
/// Committed at once: the Lock Screen has no undo toast.
@MainActor
public enum ShoppingActivityActions {
    public static let addsToInventory = true

    /// Returns how many list items were bought. Items that are gone, already bought or waiting in an undo window are
    /// skipped; a read-only household throws `ServiceError.readOnlySpace` before anything changes.
    @discardableResult
    public static func purchase(itemIDs: [UUID], shopping: ShoppingService, inventory: InventoryService,
                                pending: PendingDeletions) throws -> Int {
        var bought = 0
        for id in itemIDs {
            guard let item = try shopping.context.fetchEntities(
                ShoppingListItem.self, where: NSPredicate(format: "publicId == %@", id as NSUUID)).first,
                  !item.isGone, !item.isPurchased, !pending.contains(item.publicId) else { continue }
            let location = ShoppingPurchase.defaultStorageLocation(for: item.product, inventory: inventory)
            let details = PurchaseDetails(quantity: item.quantity, storeID: item.shoppingLocation?.publicId,
                                          keepRemainder: false,
                                          lots: [LotDetails(quantity: item.quantity, storageLocationID: location?.publicId)],
                                          addToInventory: addsToInventory)
            let action = try ShoppingPurchase.purchase(item, details: details, shopping: shopping, inventory: inventory,
                                                       pending: pending)
            try action.commit()
            bought += 1
        }
        return bought
    }

    /// Whether any of the items lives in `store` (R14 I2): the app passes the shared store, whose joined households
    /// can only be bought into once the share-permission cache is filled. Unknown ids involve nothing.
    public static func involvesStore(_ store: NSPersistentStore, itemIDs: [UUID], context: NSManagedObjectContext) -> Bool {
        guard !itemIDs.isEmpty, let items = try? context.fetchEntities(
            ShoppingListItem.self, where: NSPredicate(format: "publicId IN %@", itemIDs.map { $0 as NSUUID }))
        else { return false }
        return items.contains { $0.objectID.persistentStore === store }
    }
}
