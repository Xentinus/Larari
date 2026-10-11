import CoreData
import Foundation
import LarariShared

/// Keeps the widgets' snapshot current (N-05): rewrites it after saves (its own observer), remote changes and
/// foregrounding, applies ticks the extension queued (iOS 26), and asks WidgetKit to reload through `reload`
/// (the app passes `WidgetCenter.shared.reloadAllTimelines`; LarariCore does not import WidgetKit).
@MainActor
public final class WidgetSnapshotCoordinator {
    /// A queued tick that could not be applied is kept for this long, then dropped.
    public static let tickLifetime: TimeInterval = 24 * 3600

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

    /// Synchronous on purpose: the app-process widget tick must have written the file before its intent returns,
    /// because WidgetKit reloads the widget right after. Rows whose tick is still queued stay out, and an unchanged
    /// snapshot is neither written nor reloaded (the widgets' reload budget).
    public func refresh() {
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

    public func scheduleRefresh() {
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
    /// launch) goes back into the queue while it is less than 24 hours old, so an early drain loses nothing.
    @discardableResult
    public func drainTicks() -> Int {
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

    private func startObservingSaves() {
        saveObserver = NotificationCenter.default.addObserver(
            forName: NSManagedObjectContext.didSaveObjectsNotification, object: context, queue: nil
        ) { [weak self] _ in
            // queue nil: runs on the posting thread; the view context always saves on the main thread.
            MainActor.assumeIsolated { self?.scheduleRefresh() }
        }
    }
}
