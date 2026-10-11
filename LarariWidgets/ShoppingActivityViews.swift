import LarariShared
import SwiftUI
import WidgetKit

/// Lock Screen banner (D1, reworked in N-05): store and household on the left, how many items are left to buy here
/// on the right, a thin progress bar with "2 of 7 done" below. No item rows: the banner has to fit the system's
/// 160 pt limit at every text size, and ticking happens in the app (the tap opens it).
struct ShoppingLockScreenView: View {
    let state: ShoppingActivityContent
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ActivityTitle(state: state)
                Spacer(minLength: 8)
                if !state.isFinished {                                   // the "All done" row says it below
                    ActivityBigCount(state: state)
                }
            }
            if state.isFinished {
                Label("activity.done", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(WidgetPalette.mocha)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ActivityProgressBar(state: state)
                    Text("activity.progress \(state.doneCount) \(state.totalCount)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)                       // the bar says it
                }
            }
            if isStale {
                Text("activity.stale")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

/// The store (or chain) and, below, the household with the list count from two lists up.
struct ActivityTitle: View {
    let state: ShoppingActivityContent

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: state.title)
                .font(.headline)
                .lineLimit(1)
            Group {
                if state.listCount >= 2 {
                    Text("activity.subtitle.lists \(state.spaceName) \(state.listCount)")
                } else {
                    Text(verbatim: state.spaceName)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The number of items left to buy here, large, with "to buy here" below (N-05 Live Activity rework, option A).
struct ActivityBigCount: View {
    let state: ShoppingActivityContent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(verbatim: "\(state.remainingCount)")
                .font(.largeTitle.bold())
                .monospacedDigit()
                .contentTransition(reduceMotion ? .identity : .numericText())
                .foregroundStyle(WidgetPalette.mocha)
            Text("activity.toBuyHere")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .fixedSize()                                                     // a long title truncates, not the count
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("activity.remaining \(state.remainingCount)"))
    }
}

/// Compact trailing and minimal presentation (D2 A): the remaining count, a check when done.
struct ActivityCount: View {
    let state: ShoppingActivityContent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if state.isFinished {
                Image(systemName: "checkmark")
            } else {
                Text(verbatim: "\(state.remainingCount)")
                    .monospacedDigit()
                    .contentTransition(reduceMotion ? .identity : .numericText())
            }
        }
        .foregroundStyle(WidgetPalette.mocha)
        .accessibilityLabel(state.isFinished ? Text("activity.done")
                                             : Text("activity.remaining \(state.remainingCount)"))
    }
}

struct ActivityProgressBar: View {
    let state: ShoppingActivityContent

    var body: some View {
        ProgressView(value: Double(state.doneCount), total: Double(max(state.totalCount, 1)))
            .tint(WidgetPalette.mocha)
            .accessibilityLabel(Text("activity.progress \(state.doneCount) \(state.totalCount)"))
    }
}
