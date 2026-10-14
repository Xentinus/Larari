import Combine
import CoreData
import LarariCore
import SwiftUI

/// Keeps the 07:00 summaries and the badge current: on foreground, after local saves, after remote changes, and
/// when a summary switch in Settings ▸ Larari changes while the app runs (P2-10a).
private struct ExpiryNotificationsModifier: ViewModifier {
    let coordinator: ExpiryNotificationCoordinator
    let context: NSManagedObjectContext
    let preferences: NotificationPreferences
    @Environment(\.scenePhase) private var scenePhase
    /// The switches as last seen, so other defaults changes (there are many) do not reschedule.
    @State private var kinds: NotificationKinds?

    func body(content: Content) -> some View {
        content
            .task {
                kinds = preferences.kinds
                coordinator.scheduleRefresh(.foreground)
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active { coordinator.scheduleRefresh(.foreground) }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSManagedObjectContext.didSaveObjectsNotification,
                                                            object: context)
                        .receive(on: DispatchQueue.main)) { _ in
                coordinator.scheduleRefresh(.localSave)
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
                        .receive(on: DispatchQueue.main)) { _ in
                coordinator.scheduleRefresh(.remoteChange)
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
                        .receive(on: DispatchQueue.main)) { _ in
                let current = preferences.kinds
                guard current != kinds else { return }
                kinds = current
                coordinator.scheduleRefresh(.foreground)
            }
    }
}

extension View {
    func expiryNotifications(_ coordinator: ExpiryNotificationCoordinator, context: NSManagedObjectContext,
                             preferences: NotificationPreferences) -> some View {
        modifier(ExpiryNotificationsModifier(coordinator: coordinator, context: context, preferences: preferences))
    }
}
