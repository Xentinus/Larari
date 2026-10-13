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

    func coordinator(observesSaves: Bool = false, shopping: ShoppingService? = nil,
                     activated: Bool = true, addsToInventory: Bool = true) -> WidgetSnapshotCoordinator {
        let purchaseDefaults = PurchaseDefaults(defaults: UserDefaults(suiteName: "test.wsc.\(UUID().uuidString)")!)
        purchaseDefaults.addsToInventory = addsToInventory
        let clock = stack.now, counter = reloads
        let coordinator = WidgetSnapshotCoordinator(context: stack.context, spaceStore: stack.spaceStore,
                                         shopping: shopping ?? stack.service,
                                         inventory: stack.inventory, pending: stack.pending, store: store, queue: queue,
                                         reload: { counter.count += 1 }, now: { clock.date }, calendar: .current,
                                         locale: Locale(identifier: "en_US"), debounce: .zero,
                                         observesSaves: observesSaves, purchaseDefaults: purchaseDefaults)
        if activated { coordinator.activate() }
        return coordinator
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

    // MARK: Activation gate (R14 I1)

    @Test func beforeActivationNothingIsWrittenReloadedOrDrained() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let list = try stack.service.createList(name: "Heti", in: stack.space)
        let milk = try stack.service.addItem(to: list, customName: "Tej")
        try queue.append(QueuedTick(itemID: milk.publicId, listID: list.publicId, queuedAt: stack.now.date))
        let coordinator = coordinator(activated: false)

        coordinator.refresh()
        coordinator.scheduleRefresh()
        await coordinator.pendingRefresh?.value
        #expect(coordinator.drainTicks() == 0)

        #expect(!coordinator.isActive)
        #expect(store.read() == nil)
        #expect(reloads.count == 0)
        #expect(queue.pending().count == 1)                                     // kept for the drain after activation
        #expect(try stack.service.unpurchasedItems(in: list).count == 1)

        coordinator.activate()
        #expect(coordinator.drainTicks() == 1)
        #expect(store.read()?.lists.first?.remainingCount == 0)
        #expect(reloads.count == 1)
    }

    @Test func aSaveBeforeActivationWritesNothing() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let list = try stack.service.createList(name: "Heti", in: stack.space)
        let coordinator = coordinator(observesSaves: true, activated: false)

        try stack.service.addItem(to: list, customName: "Tej")
        await coordinator.pendingRefresh?.value

        #expect(store.read() == nil)
        #expect(reloads.count == 0)
    }

    // MARK: App-process ticks (R14 I2)

    @Test func anAppTickAfterActivationRewritesTheSnapshot() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let list = try stack.service.createList(name: "Heti", in: stack.space)
        let milk = try stack.service.addItem(to: list, customName: "Tej").publicId    // a bought item leaves the list
        try stack.service.addItem(to: list, customName: "Kenyér")
        let coordinator = coordinator()
        coordinator.refresh()
        _ = try ShoppingActivityActions.purchase(itemIDs: [milk], shopping: stack.service,
                                                 inventory: stack.inventory, pending: stack.pending)

        coordinator.recordAppTick(itemIDs: [milk], requeueOpenItems: false)

        #expect(store.read()?.lists.first?.items.map(\.name) == ["Kenyér"])
        #expect(queue.pending().isEmpty)
        #expect(reloads.count == 2)
    }

    @Test func anAppTickBeforeActivationOnlyRemovesTheBoughtRows() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let list = try stack.service.createList(name: "Heti", in: stack.space)
        let milk = try stack.service.addItem(to: list, customName: "Tej").publicId
        let bread = try stack.service.addItem(to: list, customName: "Kenyér").publicId
        coordinator().refresh()                                     // the previous run's snapshot
        let written = try #require(store.read())
        let coordinator = coordinator(activated: false)
        _ = try ShoppingActivityActions.purchase(itemIDs: [milk], shopping: stack.service,
                                                 inventory: stack.inventory, pending: stack.pending)

        coordinator.recordAppTick(itemIDs: [milk, bread], requeueOpenItems: false)

        let snapshotList = try #require(store.read()?.lists.first)
        #expect(snapshotList.items.map(\.name) == ["Kenyér"])       // bread failed and was not queued: it stays
        #expect(snapshotList.remainingCount == 1)
        #expect(store.read()?.lists.first?.canEdit == written.lists.first?.canEdit)   // not rebuilt
        #expect(queue.pending().isEmpty)
        #expect(reloads.count == 2)
    }

    @Test func aTickWhoseWaitRanOutQueuesTheItemsStillOpen() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let list = try stack.service.createList(name: "Heti", in: stack.space)
        let milk = try stack.service.addItem(to: list, customName: "Tej").publicId
        let bread = try stack.service.addItem(to: list, customName: "Kenyér").publicId
        coordinator().refresh()
        let coordinator = coordinator(activated: false)
        _ = try ShoppingActivityActions.purchase(itemIDs: [bread], shopping: stack.service,
                                                 inventory: stack.inventory, pending: stack.pending)
        // milk's purchase failed closed (the permission cache was still empty)

        coordinator.recordAppTick(itemIDs: [milk, bread, UUID()], requeueOpenItems: true)

        #expect(queue.pending() == [QueuedTick(itemID: milk, listID: list.publicId, queuedAt: stack.now.date)])
        #expect(store.read()?.lists.first?.items.isEmpty == true)
        coordinator.activate()
        #expect(coordinator.drainTicks() == 1)
        #expect(try stack.service.unpurchasedItems(in: list).isEmpty)
    }

    @Test func withTheSettingOffATickOnlyTakesTheItemOffTheList() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let list = try stack.service.createList(name: "Heti", in: stack.space)
        let milk = try stack.service.addItem(to: list, customName: "Tej")
        try queue.append(QueuedTick(itemID: milk.publicId, listID: list.publicId, queuedAt: stack.now.date))

        #expect(coordinator(addsToInventory: false).drainTicks() == 1)

        #expect(try stack.service.unpurchasedItems(in: list).isEmpty)
        #expect(try stack.count(InventoryItem.self) == 0)
    }
}
