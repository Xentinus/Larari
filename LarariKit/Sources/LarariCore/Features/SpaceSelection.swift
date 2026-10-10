import CoreData
import Foundation
import Observation

/// The space a window shows. Since N-03 every window has its own instance (iPad windows, like Reminders' lists):
/// a window restores its own space from scene storage, and a new window starts from the space last picked in any
/// window, which the `selectedSpaceID` setter records in UserDefaults.
@MainActor
@Observable
public final class SpaceSelection {
    public static let defaultsKey = "selectedSpaceID"

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var storedID: UUID?
    /// Counts Space objects inserted into or deleted from the view context, see `noteObjectsDidChange(_:)`.
    private var spaceGeneration = 0

    /// What a view keys its space-dependent work on. It changes when the user picks another space, and also when
    /// the selected space's object is replaced by another one with the same `publicId`: after an iCloud sign-in the
    /// app creates Personal before the import arrives, and the import's older copy wins the dedup (C-02). A key on
    /// the id alone would keep the view on the deleted copy.
    public struct Key: Hashable, Sendable {
        public let id: UUID?
        let generation: Int
    }

    /// - Parameter restoredID: the window's own space from its scene storage (N-03). Without one, the window starts
    ///   from the space last picked in any window.
    public init(defaults: UserDefaults = .standard, restoredID: UUID? = nil) {
        self.defaults = defaults
        storedID = restoredID ?? defaults.string(forKey: Self.defaultsKey).flatMap(UUID.init(uuidString:))
    }

    /// Shows `id` in this window without making it the last-used space. A list or product window follows its
    /// item's space this way, and a new main window still starts where the user last chose (N-03).
    public func restore(_ id: UUID?) {
        withMutation(keyPath: \.selectedSpaceID) { storedID = id }
    }

    public var selectedSpaceID: UUID? {
        get {
            access(keyPath: \.selectedSpaceID)
            return storedID
        }
        set {
            withMutation(keyPath: \.selectedSpaceID) { storedID = newValue }
            if let newValue {
                defaults.set(newValue.uuidString, forKey: Self.defaultsKey)
            } else {
                defaults.removeObject(forKey: Self.defaultsKey)
            }
        }
    }

    /// The selected space if it is in `spaces`, otherwise Personal, otherwise the first space.
    /// Does not change `selectedSpaceID`.
    public func resolve(in spaces: [Space]) -> Space? {
        if let id = selectedSpaceID, let match = spaces.first(where: { $0.publicId == id }) {
            return match
        }
        return spaces.first(where: { $0.kind == .personal }) ?? spaces.first
    }

    public var spaceKey: Key { Key(id: selectedSpaceID, generation: spaceGeneration) }

    /// Feed every `NSManagedObjectContextObjectsDidChange` of the view context here. A Space inserted or deleted
    /// (sync, dedup, leave, delete) changes `spaceKey`, so views resolve their space again.
    public func noteObjectsDidChange(_ notification: Notification) {
        let info = notification.userInfo ?? [:]
        let touched = [NSInsertedObjectsKey, NSDeletedObjectsKey].contains { key in
            (info[key] as? Set<NSManagedObject>)?.contains { $0 is Space } ?? false
        }
        if touched { spaceGeneration += 1 }
    }

    public func select(_ space: Space) {
        selectedSpaceID = space.publicId
    }
}
