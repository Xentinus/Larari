import Foundation
import Testing
@testable import LarariShared

@Suite("WidgetTimelinePlanner")
struct WidgetTimelinePlannerTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest")!
        return calendar
    }()
    let spaceA = UUID(), spaceB = UUID()

    func date(_ day: Int, _ hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    func item(_ name: String, expires day: Int, space: UUID? = nil) -> ExpiringItemSnapshot {
        ExpiringItemSnapshot(id: UUID(), name: name, spaceID: space ?? spaceA, spaceName: "Otthon", expiresAt: date(day, 12))
    }

    func snapshot(_ items: [ExpiringItemSnapshot], lists: [ShoppingListSnapshot] = []) -> WidgetSnapshot {
        WidgetSnapshot(generatedAt: date(1), soonDays: 14, criticalDays: 3, expiring: items, lists: lists)
    }

    @Test func oneEntryNowAndOneAtEachOfTheNextSevenMidnights() {
        let entries = WidgetTimelinePlanner.expiringTimeline(snapshot: snapshot([]), now: date(1), calendar: calendar)
        #expect(entries.count == 1 + WidgetTimelinePlanner.lookaheadDays)
        #expect(entries[0].date == date(1))
        #expect(entries[1].date == date(2, 0))
        #expect(entries[7].date == date(8, 0))
    }

    @Test func levelsChangeAtMidnight() {
        let entries = WidgetTimelinePlanner.expiringTimeline(snapshot: snapshot([item("Joghurt", expires: 5)]),
                                                             now: date(1), calendar: calendar)
        #expect(entries[0].rows.first?.level == .soon)        // 4 days
        #expect(entries[0].rows.first?.daysLeft == 4)
        #expect(entries[1].rows.first?.level == .critical)    // 3 days
        #expect(entries[5].rows.first?.level == .expired)     // Oct 6
    }

    @Test func itemsEnterTheWindowOnTheirDay() {
        let entries = WidgetTimelinePlanner.expiringTimeline(snapshot: snapshot([item("Sajt", expires: 17)]),
                                                             now: date(1), calendar: calendar)
        #expect(entries[0].rows.isEmpty)                      // 16 days
        #expect(entries[2].rows.map(\.item.name) == ["Sajt"]) // Oct 3: 14 days
    }

    @Test func mostSevereFirstThenEarliest() {
        let content = WidgetTimelinePlanner.expiringContent(
            snapshot: snapshot([item("Tej", expires: 10), item("Sonka", expires: 1), item("Vaj", expires: 3),
                                item("Kefir", expires: 2)]),
            at: date(2), calendar: calendar)
        #expect(content.rows.map(\.item.name) == ["Sonka", "Kefir", "Vaj", "Tej"])
        #expect(content.rows.map(\.level) == [.expired, .critical, .critical, .soon])
    }

    @Test func theSpaceWithMostItemsIsTheTapTarget() {
        let content = WidgetTimelinePlanner.expiringContent(
            snapshot: snapshot([item("Tej", expires: 3, space: spaceB), item("Vaj", expires: 4),
                                item("Kefir", expires: 5)]),
            at: date(1), calendar: calendar)
        #expect(content.topSpaceID == spaceA)
    }

    @Test func withoutASnapshotTheWidgetSaysSo() {
        let entries = WidgetTimelinePlanner.expiringTimeline(snapshot: nil, now: date(1), calendar: calendar)
        #expect(entries.count == 1)
        #expect(!entries[0].hasSnapshot)
        #expect(entries[0].rows.isEmpty)
    }

    @Test func reloadsAtTheNextSevenOClock() {
        #expect(WidgetTimelinePlanner.nextReload(after: date(1, 6), calendar: calendar) == date(1, 7))
        #expect(WidgetTimelinePlanner.nextReload(after: date(1, 7), calendar: calendar) == date(2, 7))
        #expect(WidgetTimelinePlanner.nextReload(after: date(1, 22), calendar: calendar) == date(2, 7))
    }

    @Test func theChosenListOrTheFirstWithItems() {
        func list(_ name: String, remaining: Int) -> ShoppingListSnapshot {
            ShoppingListSnapshot(id: UUID(), spaceID: spaceA, spaceName: "Otthon", name: name, colorHex: nil,
                                 canEdit: true, remainingCount: remaining, items: [])
        }
        let empty = list("Üres", remaining: 0), weekly = list("Heti", remaining: 3)
        let snapshot = snapshot([], lists: [empty, weekly])
        #expect(WidgetTimelinePlanner.list(in: snapshot, id: empty.id) == empty)
        #expect(WidgetTimelinePlanner.list(in: snapshot, id: nil) == weekly)
        #expect(WidgetTimelinePlanner.list(in: snapshot, id: UUID()) == weekly)     // deleted list: fall back
        #expect(WidgetTimelinePlanner.list(in: nil, id: nil) == nil)
    }
}
