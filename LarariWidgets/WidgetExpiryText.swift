import LarariShared
import SwiftUI

/// The app's expiry wording inside the 14-day window ("Holnap lejár", "Még 3 nap", "2 napja lejárt"), with the
/// app's colours: yellow clock within 14 days, red exclamation mark once expired (README "Card layout").
enum WidgetExpiryText {
    static func label(daysLeft: Int) -> Text {
        switch daysLeft {
        case ..<(-1): Text("widget.expiry.daysAgo \(-daysLeft)")
        case -1: Text("widget.expiry.yesterday")
        case 0: Text("widget.expiry.today")
        case 1: Text("widget.expiry.tomorrow")
        default: Text("widget.expiry.daysLeft \(daysLeft)")
        }
    }

    static func symbol(_ level: SnapshotExpiryLevel) -> String {
        level == .expired ? "exclamationmark.circle.fill" : "clock.fill"
    }

    static func color(_ level: SnapshotExpiryLevel) -> Color {
        level == .expired ? WidgetPalette.critical : WidgetPalette.soon
    }
}
