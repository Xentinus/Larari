import AppIntents
import Foundation
import LarariShared

/// Ticks one item on the Shopping list widget (N-05). iOS 27: runs in the app's process and buys through
/// `ShoppingTickBridge`, like the Live Activity. iOS 26 (or wherever it runs in the extension): queues the tick in the
/// App Group, removes the row from the snapshot at once and pings a running app. Compiled into both targets.
/// Main-actor isolated (both targets' default), like `TickShoppingItemIntent`: `@Parameter` storage cannot be
/// `nonisolated`.
struct TickWidgetShoppingItemIntent: AppIntent {
    static let title: LocalizedStringResource = "widget.list.tick.title"
    static let isDiscoverable = false

    /// Verified on the iPhone in Step 7.5; remove this witness (and note it) if the spike fails.
    @available(iOS 27.0, *)
    nonisolated static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Parameter(title: "widget.list.tick.item")
    var itemID: String

    @Parameter(title: "widget.list.tick.list")
    var listID: String

    init() {}

    init(itemID: UUID, listID: UUID) {
        self.itemID = itemID.uuidString
        self.listID = listID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let item = UUID(uuidString: itemID), let list = UUID(uuidString: listID) else { return .result() }
        // App process: the app took the tick. False there (no services yet) falls through to the queue like iOS 26.
        if await ShoppingTickBridge.tick([item]) { return .result() }
        guard let store = WidgetSnapshotStore.appGroup(), let queue = WidgetTickQueue.appGroup() else { return .result() }
        try queue.append(QueuedTick(itemID: item, listID: list, queuedAt: .now))
        // The queue is the source of truth; a snapshot that could not be marked only shows the row until the app runs.
        try? store.markTicked(itemID: item, listID: list)
        WidgetTickPing.post()
        return .result()
    }
}
