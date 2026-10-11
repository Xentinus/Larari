import AppIntents
import LarariShared
import SwiftUI
import WidgetKit

nonisolated struct ShoppingListWidgetEntry: TimelineEntry, Sendable {
    let date: Date
    let list: ShoppingListSnapshot?
    let hasSnapshot: Bool
}

nonisolated struct ShoppingListProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ShoppingListWidgetEntry {
        ShoppingListWidgetEntry(date: .now, list: nil, hasSnapshot: true)
    }

    func snapshot(for configuration: SelectShoppingListIntent, in context: Context) async -> ShoppingListWidgetEntry {
        entry(for: configuration)
    }

    /// One entry; the app reloads the widget after every change, so the policy is `.never`.
    func timeline(for configuration: SelectShoppingListIntent, in context: Context) async -> Timeline<ShoppingListWidgetEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: SelectShoppingListIntent) -> ShoppingListWidgetEntry {
        let snapshot = WidgetSnapshotStore.appGroup()?.read()
        return ShoppingListWidgetEntry(date: .now, list: WidgetTimelinePlanner.list(in: snapshot, id: configuration.list?.id),
                                       hasSnapshot: snapshot != nil)
    }
}

/// "Shopping list" (W4 A, W5 A, W6 A): the chosen list (else the first with items) with circle tick buttons.
struct ShoppingListWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKinds.shoppingList, intent: SelectShoppingListIntent.self,
                               provider: ShoppingListProvider()) { entry in
            ShoppingListWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(entry.list.map { LarariDeepLink.shoppingList(spaceID: $0.spaceID, listID: $0.id).url })
        }
        .configurationDisplayName("widget.list.name")
        .description("widget.list.description")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct ShoppingListWidgetView: View {
    let entry: ShoppingListWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var isLarge: Bool { family == .systemLarge }
    private var limit: Int { isLarge ? 8 : 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let list = entry.list {
                HStack {
                    Text(verbatim: list.name)
                        .font(.headline)
                        .foregroundStyle(WidgetPalette.mocha)
                        .widgetAccentable()
                        .lineLimit(1)
                    Spacer()
                    Text(verbatim: "\(list.remainingCount)")
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text("widget.list.remaining \(list.remainingCount)"))
                }
                if list.items.isEmpty {
                    Label("widget.list.done", systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    // Rows are 32 pt high (the tick's tap area), so they sit without extra spacing.
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(list.items.prefix(limit)) { item in
                            ShoppingListWidgetRow(item: item, listID: list.id, canTick: list.canEdit)
                        }
                    }
                    // Medium has room for three 32 pt rows only; the count in the header says what is left.
                    let more = list.remainingCount - min(limit, list.items.count)
                    if isLarge, more > 0 {
                        Text("widget.list.more \(more)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(entry.hasSnapshot ? LocalizedStringKey("widget.list.choose") : LocalizedStringKey("widget.openApp"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

/// One row: a circle tick button (not in read-only households) with a 32 × 32 pt tap area like the Live Activity
/// rows, the name, the quantity on the right.
struct ShoppingListWidgetRow: View {
    let item: ShoppingItemSnapshot
    let listID: UUID
    let canTick: Bool

    var body: some View {
        HStack(spacing: 8) {
            if canTick {
                Button(intent: TickWidgetShoppingItemIntent(itemID: item.id, listID: listID)) {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundStyle(WidgetPalette.mocha)
                        .widgetAccentable()
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("widget.list.tick.accessibility \(item.name)"))
            }
            HStack(spacing: 8) {
                Text(verbatim: item.name).font(.subheadline).lineLimit(1)
                Spacer(minLength: 4)
                Text(verbatim: item.quantityText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(minHeight: 32)
    }
}
