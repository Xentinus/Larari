import AppIntents
import Foundation
import LarariShared

/// A shopping list as the widget's configuration sees it, read from the App Group snapshot (N-05).
nonisolated struct ShoppingListAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "widget.list.entity") }
    static var defaultQuery: ShoppingListEntityQuery { ShoppingListEntityQuery() }

    let id: UUID
    let name: String
    let spaceName: String

    /// User data shown as is: a non-literal resource is not extracted into the catalog, and no key matches it.
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name),
                              subtitle: LocalizedStringResource(stringLiteral: spaceName))
    }
}

nonisolated struct ShoppingListEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ShoppingListAppEntity] {
        all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ShoppingListAppEntity] {
        all()
    }

    private func all() -> [ShoppingListAppEntity] {
        (WidgetSnapshotStore.appGroup()?.read()?.lists ?? []).map {
            ShoppingListAppEntity(id: $0.id, name: $0.name, spaceName: $0.spaceName)
        }
    }
}

/// "Edit widget": which list to show. Not discoverable (no Shortcuts, no Siri). Main-actor isolated like every
/// intent here: `@Parameter` storage cannot be `nonisolated`.
struct SelectShoppingListIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.list.configure.title"
    static let isDiscoverable = false

    @Parameter(title: "widget.list.configure.list")
    var list: ShoppingListAppEntity?

    init() {}
}
