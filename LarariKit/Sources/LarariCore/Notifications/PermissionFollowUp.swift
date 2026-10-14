import Foundation

/// What the introduction's "Not now" left to ask (P1-10b, 2A): set there, cleared once the permission was asked.
@MainActor
public struct PermissionFollowUpFlags {
    public static let notificationsKey = "asksNotificationsWhenEnabled"
    public static let locationKey = "asksLocationWhenEnabled"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var asksNotifications: Bool {
        get { defaults.bool(forKey: Self.notificationsKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.notificationsKey) }
    }

    public var asksLocation: Bool {
        get { defaults.bool(forKey: Self.locationKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.locationKey) }
    }
}

/// After "Not now" in the introduction, a switch turned on later in Settings ▸ Larari asks for its permission once,
/// on the next foreground (P1-10b, 2A): any summary or the store reminders → notifications; the store reminders →
/// location (When In Use). Without that request Larari never appears in the system's notification settings.
@MainActor
public final class PermissionFollowUp {
    private let flags: PermissionFollowUpFlags
    private let notificationPreferences: NotificationPreferences
    private let storeReminders: StoreReminderPreference
    private let notifications: any NotificationAuthorizing
    private let location: (any LocationAuthorizing)?
    private var isChecking = false

    /// The flags and both switches live in `defaults`.
    public init(defaults: UserDefaults, notifications: any NotificationAuthorizing,
                location: (any LocationAuthorizing)?) {
        flags = PermissionFollowUpFlags(defaults: defaults)
        notificationPreferences = NotificationPreferences(defaults: defaults)
        storeReminders = StoreReminderPreference(defaults: defaults)
        self.notifications = notifications
        self.location = location
    }

    /// Call on every foreground once the introduction is over. Each flag is cleared before its prompt, so overlapping
    /// calls (two windows) ask once.
    public func check() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        if flags.asksNotifications, !notificationPreferences.kinds.isEmpty || storeReminders.isEnabled {
            flags.asksNotifications = false
            _ = try? await notifications.requestAuthorization()
        }
        if flags.asksLocation, storeReminders.isEnabled, let location {
            flags.asksLocation = false
            if location.access == .notDetermined { _ = await location.requestWhenInUse() }
        }
    }
}
