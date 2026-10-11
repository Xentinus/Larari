import CoreData
import Foundation
import LarariShared

/// Keeps the widgets' snapshot current (N-05): rewrites it after saves (its own observer), remote changes and
/// foregrounding, applies ticks the extension queued (iOS 26), and asks WidgetKit to reload through `reload`
/// (the app passes `WidgetCenter.shared.reloadAllTimelines`; LarariCore does not import WidgetKit).
///
/// Inactive until the app calls `activate()` after the launch share refresh (R14 I1): until then P5-06's
/// share-permission cache fails closed for joined households, so a rebuilt snapshot would carry `canEdit = false` and a
/// drain could buy nothing there. While inactive, `refresh`, `scheduleRefresh` and `drainTicks` do nothing: the file
/// keeps the previous run's snapshot and the queue keeps every tick for the drain that follows the activation.
@MainActor
public final class WidgetSnapshotCoordinator {
    /// A queued tick that could not be applied is kept for this long, then dropped.
    public static let tickLifetime: TimeInterval = 24 * 3600

    public private(set) var isActive = false
    public private(set) var lastSnapshot: WidgetSnapshot?
    public private(set) var pendingRefresh: Task<Void, Never>?

    private let context: NSManagedObjectContext
    private let spaceStore: SpaceStore
    private let shopping: ShoppingService
    private let inventory: InventoryService
    private let pending: PendingDeletions
    private let store: WidgetSnapshotStore
    private let queue: WidgetTickQueue
    private let reload: @MainActor () -> Void
    private let now: () -> Date
    private let calendar: Calendar
    private let locale: Locale
    private let debounce: Duration
    private var saveObserver: (any NSObjectProtocol)?

    public init(context: NSManagedObjectContext, spaceStore: SpaceStore, shopping: ShoppingService,
                inventory: InventoryService, pending: PendingDeletions, store: WidgetSnapshotStore,
                queue: WidgetTickQueue, reload: @escaping @MainActor () -> Void, now: @escaping () -> Date = { Date() },
                calendar: Calendar = .current, locale: Locale = .current, debounce: Duration = .milliseconds(500),
                observesSaves: Bool = true) {
        self.context = context
        self.spaceStore = spaceStore
        self.shopping = shopping
        self.inventory = inventory
        self.pending = pending
        self.store = store
        self.queue = queue
        self.reload = reload
        self.now = now
        self.calendar = calendar
        self.locale = locale
        self.debounce = debounce
        if observesSaves { startObservingSaves() }
    }

    /// Called by the app right before the first `drainTicks()` after the launch share refresh; idempotent.
    public func activate() {
        isActive = true
    }

    /// Synchronous on purpose: the app-process widget tick must have written the file before its intent returns,
    /// because WidgetKit reloads the widget right after. Rows whose tick is still queued stay out, and an unchanged
    /// snapshot is neither written nor reloaded (the widgets' reload budget). Does nothing before `activate()`.
    public func refresh() {
        guard isActive else { return }
        pendingRefresh?.cancel()
        let queued = Set(queue.pending().map(\.itemID))
        guard let snapshot = try? WidgetSnapshotBuilder.build(context: context, spaceStore: spaceStore,
                                                              shopping: shopping, pending: pending, now: now(),
                                                              calendar: calendar, locale: locale,
                                                              queuedItemIDs: queued),
              let written = try? store.writeIfChanged(snapshot) else { return }
        lastSnapshot = snapshot
        if written { reload() }
    }

    /// Does nothing before `activate()`.
    public func scheduleRefresh() {
        guard isActive else { return }
        pendingRefresh?.cancel()
        let delay = debounce
        pendingRefresh = Task { [weak self] in
            if delay > .zero {
                do { try await Task.sleep(for: delay) } catch { return }
            }
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    /// Buys what the extension queued (N-04's tick, same choices), then rewrites the snapshot. Returns how many
    /// items were bought. A tick whose item is gone or already bought is dropped. A tick that fails (a read-only
    /// household, or the share-permission cache of joined households that fails closed until it is refreshed after
    /// launch) goes back into the queue while it is less than 24 hours old, so an early drain loses nothing. Before
    /// `activate()` it does nothing and leaves the queue untouched (the safe choice: no purchase can fail closed, no
    /// tick is dropped), so a ping from the extension during launch waits for the activation's drain.
    @discardableResult
    public func drainTicks() -> Int {
        guard isActive else { return 0 }
        let ticks = (try? queue.drain()) ?? []
        let current = now()
        var bought = 0
        for tick in ticks {
            do {
                bought += try ShoppingActivityActions.purchase(itemIDs: [tick.itemID], shopping: shopping,
                                                               inventory: inventory, pending: pending)
            } catch {
                if current.timeIntervalSince(tick.queuedAt) < Self.tickLifetime { try? queue.append(tick) }
            }
        }
        refresh()
        return bought
    }

    /// After a tick the app applied itself (iOS 27 widget tick, Live Activity tick), whether or not the purchase
    /// succeeded. `requeueOpenItems` (the app's bounded wait for the launch share refresh ran out, R14 I2): the items
    /// still open go into the tick queue, so the drain after the activation buys them once the permission cache is
    /// filled. Active: rewrites the snapshot at once. Inactive: a rebuilt snapshot could carry `canEdit = false`, so
    /// only the rows that were bought (or are gone) or queued leave the file, as the extension does for its own ticks.
    public func recordAppTick(itemIDs: [UUID], requeueOpenItems: Bool) {
        let open = openItems(itemIDs)
        if requeueOpenItems {
            for id in itemIDs {
                guard let listID = open[id] else { continue }
                try? queue.append(QueuedTick(itemID: id, listID: listID, queuedAt: now()))
            }
        }
        if isActive {
            refresh()
            return
        }
        let handled = itemIDs.filter { requeueOpenItems || open[$0] == nil }
        guard !handled.isEmpty, let lists = store.read()?.lists else { return }
        var marked = false
        for id in handled {
            guard let list = lists.first(where: { $0.items.contains { $0.id == id } }) else { continue }
            try? store.markTicked(itemID: id, listID: list.id)
            marked = true
        }
        if marked { reload() }
    }

    /// The ticked items that still wait on their list (a bought item leaves it), keyed to their list's id.
    private func openItems(_ itemIDs: [UUID]) -> [UUID: UUID] {
        guard !itemIDs.isEmpty, let items = try? context.fetchEntities(
            ShoppingListItem.self, where: NSPredicate(format: "publicId IN %@", itemIDs.map { $0 as NSUUID }))
        else { return [:] }
        var open: [UUID: UUID] = [:]
        for item in items where !item.isGone && !item.isPurchased {
            if let listID = item.shoppingList?.publicId { open[item.publicId] = listID }
        }
        return open
    }

    private func startObservingSaves() {
        saveObserver = NotificationCenter.default.addObserver(
            forName: NSManagedObjectContext.didSaveObjectsNotification, object: context, queue: nil
        ) { [weak self] _ in
            // queue nil: runs on the posting thread; the view context always saves on the main thread.
            MainActor.assumeIsolated { self?.scheduleRefresh() }
        }
    }
}
