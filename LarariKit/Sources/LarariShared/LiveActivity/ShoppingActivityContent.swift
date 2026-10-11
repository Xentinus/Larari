import Foundation

/// Which items a shopping Live Activity covers (N-04 D5 A, D10 A, D11): one saved store, several saved stores within
/// 150 m of the user (one household, sorted by `uuidString`), or every store of a chain when the user stands at a
/// branch that is not saved. The chain is a `ChainKey` (lowercased, no diacritics).
public enum ShoppingActivityScope: Codable, Hashable, Sendable {
    case store(UUID)
    case stores([UUID])
    case chain(String)

    /// Store scopes end when their stores are gone; a chain scope keeps its last title while nothing is open.
    public var isChain: Bool {
        switch self {
        case .chain: true
        case .store, .stores: false
        }
    }
}

/// The shopping Live Activity's changing part (`ShoppingActivityAttributes.ContentState`). Kept small: ActivityKit
/// caps attributes plus state at 4 KB, and the builder shortens every name to 40 characters. Counts only since the
/// N-05 rework: the banner has no item rows (the Lock Screen's 160 pt).
public struct ShoppingActivityContent: Codable, Hashable, Sendable {
    /// The store's name, or the chain's name at an unsaved branch.
    public var title: String
    public var spaceName: String
    /// How many lists the open items come from; the caption shows it from two up.
    public var listCount: Int
    public var remainingCount: Int
    /// Rows that left since the activity started: bought here, in the app, or removed by someone else.
    public var doneCount: Int

    public init(title: String, spaceName: String, listCount: Int, remainingCount: Int, doneCount: Int) {
        self.title = title
        self.spaceName = spaceName
        self.listCount = listCount
        self.remainingCount = remainingCount
        self.doneCount = doneCount
    }

    public var isFinished: Bool { remainingCount == 0 }
    public var totalCount: Int { remainingCount + doneCount }
}
