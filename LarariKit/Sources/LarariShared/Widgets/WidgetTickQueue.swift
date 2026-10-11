import CoreFoundation
import Foundation

/// A widget tick the extension could not hand to the app (iOS 26, N-05).
public struct QueuedTick: Codable, Equatable, Sendable {
    public let itemID: UUID
    public let listID: UUID
    public let queuedAt: Date

    public init(itemID: UUID, listID: UUID, queuedAt: Date) {
        self.itemID = itemID
        self.listID = listID
        self.queuedAt = queuedAt
    }
}

/// `<App Group>/Widgets/ticks.json`: appended by the extension, drained by the app.
public struct WidgetTickQueue: Sendable {
    public static let fileName = "ticks.json"

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func appGroup(_ appGroup: String = SharedContainer.appGroup) -> WidgetTickQueue? {
        SharedContainer.directory("Widgets", appGroup: appGroup).map(WidgetTickQueue.init(directory:))
    }

    var fileURL: URL { directory.appending(path: Self.fileName) }

    public func append(_ tick: QueuedTick) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileCoordination.write(fileURL, options: .forMerging) { url in
            var ticks = Self.load(url)
            guard !ticks.contains(where: { $0.itemID == tick.itemID }) else { return }
            ticks.append(tick)
            try FileCoordination.encoder.encode(ticks).write(to: url, options: .atomic)
        }
    }

    public func pending() -> [QueuedTick] {
        (try? FileCoordination.read(fileURL) { Self.load($0) }) ?? []
    }

    /// Returns every queued tick and empties the queue; a broken file is discarded.
    public func drain() throws -> [QueuedTick] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try FileCoordination.write(fileURL, options: .forDeleting) { url in
            let ticks = Self.load(url)
            try FileManager.default.removeItem(at: url)
            return ticks
        }
    }

    private static func load(_ url: URL) -> [QueuedTick] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? FileCoordination.decoder.decode([QueuedTick].self, from: data)) ?? []
    }
}

/// Wakes a running app when the extension queued a tick (a Darwin notification carries no data).
public enum WidgetTickPing {
    public static let name = "app.larari.widget-tick"

    public static func post() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(name as CFString), nil, nil, true)
    }
}
