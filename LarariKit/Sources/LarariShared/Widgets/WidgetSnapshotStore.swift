import Foundation

/// `<App Group>/Widgets/snapshot.json` (N-05). The app replaces it after changes; the extension reads it and, for a
/// queued iOS 26 tick, removes the ticked row at once.
public struct WidgetSnapshotStore: Sendable {
    public static let fileName = "snapshot.json"

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func appGroup(_ appGroup: String = SharedContainer.appGroup) -> WidgetSnapshotStore? {
        SharedContainer.directory("Widgets", appGroup: appGroup).map(WidgetSnapshotStore.init(directory:))
    }

    public var fileURL: URL { directory.appending(path: Self.fileName) }

    public func write(_ snapshot: WidgetSnapshot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try FileCoordination.encoder.encode(snapshot)
        try FileCoordination.write(fileURL) { url in try data.write(to: url, options: .atomic) }
    }

    /// Writes `snapshot` unless the file already holds the same content, `generatedAt` aside (compared as encoded, so
    /// at the file's date precision). Returns whether it wrote. Reading and writing are one coordinated block, so an
    /// extension tick (`markTicked`) in between is seen, not overwritten unchecked.
    @discardableResult
    public func writeIfChanged(_ snapshot: WidgetSnapshot) throws -> Bool {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try FileCoordination.encoder.encode(snapshot)
        return try FileCoordination.write(fileURL, options: .forMerging) { url in
            if let existing = try? Data(contentsOf: url), var current = Self.decode(existing) {
                current.generatedAt = snapshot.generatedAt
                if try FileCoordination.encoder.encode(current) == data { return false }
            }
            try data.write(to: url, options: .atomic)
            return true
        }
    }

    public func read() -> WidgetSnapshot? {
        guard let data = try? FileCoordination.read(fileURL, { try Data(contentsOf: $0) }) else { return nil }
        return Self.decode(data)
    }

    /// Optimistic update for a tick the app has not applied yet. Unknown lists or rows change nothing.
    public func markTicked(itemID: UUID, listID: UUID) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileCoordination.write(fileURL, options: .forMerging) { url in
            guard let data = try? Data(contentsOf: url), var snapshot = Self.decode(data),
                  let index = snapshot.lists.firstIndex(where: { $0.id == listID }),
                  snapshot.lists[index].items.contains(where: { $0.id == itemID }) else { return }
            snapshot.lists[index].items.removeAll { $0.id == itemID }
            snapshot.lists[index].remainingCount = max(0, snapshot.lists[index].remainingCount - 1)
            try FileCoordination.encoder.encode(snapshot).write(to: url, options: .atomic)
        }
    }

    private struct Header: Decodable { let schemaVersion: Int }

    static func decode(_ data: Data) -> WidgetSnapshot? {
        guard let header = try? FileCoordination.decoder.decode(Header.self, from: data),
              header.schemaVersion == WidgetSnapshot.currentSchemaVersion else { return nil }
        return try? FileCoordination.decoder.decode(WidgetSnapshot.self, from: data)
    }
}
