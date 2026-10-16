import CoreData
import Foundation
import Testing
@testable import LarariCore

@MainActor
@Suite("BadgeCounter content (P2-10b)")
struct BadgeCounterTests {
    private func count(_ content: BadgeContent, _ env: ServiceTestEnvironment) throws -> Int {
        try BadgeCounter.count(content, in: env.context, now: ServiceTestEnvironment.fixedNow,
                               calendar: ServiceTestEnvironment.budapest)
    }

    private func shopping(_ env: ServiceTestEnvironment) -> ShoppingService {
        ShoppingService(spaceStore: env.spaceStore, context: env.context, userRecordName: ServiceTestEnvironment.user,
                        now: { ServiceTestEnvironment.fixedNow })
    }

    /// Stock expiring on each of `offsets` (days from today), plus one undated and one used-up expired item.
    private func stockFixture(_ env: ServiceTestEnvironment, offsets: [Int]) async throws {
        let milk = try await env.makeProduct("Milk")
        for offset in offsets { try env.stock(milk, 1, expiresInDays: offset) }
        try env.stock(milk, 1)
        let finished = try env.stock(milk, 1, expiresInDays: -2)
        try env.inventoryService().markUsedUp(finished)
    }

    @Test func soonCountsExpiredAndTheNextFourteenDays() async throws {
        let env = try ServiceTestEnvironment()
        try await stockFixture(env, offsets: [-1, 0, 3, 4, 14, 15])
        #expect(try count(BadgeContent(expiry: .soon, includesShopping: false), env) == 5)
    }

    @Test func criticalCountsExpiredAndTheNextThreeDays() async throws {
        let env = try ServiceTestEnvironment()
        try await stockFixture(env, offsets: [-1, 0, 3, 4, 14, 15])
        #expect(try count(BadgeContent(expiry: .critical, includesShopping: false), env) == 3)
    }

    @Test func expiredCountsOnlyBeforeToday() async throws {
        let env = try ServiceTestEnvironment()
        try await stockFixture(env, offsets: [-1, 0, 3, 4, 14, 15])
        #expect(try count(BadgeContent(expiry: .expired, includesShopping: false), env) == 1)
    }

    @Test func theOldCountIsTheStandardContent() async throws {
        let env = try ServiceTestEnvironment()
        try await stockFixture(env, offsets: [-1, 0, 3, 4, 14, 15])
        let old = try BadgeCounter.count(in: env.context, now: ServiceTestEnvironment.fixedNow,
                                         calendar: ServiceTestEnvironment.budapest)
        #expect(old == (try count(.standard, env)))
    }

    @Test func shoppingCountsUnpurchasedItemsInEveryList() async throws {
        let env = try ServiceTestEnvironment()
        let home = try env.makeHousehold()
        let service = shopping(env)
        let weekly = try service.createList(name: "Heti", in: env.personal)
        let party = try service.createList(name: "Buli", in: home)
        try service.addItem(to: weekly, customName: "Kenyér")
        try service.addItem(to: party, customName: "Chips")
        let bought = try service.addItem(to: weekly, customName: "Tej")
        try service.togglePurchased(bought)
        let orphan = try service.addItem(to: weekly, customName: "Árva")
        orphan.shoppingList = nil
        try env.context.save()
        try env.stock(try await env.makeProduct("Milk"), 1, expiresInDays: -1)   // inventory does not count here

        #expect(try count(BadgeContent(expiry: .off, includesShopping: true), env) == 2)
    }

    @Test func purchaseAndUndoMoveTheShoppingCount() throws {
        let env = try ServiceTestEnvironment()
        let service = shopping(env)
        let list = try service.createList(name: "Heti", in: env.personal)
        let item = try service.addItem(to: list, customName: "Kenyér")
        let content = BadgeContent(expiry: .off, includesShopping: true)
        #expect(try count(content, env) == 1)
        try service.togglePurchased(item)
        #expect(try count(content, env) == 0)
        try service.togglePurchased(item)
        #expect(try count(content, env) == 1)
    }

    @Test func bothPartsAddUp() async throws {
        let env = try ServiceTestEnvironment()
        try await stockFixture(env, offsets: [-1, 0, 3, 4, 14, 15])
        let service = shopping(env)
        let list = try service.createList(name: "Heti", in: env.personal)
        for name in ["Kenyér", "Tej", "Sajt"] { try service.addItem(to: list, customName: name) }
        #expect(try count(BadgeContent(expiry: .soon, includesShopping: true), env) == 5 + 3)
        #expect(try count(BadgeContent(expiry: .expired, includesShopping: true), env) == 1 + 3)
    }

    @Test func bothPartsOffCountNothing() async throws {
        let env = try ServiceTestEnvironment()
        try await stockFixture(env, offsets: [-1, 0])
        let list = try shopping(env).createList(name: "Heti", in: env.personal)
        try shopping(env).addItem(to: list, customName: "Kenyér")
        #expect(try count(BadgeContent(expiry: .off, includesShopping: false), env) == 0)
    }

    @Test func shoppingSwitchOffIgnoresTheList() async throws {
        let env = try ServiceTestEnvironment()
        try await stockFixture(env, offsets: [-1])
        let list = try shopping(env).createList(name: "Heti", in: env.personal)
        try shopping(env).addItem(to: list, customName: "Kenyér")
        #expect(try count(BadgeContent(expiry: .soon, includesShopping: false), env) == 1)
    }
}
