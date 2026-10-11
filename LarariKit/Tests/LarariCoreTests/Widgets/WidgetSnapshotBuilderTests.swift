import CoreData
import Foundation
import LarariShared
import Testing
@testable import LarariCore

@MainActor
@Suite("WidgetSnapshotBuilder")
struct WidgetSnapshotBuilderTests {
    let stack: ShoppingTestStack
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest")!
        return calendar
    }()
    let day: TimeInterval = 86_400
    init() throws { stack = try ShoppingTestStack() }

    func build(shopping: ShoppingService? = nil) throws -> WidgetSnapshot {
        try WidgetSnapshotBuilder.build(context: stack.context, spaceStore: stack.spaceStore,
                                        shopping: shopping ?? stack.service, pending: stack.pending,
                                        now: stack.now.date, calendar: calendar, locale: Locale(identifier: "hu_HU"))
    }

    @discardableResult
    func stock(_ name: String, expiresIn days: Double?) throws -> InventoryItem {
        let product = try stack.makeProduct(name)
        return try stack.inventory.addStock(product: product, quantity: 1, unit: .piece,
                                            expiresAt: days.map { stack.now.date.addingTimeInterval($0 * day) },
                                            purchasedAt: nil, price: nil, currency: nil, storageLocation: nil,
                                            shoppingLocation: nil)
    }

    @Test func expiringHoldsOpenItemsUpToTheLookAheadExpiredIncluded() throws {
        try stock("Tej", expiresIn: 2)
        try stock("Sajt", expiresIn: 20)            // inside 14 + 7 days
        try stock("Konzerv", expiresIn: 60)         // outside
        try stock("Sonka", expiresIn: -3)           // expired
        try stock("Só", expiresIn: nil)             // no date
        let used = try stock("Kefir", expiresIn: 1)
        used.isFullyConsumed = true
        try stack.context.save()

        let snapshot = try build()

        #expect(snapshot.expiring.map(\.name) == ["Sonka", "Tej", "Sajt"])
        #expect(snapshot.expiring.first?.spaceID == stack.space.publicId)
        #expect(snapshot.soonDays == ExpirationStatus.soonDays)
        #expect(snapshot.criticalDays == ExpirationStatus.criticalDays)
        #expect(snapshot.schemaVersion == WidgetSnapshot.currentSchemaVersion)
        #expect(snapshot.generatedAt == stack.now.date)
    }

    @Test func pendingDeletionsAreLeftOut() throws {
        let milk = try stock("Tej", expiresIn: 2)
        stack.pending.hide(milk.publicId)
        #expect(try build().expiring.isEmpty)
    }

    @Test func listsCarryTheFirstOpenItemsAndTheCount() throws {
        let list = try stack.service.createList(name: "Heti", in: stack.space)
        for index in 1...10 { try stack.service.addItem(to: list, customName: "Tétel \(index)", quantity: 2) }
        let items = try stack.service.unpurchasedItems(in: list)
        stack.pending.hide(items[0].publicId)

        let snapshot = try build()

        let entry = try #require(snapshot.lists.first)
        #expect(entry.id == list.publicId)
        #expect(entry.spaceID == stack.space.publicId)
        #expect(entry.name == "Heti")
        #expect(entry.canEdit)
        #expect(entry.remainingCount == 9)
        #expect(entry.items.count == WidgetSnapshotBuilder.maxItemsPerList)
        #expect(entry.items.first?.name == "Tétel 2")
        #expect(entry.items.first?.quantityText == Quantity.format(2, unit: .piece, locale: Locale(identifier: "hu_HU")))
    }

    @Test func readOnlyListsHaveNoTicks() throws {
        try stack.service.createList(name: "Heti", in: stack.space)
        let readOnly = ShoppingService(spaceStore: stack.spaceStore, context: stack.context,
                                       userRecordName: stack.user, canEdit: { _ in false })
        #expect(try build(shopping: readOnly).lists.first?.canEdit == false)
    }
}
