#if DEBUG
import LarariCore
import SwiftUI

/// The summary switches as nearly invisible text, "daily weekly", a part of it or "none" (P2-10a), and the store
/// reminder switch, "on" or "off" (P1-10b); only under UI tests.
struct UITestNotificationKindsProbe: View {
    let preferences: NotificationPreferences

    var body: some View {
        let kinds = preferences.kinds
        let names = [kinds.contains(.daily) ? "daily" : nil, kinds.contains(.weekly) ? "weekly" : nil].compactMap { $0 }
        VStack {
            probe(names.isEmpty ? "none" : names.joined(separator: " "), identifier: "uiTest.notificationKinds")
            probe(StoreReminderSettings.isEnabled ? "on" : "off", identifier: "uiTest.storeReminders")
        }
    }

    private func probe(_ text: String, identifier: String) -> some View {
        Text(verbatim: text)
            .font(.caption2)
            .opacity(0.02)
            .allowsHitTesting(false)
            .accessibilityIdentifier(identifier)
    }
}
#endif
