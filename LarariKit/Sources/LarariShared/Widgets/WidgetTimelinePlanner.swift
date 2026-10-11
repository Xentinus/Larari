import Foundation

/// Same order and raw values as LarariCore's `ExpirationLevel` (`SnapshotExpiryParityTests`).
public enum SnapshotExpiryLevel: Int, Comparable, Sendable {
    case none, ok, soon, critical, expired

    public static func < (lhs: SnapshotExpiryLevel, rhs: SnapshotExpiryLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// `ExpirationStatus.level` for the extension, with the thresholds the app wrote into the snapshot.
public enum SnapshotExpiry {
    public static func daysLeft(_ expiresAt: Date, now: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: expiresAt)).day ?? 0
    }

    public static func level(expiresAt: Date?, now: Date, calendar: Calendar, soonDays: Int,
                             criticalDays: Int) -> SnapshotExpiryLevel {
        guard let expiresAt else { return .none }
        let days = daysLeft(expiresAt, now: now, calendar: calendar)
        if days < 0 { return .expired }
        if days <= criticalDays { return .critical }
        if days <= soonDays { return .soon }
        return .ok
    }
}

public struct ExpiringRow: Equatable, Sendable, Identifiable {
    public let item: ExpiringItemSnapshot
    public let level: SnapshotExpiryLevel
    public let daysLeft: Int
    public var id: UUID { item.id }

    public init(item: ExpiringItemSnapshot, level: SnapshotExpiryLevel, daysLeft: Int) {
        self.item = item
        self.level = level
        self.daysLeft = daysLeft
    }
}

/// What the Expiring soon widget shows at one moment.
public struct ExpiringTimelineContent: Equatable, Sendable {
    public let date: Date
    /// soon, critical and expired items at `date`, most severe first, then earliest.
    public let rows: [ExpiringRow]
    /// False before the app has written a snapshot (or after a schema change): "Open Larari once".
    public let hasSnapshot: Bool
    /// The space with most rows; the tap opens Inventory there (like a tapped summary notification).
    public let topSpaceID: UUID?

    public init(date: Date, rows: [ExpiringRow], hasSnapshot: Bool, topSpaceID: UUID?) {
        self.date = date
        self.rows = rows
        self.hasSnapshot = hasSnapshot
        self.topSpaceID = topSpaceID
    }
}

public enum WidgetTimelinePlanner {
    public static let lookaheadDays = 7
    /// The daily summary's hour (spec §6.5): the widget re-reads the snapshot then.
    public static let refreshHour = 7

    public static func expiringContent(snapshot: WidgetSnapshot?, at date: Date,
                                       calendar: Calendar) -> ExpiringTimelineContent {
        guard let snapshot else { return ExpiringTimelineContent(date: date, rows: [], hasSnapshot: false, topSpaceID: nil) }
        let rows = snapshot.expiring.compactMap { item -> ExpiringRow? in
            let level = SnapshotExpiry.level(expiresAt: item.expiresAt, now: date, calendar: calendar,
                                             soonDays: snapshot.soonDays, criticalDays: snapshot.criticalDays)
            guard level >= .soon else { return nil }
            return ExpiringRow(item: item, level: level,
                               daysLeft: SnapshotExpiry.daysLeft(item.expiresAt, now: date, calendar: calendar))
        }
        .sorted { lhs, rhs in
            lhs.level != rhs.level ? lhs.level > rhs.level : lhs.item.expiresAt < rhs.item.expiresAt
        }
        let counts = Dictionary(grouping: rows.compactMap(\.item.spaceID), by: { $0 }).mapValues(\.count)
        let top = rows.compactMap(\.item.spaceID).max { (counts[$0] ?? 0) < (counts[$1] ?? 0) }
        return ExpiringTimelineContent(date: date, rows: rows, hasSnapshot: true, topSpaceID: top)
    }

    /// Now, then every midnight of the look-ahead; without a snapshot only now.
    public static func expiringTimeline(snapshot: WidgetSnapshot?, now: Date,
                                        calendar: Calendar) -> [ExpiringTimelineContent] {
        guard snapshot != nil else { return [expiringContent(snapshot: nil, at: now, calendar: calendar)] }
        let today = calendar.startOfDay(for: now)
        let midnights = (1...lookaheadDays).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        return ([now] + midnights).map { expiringContent(snapshot: snapshot, at: $0, calendar: calendar) }
    }

    public static func nextReload(after now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        let seven = calendar.date(bySettingHour: refreshHour, minute: 0, second: 0, of: today) ?? now
        return seven > now ? seven : (calendar.date(byAdding: .day, value: 1, to: seven) ?? now)
    }

    /// Without a snapshot (before the first unlock after a restart the App Group file cannot be read, or the app has
    /// not written it yet) the widgets look again this soon, so "Open Larari once" does not stick until 07:00.
    public static let missingSnapshotRetry: TimeInterval = 15 * 60

    /// The Expiring soon widget's reload: 07:00 with a snapshot, else `missingSnapshotRetry` from now.
    public static func expiringReload(hasSnapshot: Bool, after now: Date, calendar: Calendar) -> Date {
        hasSnapshot ? nextReload(after: now, calendar: calendar) : now.addingTimeInterval(missingSnapshotRetry)
    }

    /// The Shopping list widget's reload: nil (never; the app reloads it after every change) with a snapshot, else
    /// `missingSnapshotRetry` from now.
    public static func listReload(hasSnapshot: Bool, after now: Date) -> Date? {
        hasSnapshot ? nil : now.addingTimeInterval(missingSnapshotRetry)
    }

    /// The configured list; without one (or when it was deleted) the first list that has items, else the first.
    public static func list(in snapshot: WidgetSnapshot?, id: UUID?) -> ShoppingListSnapshot? {
        guard let lists = snapshot?.lists else { return nil }
        if let id, let chosen = lists.first(where: { $0.id == id }) { return chosen }
        return lists.first { $0.remainingCount > 0 } ?? lists.first
    }
}
