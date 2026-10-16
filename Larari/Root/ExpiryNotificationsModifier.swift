import Combine
import CoreData
import LarariCore
import SwiftUI

/// Keeps the 07:00 summaries and the badge current: on foreground, after local saves, after remote changes, and
/// when a summary switch or the Ikonjelvény values in Settings ▸ Larari change while the app runs (P2-10a, P2-10b).
private struct ExpiryNotificationsModifier: ViewModifier {
    let coordinator: ExpiryNotificationCoordinator
    let context: NSManagedObjectContext
    let preferences: NotificationPreferences
    @Environment(\.scenePhase) private var scenePhase
    /// The values a refresh depends on, as last seen, so other defaults changes (there are many) do not reschedule.
    private struct Watched: Equatable {
        var kinds: NotificationKinds
        var badge: BadgeContent
    }
    @State private var watched: Watched?

    private var current: Watched { Watched(kinds: preferences.kinds, badge: preferences.badge) }

    func body(content: Content) -> some View {
        content
            .task {
                watched = current
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
                let now = current
                guard now != watched else { return }
                watched = now
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
