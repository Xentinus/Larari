#if DEBUG
import LarariCore
import SwiftUI

/// The summary switches as nearly invisible text, "daily weekly" or a part of it (P2-10a); only under UI tests.
struct UITestNotificationKindsProbe: View {
    let preferences: NotificationPreferences

    var body: some View {
        let kinds = preferences.kinds
        Text(verbatim: [kinds.contains(.daily) ? "daily" : nil, kinds.contains(.weekly) ? "weekly" : nil]
            .compactMap { $0 }.joined(separator: " "))
            .font(.caption2)
            .opacity(0.02)
            .allowsHitTesting(false)
            .accessibilityIdentifier("uiTest.notificationKinds")
    }
}
#endif
