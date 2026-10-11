import LarariShared
import SwiftUI
import WidgetKit

nonisolated struct ExpiringWidgetEntry: TimelineEntry, Sendable {
    let date: Date
    let content: ExpiringTimelineContent
}

/// Today's rows now, then one entry per midnight of the look-ahead; WidgetKit reloads at 07:00 (N-05).
nonisolated struct ExpiringProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExpiringWidgetEntry {
        ExpiringWidgetEntry(date: .now, content: ExpiringTimelineContent(date: .now, rows: [], hasSnapshot: true, topSpaceID: nil))
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (ExpiringWidgetEntry) -> Void) {
        let content = WidgetTimelinePlanner.expiringContent(snapshot: WidgetSnapshotStore.appGroup()?.read(), at: .now,
                                                            calendar: .current)
        completion(ExpiringWidgetEntry(date: .now, content: content))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ExpiringWidgetEntry>) -> Void) {
        let now = Date.now
        let contents = WidgetTimelinePlanner.expiringTimeline(snapshot: WidgetSnapshotStore.appGroup()?.read(), now: now,
                                                              calendar: .current)
        completion(Timeline(entries: contents.map { ExpiringWidgetEntry(date: $0.date, content: $0) },
                            policy: .after(WidgetTimelinePlanner.nextReload(after: now, calendar: .current))))
    }
}

/// "Expiring soon" (W1 A, W2 A, W3 A/A): a tap opens Inventory grouped by expiry, like the expiry notifications.
struct ExpiringSoonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.expiring, provider: ExpiringProvider()) { entry in
            ExpiringWidgetView(content: entry.content)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(LarariDeepLink.inventoryExpiring(spaceID: entry.content.topSpaceID).url)
        }
        .configurationDisplayName("widget.expiring.name")
        .description("widget.expiring.description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct ExpiringWidgetView: View {
    let content: ExpiringTimelineContent
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: ExpiringCircularView(content: content)
        case .accessoryRectangular: ExpiringRectangularView(content: content)
        case .systemMedium: ExpiringListView(content: content, limit: 4, singleLine: true)
        default: ExpiringListView(content: content, limit: 2, singleLine: false)     // systemSmall and StandBy
        }
    }
}

/// Home Screen and StandBy: "Expiring soon · 3", then rows with the coloured glyph, name and relative label. The
/// medium family puts the label on the name's line, so four rows fit its height.
struct ExpiringListView: View {
    let content: ExpiringTimelineContent
    let limit: Int
    let singleLine: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("widget.expiring.title")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetPalette.mocha)
                    .widgetAccentable()
                Spacer()
                if !content.rows.isEmpty {
                    Text(verbatim: "\(content.rows.count)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            if !content.hasSnapshot {
                Text("widget.openApp").font(.footnote).foregroundStyle(.secondary)
            } else if content.rows.isEmpty {
                Label("widget.expiring.none", systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: singleLine ? 4 : 6) {
                    ForEach(content.rows.prefix(limit)) { row in
                        ExpiringRowView(row: row, singleLine: singleLine)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct ExpiringRowView: View {
    let row: ExpiringRow
    let singleLine: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: WidgetExpiryText.symbol(row.level))
                .foregroundStyle(WidgetExpiryText.color(row.level))
                .widgetAccentable()
                .accessibilityHidden(true)
            if singleLine {
                Text(verbatim: row.item.name).font(.subheadline).lineLimit(1)
                Spacer(minLength: 6)
                label.layoutPriority(1)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: row.item.name).font(.subheadline).lineLimit(1)
                    label.minimumScaleFactor(0.8)       // systemSmall: a long label shrinks a little before it truncates
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var label: some View {
        WidgetExpiryText.label(daysLeft: row.daysLeft)
            .font(.caption)
            .foregroundStyle(WidgetExpiryText.color(row.level))
            .lineLimit(1)
    }
}

/// Lock Screen circle: a clock over the attention count.
struct ExpiringCircularView: View {
    let content: ExpiringTimelineContent

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "clock")
                    .font(.caption)
                    .widgetAccentable()
                Text(verbatim: content.hasSnapshot ? "\(content.rows.count)" : "–")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.hasSnapshot ? Text("widget.expiring.count \(content.rows.count)") : Text("widget.openApp"))
    }
}

/// Lock Screen rectangle: "3 expiring soon", then the first item and its label.
struct ExpiringRectangularView: View {
    let content: ExpiringTimelineContent

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if content.hasSnapshot {        // no snapshot yet: only "open the app", not "0 expiring soon"
                Label {
                    Text("widget.expiring.count \(content.rows.count)").font(.headline)
                } icon: {
                    Image(systemName: "clock").widgetAccentable()
                }
            }
            if let first = content.rows.first {
                HStack(spacing: 4) {
                    Text(verbatim: first.item.name).lineLimit(1)
                    WidgetExpiryText.label(daysLeft: first.daysLeft).foregroundStyle(.secondary)
                }
                .font(.caption)
            } else if !content.hasSnapshot {
                Text("widget.openApp").font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
