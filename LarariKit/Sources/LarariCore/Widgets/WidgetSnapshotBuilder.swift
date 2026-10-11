import CoreData
import Foundation
import LarariShared

/// Turns the store into the widgets' snapshot (N-05): every space's open items expiring before the 14-day window plus
/// the timeline's 7-day look-ahead (expired ones included), and every shopping list's first open items. Items whose
/// widget tick is still queued (`queuedItemIDs`) stay out, as the extension already removed them from the widget.
@MainActor
public enum WidgetSnapshotBuilder {
    public static let maxExpiring = 40
    public static let maxItemsPerList = 8

    public static func build(context: NSManagedObjectContext, spaceStore: SpaceStore, shopping: ShoppingService,
                             pending: PendingDeletions, now: Date, calendar: Calendar, locale: Locale,
                             queuedItemIDs: Set<UUID> = []) throws -> WidgetSnapshot {
        WidgetSnapshot(generatedAt: now, soonDays: ExpirationStatus.soonDays, criticalDays: ExpirationStatus.criticalDays,
                       expiring: try expiring(in: context, pending: pending, now: now, calendar: calendar),
                       lists: try lists(spaceStore: spaceStore, shopping: shopping, pending: pending, locale: locale,
                                        queuedItemIDs: queuedItemIDs))
    }

    private static func expiring(in context: NSManagedObjectContext, pending: PendingDeletions, now: Date,
                                 calendar: Calendar) throws -> [ExpiringItemSnapshot] {
        let days = ExpirationStatus.soonDays + WidgetTimelinePlanner.lookaheadDays + 1
        guard let limit = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now)) else { return [] }
        let items = try context.fetchEntities(
            InventoryItem.self,
            where: NSPredicate(format: "isFullyConsumed == NO AND expiresAt != nil AND expiresAt < %@", limit as NSDate),
            sortedBy: [NSSortDescriptor(key: "expiresAt", ascending: true), NSSortDescriptor(key: "publicId", ascending: true)])
        return items
            .compactMap { item in
                // A product in its undo window hides its stock too (the app's `InventoryModel.sections` does the same).
                guard !pending.contains(item.publicId), let expiresAt = item.expiresAt, let product = item.product,
                      !product.isGone, !pending.contains(product.publicId) else { return nil }
                return ExpiringItemSnapshot(id: item.publicId, name: product.name, spaceID: product.space?.publicId,
                                            spaceName: product.space?.name ?? "", expiresAt: expiresAt)
            }
            .prefix(maxExpiring)
            .map { $0 }
    }

    private static func lists(spaceStore: SpaceStore, shopping: ShoppingService, pending: PendingDeletions,
                              locale: Locale, queuedItemIDs: Set<UUID>) throws -> [ShoppingListSnapshot] {
        try spaceStore.allSpaces().flatMap { space in
            try shopping.lists(in: space).map { list in
                let open = try shopping.unpurchasedItems(in: list).filter { item in
                    !pending.contains(item.publicId) && !queuedItemIDs.contains(item.publicId)
                        && !(item.product.map { pending.contains($0.publicId) } ?? false)
                }
                return ShoppingListSnapshot(
                    id: list.publicId, spaceID: space.publicId, spaceName: space.name, name: list.name,
                    colorHex: list.color, canEdit: shopping.canEdit(space), remainingCount: open.count,
                    items: open.prefix(maxItemsPerList).map { item in
                        ShoppingItemSnapshot(id: item.publicId, name: ShoppingService.displayName(of: item),
                                             quantityText: Quantity.format(item.quantity, unit: item.unit, locale: locale))
                    })
            }
        }
    }
}
