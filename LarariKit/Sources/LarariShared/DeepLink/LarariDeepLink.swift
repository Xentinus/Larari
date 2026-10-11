import Foundation

/// `larari://` links opened from the Live Activity and the widgets (N-04, N-05). The app maps them onto
/// `AppDestination`; any other URL (an archive) goes to the import router as before.
public enum LarariDeepLink: Equatable, Sendable {
    case inventory(spaceID: UUID?)
    /// The Inventory tab grouped by expiry, like the expiry notifications (the Expiring soon widget, N-05).
    case inventoryExpiring(spaceID: UUID?)
    /// The Shopping home filtered to one list (the Shopping list widget, N-05).
    case shoppingList(spaceID: UUID, listID: UUID)
    /// The Shopping tab of a household, grouped by store (the Live Activity's store or chain).
    case shoppingStore(spaceID: UUID, scope: ShoppingActivityScope)

    public static let scheme = "larari"
    private static let expiryGroup = "expiry"

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case let .inventory(spaceID):
            components.host = "inventory"
            components.queryItems = spaceID.map { [URLQueryItem(name: "space", value: $0.uuidString)] }
        case let .inventoryExpiring(spaceID):
            components.host = "inventory"
            components.queryItems = (spaceID.map { [URLQueryItem(name: "space", value: $0.uuidString)] } ?? [])
                + [URLQueryItem(name: "group", value: Self.expiryGroup)]
        case let .shoppingList(spaceID, listID):
            components.host = "shopping"
            components.queryItems = [URLQueryItem(name: "space", value: spaceID.uuidString),
                                     URLQueryItem(name: "list", value: listID.uuidString)]
        case let .shoppingStore(spaceID, scope):
            components.host = "shopping"
            var items = [URLQueryItem(name: "space", value: spaceID.uuidString)]
            switch scope {
            case let .store(id): items.append(URLQueryItem(name: "store", value: id.uuidString))
            case let .stores(ids): items.append(URLQueryItem(name: "stores", value: ids.map(\.uuidString).joined(separator: ",")))
            case let .chain(key): items.append(URLQueryItem(name: "chain", value: key))
            }
            components.queryItems = items
        }
        // Always valid: a fixed scheme and host, query values percent-encoded by URLComponents.
        return components.url!
    }

    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        func value(_ name: String) -> String? {
            components.queryItems?.first { $0.name == name }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }
        switch components.host?.lowercased() {
        case "inventory":
            let space = value("space").flatMap(UUID.init(uuidString:))
            self = value("group") == Self.expiryGroup ? .inventoryExpiring(spaceID: space) : .inventory(spaceID: space)
        case "shopping":
            guard let space = value("space").flatMap(UUID.init(uuidString:)) else { return nil }
            if let list = value("list") {
                guard let id = UUID(uuidString: list) else { return nil }
                self = .shoppingList(spaceID: space, listID: id)
            } else if let store = value("store").flatMap(UUID.init(uuidString:)) {
                self = .shoppingStore(spaceID: space, scope: .store(store))
            } else if let list = value("stores") {
                let ids = list.split(separator: ",").map { UUID(uuidString: String($0)) }
                guard !ids.isEmpty, !ids.contains(nil) else { return nil }
                self = .shoppingStore(spaceID: space, scope: .stores(ids.compactMap { $0 }))
            } else if let chain = value("chain") {
                self = .shoppingStore(spaceID: space, scope: .chain(chain))
            } else {
                return nil
            }
        default:
            return nil
        }
    }
}
