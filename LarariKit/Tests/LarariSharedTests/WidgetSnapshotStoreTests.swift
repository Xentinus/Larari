import Foundation
import Testing
@testable import LarariShared

@Suite("WidgetSnapshotStore")
struct WidgetSnapshotStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "larari-widgets-\(UUID().uuidString)",
                                                                     directoryHint: .isDirectory)
    var store: WidgetSnapshotStore { WidgetSnapshotStore(directory: directory) }
    let listID = UUID()
    let milkID = UUID()

    func snapshot(generatedAt: Date = Date(timeIntervalSince1970: 1_790_000_000)) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: generatedAt, soonDays: 14, criticalDays: 3,
            expiring: [ExpiringItemSnapshot(id: UUID(), name: "Tej", spaceID: UUID(), spaceName: "Otthon",
                                            expiresAt: Date(timeIntervalSince1970: 1_790_086_400))],
            lists: [ShoppingListSnapshot(id: listID, spaceID: UUID(), spaceName: "Otthon", name: "Heti", colorHex: nil,
                                         canEdit: true, remainingCount: 2,
                                         items: [ShoppingItemSnapshot(id: milkID, name: "Tej", quantityText: "2 × 1 l"),
                                                 ShoppingItemSnapshot(id: UUID(), name: "Kenyér", quantityText: "1 db")])])
    }

    @Test func roundTrips() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let written = snapshot()
        try store.write(written)
        #expect(store.read() == written)
    }

    @Test func missingOrBrokenFilesReadAsNothing() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(store.read() == nil)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: store.fileURL)
        #expect(store.read() == nil)
    }

    @Test func anotherSchemaVersionReadsAsNothing() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        var future = snapshot()
        future.schemaVersion = WidgetSnapshot.currentSchemaVersion + 1
        try store.write(future)
        #expect(store.read() == nil)
    }

    @Test func writesReplaceTheFileAtomically() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try store.write(snapshot())
        try store.write(snapshot(generatedAt: Date(timeIntervalSince1970: 1_790_000_600)))
        #expect(store.read()?.generatedAt == Date(timeIntervalSince1970: 1_790_000_600))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == [WidgetSnapshotStore.fileName])
    }

    @Test func markTickedRemovesTheRowAndCountsDown() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try store.write(snapshot())
        try store.markTicked(itemID: milkID, listID: listID)
        let list = try #require(store.read()?.lists.first)
        #expect(list.items.map(\.name) == ["Kenyér"])
        #expect(list.remainingCount == 1)

        try store.markTicked(itemID: milkID, listID: listID)          // twice: no double count
        #expect(store.read()?.lists.first?.remainingCount == 1)
        try store.markTicked(itemID: UUID(), listID: UUID())          // unknown: no change
        #expect(store.read()?.lists.first?.remainingCount == 1)
    }
}
