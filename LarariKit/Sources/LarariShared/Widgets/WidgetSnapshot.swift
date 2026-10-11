import Foundation

/// The App Group shared by the app and the widget extension (C-01, N-05). `AppModel.appGroup` has the same value.
public enum SharedContainer {
    public static let appGroup = "group.app.larari"

    /// `<App Group>/<name>/`, or nil when the App Group is not available (local mode, missing entitlement).
    public static func directory(_ name: String, appGroup: String = appGroup) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: name, directoryHint: .isDirectory)
    }
}

public enum WidgetKinds {
    public static let expiring = "com.larari.widgets.expiring"
    public static let shoppingList = "com.larari.widgets.shoppingList"
}

/// Everything the widgets show, written by the app (N-05). Names, quantities and dates only.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var generatedAt: Date
    /// `ExpirationStatus.soonDays` / `.criticalDays` at write time, so the extension needs no LarariCore.
    public var soonDays: Int
    public var criticalDays: Int
    /// Open items expiring before the window plus the timeline's look-ahead, expired ones included, earliest first.
    public var expiring: [ExpiringItemSnapshot]
    public var lists: [ShoppingListSnapshot]

    public init(generatedAt: Date, soonDays: Int, criticalDays: Int, expiring: [ExpiringItemSnapshot],
                lists: [ShoppingListSnapshot], schemaVersion: Int = WidgetSnapshot.currentSchemaVersion) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.soonDays = soonDays
        self.criticalDays = criticalDays
        self.expiring = expiring
        self.lists = lists
    }
}

public struct ExpiringItemSnapshot: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let spaceID: UUID?
    public let spaceName: String
    public let expiresAt: Date

    public init(id: UUID, name: String, spaceID: UUID?, spaceName: String, expiresAt: Date) {
        self.id = id
        self.name = name
        self.spaceID = spaceID
        self.spaceName = spaceName
        self.expiresAt = expiresAt
    }
}

public struct ShoppingListSnapshot: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let spaceID: UUID
    public let spaceName: String
    public let name: String
    public let colorHex: String?
    public let canEdit: Bool
    public var remainingCount: Int
    /// The first open items in list order (at most `WidgetSnapshotBuilder.maxItemsPerList`).
    public var items: [ShoppingItemSnapshot]

    public init(id: UUID, spaceID: UUID, spaceName: String, name: String, colorHex: String?, canEdit: Bool,
                remainingCount: Int, items: [ShoppingItemSnapshot]) {
        self.id = id
        self.spaceID = spaceID
        self.spaceName = spaceName
        self.name = name
        self.colorHex = colorHex
        self.canEdit = canEdit
        self.remainingCount = remainingCount
        self.items = items
    }
}

public struct ShoppingItemSnapshot: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let quantityText: String

    public init(id: UUID, name: String, quantityText: String) {
        self.id = id
        self.name = name
        self.quantityText = quantityText
    }
}
