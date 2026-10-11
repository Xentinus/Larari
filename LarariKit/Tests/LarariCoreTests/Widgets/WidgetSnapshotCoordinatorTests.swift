import CoreData
import Foundation
import LarariShared
import Testing
@testable import LarariCore

@MainActor
@Suite("WidgetSnapshotCoordinator")
struct WidgetSnapshotCoordinatorTests {
    final class Reloads { var count = 0 }

    let stack: ShoppingTestStack
    let directory = FileManager.default.temporaryDirectory.appending(path: "larari-wsc-\(UUID().uuidString)",
                                                                     directoryHint: .isDirectory)
    let reloads = Reloads()
    var store: WidgetSnapshotStore { WidgetSnapshotStore(directory: directory) }
    var queue: WidgetTickQueue { WidgetTickQueue(directory: directory) }
    init() throws { stack = try ShoppingTestStack() }

    func coordinator(observesSaves: Bool = false, shopping: ShoppingService? = nil) -> WidgetSnapshotCoordinator {
        let clock = stack.now, counter = reloads
        return WidgetSnapshotCoordinator(context: stack.context, spaceStore: stack.spaceStore,
                                         shopping: shopping ?? stack.service,
                                         inventory: stack.inventory, pending: stack.pending, store: store, queue: queue,
                                         reload: { counter.count += 1 }, now: { clock.date }, calendar: .current,
                                         locale: Locale(identifier: "en_US"), debounce: .zero,
                                         observesSaves: observesSaves)
    }

    var readOnlyShopping: ShoppingService {
        ShoppingService(spaceStore: stack.spaceStore, context: stack.context, userRecordName: stack.user,
                        canEdit: { _ in false })
    }

    @Test func refreshWritesTheSnapshotAndReloadsTheWidgets() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try stack.service.createList(name: "Heti", in: stack.space)
        let coordinator = coordinator()

        coordinator.refresh()

        #expect(store.read() == coordinator.lastSnapshot)
        #expect(store.read()?.lists.map(\.name) == ["Heti"])
        #expect(reloads.count == 1)
    }

    @Test func anUnchangedSnapshotIsNeitherRewrittenNorReloaded() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let list = try stack.service.createList(name: "Heti", in: stack.space)
        try stack.service.addItem(to: list, customName: "Tej")
        let coordinator = coordinator()

        coordinator.refresh()
        stack.now.advance(seconds: 60)                               // only the generation time differs
        coordinator.refresh()
        #expect(reloads.count == 1)

        try stack.service.addItem(to: list, customName: "Kenyér")
        coordinator.refresh()
        #expect(reloads.count == 2)
        #expect(store.read()?.lists.first?.remainingCount == 2)
    }

    @Test func aRowWhoseTickIsStillQueuedStaysOut() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let list = try stack.service.createList(name: "Heti", in: stack.space)
        let milk = try stack.service.addItem(to: list, customName: "Tej")
        try stack.service.addItem(to: list, customName: "Kenyér")
        try queue.append(QueuedTick(itemID: milk.publicId, listID: list.publicId, queuedAt: stack.now.date))

        coordinator().refresh()

        let snapshotList = try #require(store.read()?.lists.first)
        #expect(snapshotList.items.map(\.name) == ["Kenyér"])
        #expect(snapshotList.remainingCount == 1)
        #expect(queue.pending().count == 1)                            // refresh reads the queue, never drains it
    }

    @Test func aSaveSchedulesARefresh() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let list = try stack.service.createList(name: "Heti", in: stack.space)
        let coordinator = coordinator(observesSaves: true)

        try stack.service.addItem(to: list, customName: "Tej")
        await coordinator.pendingRefresh?.value

        #expect(store.read()?.lists.first?.items.map(\.name) == ["Tej"])
    }

    @Test func queuedTicksAreBoughtThenTheSnapshotIsRewritten() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let list = try stack.service.createList(name: "Heti", in: stack.space)
        let milk = try stack.service.addItem(to: list, customName: "Tej")
        try stack.service.addItem(to: list, customName: "Kenyér")
        try queue.append(QueuedTick(itemID: milk.publicId, listID: list.publicId, queuedAt: stack.now.date))
        try queue.append(QueuedTick(itemID: UUID(), listID: list.publicId, queuedAt: stack.now.date))   // gone meanwhile
        let coordinator = coordinator()

        #expect(coordinator.drainTicks() == 1)

        #expect(try stack.service.unpurchasedItems(in: list).map { $0.customName } == ["Kenyér"])
        #expect(store.read()?.lists.first?.remainingCount == 1)
        #expect(queue.pending().isEmpty)
        #expect(reloads.count == 1)
    }

    @Test func aTickForAMissingItemIsDropped() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let list = try stack.service.createList(name: "Heti", in: stack.space)
        try queue.append(QueuedTick(itemID: UUID(), listID: list.publicId, queuedAt: stack.now.date))

        #expect(coordinator().drainTicks() == 0)

        #expect(queue.pending().isEmpty)
    }

    @Test func aReadOnlySpaceRequeuesAFreshTickAndDropsAnOldOne() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let list = try stack.service.createList(name: "Heti", in: stack.space)
        let milk = try stack.service.addItem(to: list, customName: "Tej")
        let bread = try stack.service.addItem(to: list, customName: "Kenyér")
        let fresh = QueuedTick(itemID: milk.publicId, listID: list.publicId,
                               queuedAt: stack.now.date.addingTimeInterval(-23 * 3600))
        let old = QueuedTick(itemID: bread.publicId, listID: list.publicId,
                             queuedAt: stack.now.date.addingTimeInterval(-25 * 3600))
        try queue.append(fresh)
        try queue.append(old)

        #expect(coordinator(shopping: readOnlyShopping).drainTicks() == 0)

        #expect(queue.pending() == [fresh])
        #expect(try stack.service.unpurchasedItems(in: list).count == 2)
    }
}
