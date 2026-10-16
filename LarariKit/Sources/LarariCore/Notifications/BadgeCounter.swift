import CoreData
import Foundation

/// Reads open items across every store in the context (all spaces).
@MainActor
public enum BadgeCounter {
    /// The app icon badge (P2-10b): the chosen expiring items, plus the unpurchased shopping list items when the
    /// shopping part is on. Every space counts.
    public static func count(_ content: BadgeContent, in context: NSManagedObjectContext, now: Date,
                             calendar: Calendar) throws -> Int {
        let expiring = try expiringCount(content.expiry, in: context, now: now, calendar: calendar)
        let shopping = content.includesShopping ? try unpurchasedShoppingCount(in: context) : 0
        return expiring + shopping
    }

    /// Expired and within 14 days (soon + critical + expired). The Home Screen quick action's count, and the badge
    /// with the default settings.
    public static func count(in context: NSManagedObjectContext, now: Date, calendar: Calendar) throws -> Int {
        try expiringCount(.soon, in: context, now: now, calendar: calendar)
    }

    /// Open items expiring before the start of the mode's last day + 1.
    private static func expiringCount(_ mode: ExpiryBadgeMode, in context: NSManagedObjectContext, now: Date,
                                      calendar: Calendar) throws -> Int {
        let today = calendar.startOfDay(for: now)
        let days: Int
        switch mode {
        case .soon: days = ExpirationStatus.soonDays + 1
        case .critical: days = ExpirationStatus.criticalDays + 1
        case .expired: days = 0
        case .off: return 0
        }
        guard let limit = calendar.date(byAdding: .day, value: days, to: today) else { return 0 }
        return try context.countEntities(
            InventoryItem.self,
            where: NSPredicate(format: "isFullyConsumed == NO AND expiresAt != nil AND expiresAt < %@", limit as NSDate))
    }

    /// Items still to buy, in every list of every space. An item without a list is an orphan from a partial
    /// import and does not count.
    private static func unpurchasedShoppingCount(in context: NSManagedObjectContext) throws -> Int {
        try context.countEntities(ShoppingListItem.self,
                                  where: NSPredicate(format: "isPurchased == NO AND shoppingList != nil"))
    }

    /// Open items expiring from today through the horizon plus one week (the last Monday's window).
    public static func snapshots(in context: NSManagedObjectContext, now: Date, calendar: Calendar,
                                 horizonDays: Int = NotificationPlanner.defaultHorizonDays) throws -> [ExpirySnapshot] {
        let today = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: horizonDays + 7, to: today) else { return [] }
        let items = try context.fetchEntities(
            InventoryItem.self,
            where: NSPredicate(format: "isFullyConsumed == NO AND expiresAt >= %@ AND expiresAt < %@",
                               today as NSDate, end as NSDate))
        return items.compactMap { item in
            guard let expiresAt = item.expiresAt, let product = item.product else { return nil }
            return ExpirySnapshot(id: item.publicId, name: product.name, expiresAt: expiresAt,
                                  spaceName: product.space?.name ?? "", spaceID: product.space?.publicId)
        }
    }
}
