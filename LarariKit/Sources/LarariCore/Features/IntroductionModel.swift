import Foundation
import Observation

/// The introduction's pages, in order (P1-10b, user picks A and X): the Apple Welcome page, whether purchases go into
/// inventory by default (P4-07, I-A), which expiry summaries to send (P2-10a), and the store reminders (P4-06). Each
/// permission is asked on its own page, which also has "Not now".
public enum IntroductionPage: Int, CaseIterable, Identifiable, Sendable {
    case welcome, purchase, notifications, stores
    public var id: Int { rawValue }
}

/// First-launch introduction. Shown once; finishing, "Not now" on the last page or skipping hides it for good.
@MainActor
@Observable
public final class IntroductionModel {
    public static let defaultsKey = "hasSeenIntroduction"

    public private(set) var hasSeenIntroduction: Bool
    public var currentPage: IntroductionPage = .welcome
    /// The `purchase` page's answer, written to the setting as soon as it changes, so a later swipe or "Get started"
    /// keeps it and "Skip" before touching it writes nothing.
    public var addsToInventory: Bool {
        didSet {
            guard addsToInventory != oldValue else { return }
            purchaseDefaults.addsToInventory = addsToInventory
        }
    }

    /// The `notifications` page's selection, written by its "Next" only when notifications are allowed.
    public var summaryChoice: NotificationKinds
    /// A permission prompt is up; the page's buttons wait for it.
    public private(set) var isAsking = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let notifications: any NotificationAuthorizing
    @ObservationIgnored private let location: (any LocationAuthorizing)?
    @ObservationIgnored private let purchaseDefaults: PurchaseDefaults
    @ObservationIgnored private let notificationPreferences: NotificationPreferences
    @ObservationIgnored private let storeReminders: StoreReminderPreference
    @ObservationIgnored private let followUpFlags: PermissionFollowUpFlags
    @ObservationIgnored private var hasAskedNotifications = false
    @ObservationIgnored private var notificationsGranted = false

    /// Every store defaults to the same `defaults`. Without `location` (UI tests), "Get started" asks for none.
    public init(defaults: UserDefaults = .standard, notifications: any NotificationAuthorizing,
                location: (any LocationAuthorizing)? = nil, purchaseDefaults: PurchaseDefaults? = nil,
                notificationPreferences: NotificationPreferences? = nil,
                storeReminders: StoreReminderPreference? = nil, followUpFlags: PermissionFollowUpFlags? = nil) {
        self.defaults = defaults
        self.notifications = notifications
        self.location = location
        let purchase = purchaseDefaults ?? PurchaseDefaults(defaults: defaults)
        self.purchaseDefaults = purchase
        let preferences = notificationPreferences ?? NotificationPreferences(defaults: defaults)
        self.notificationPreferences = preferences
        self.storeReminders = storeReminders ?? StoreReminderPreference(defaults: defaults)
        self.followUpFlags = followUpFlags ?? PermissionFollowUpFlags(defaults: defaults)
        hasSeenIntroduction = defaults.bool(forKey: Self.defaultsKey)
        addsToInventory = purchase.addsToInventory
        summaryChoice = preferences.kinds.isEmpty ? .all : preferences.kinds
    }

    public var shouldShow: Bool { !hasSeenIntroduction }

    public var isOnLastPage: Bool { currentPage == IntroductionPage.allCases.last }

    /// The pages with their own "Not now" have no Skip.
    public var asksPermission: Bool { currentPage == .notifications || currentPage == .stores }

    public func next() {
        if let following = IntroductionPage(rawValue: currentPage.rawValue + 1) {
            currentPage = following
        }
    }

    /// "Skip": hides the introduction without any prompt, and writes nothing.
    public func skip() {
        markSeen()
    }

    /// The notifications page's "Next": asks for notification permission once. Allowed, the summary choice becomes
    /// the Settings switches; declined (or failed), nothing is written (P2-10a, D-B). Then the store page.
    public func allowNotifications() async {
        guard !isAsking else { return }
        if !hasAskedNotifications {
            isAsking = true
            notificationsGranted = await askNotifications()
            isAsking = false
        }
        if notificationsGranted {
            notificationPreferences.set(summaryChoice)       // also a changed choice after swiping back
        }
        next()
    }

    /// The notifications page's "Not now": both summaries off, no prompt; a switch turned on later asks (2A).
    public func declineNotifications() {
        guard !isAsking else { return }
        notificationPreferences.set([])
        followUpFlags.asksNotifications = true
        next()
    }

    /// "Get started" on the store page: store reminders on, then location (When In Use), and notifications too when
    /// the notifications page said "Not now", since a store reminder is a notification. The introduction closes.
    public func finish() async {
        guard !hasSeenIntroduction, !isAsking else { return }
        isAsking = true
        storeReminders.isEnabled = true
        if let location, location.access == .notDetermined {
            _ = await location.requestWhenInUse()
        }
        if !hasAskedNotifications {
            _ = await askNotifications()
            followUpFlags.asksNotifications = false
        }
        isAsking = false
        markSeen()
    }

    /// The store page's "Not now": store reminders off, no prompt; switched on later, location is asked (2A).
    public func declineStoreReminders() {
        guard !isAsking else { return }
        storeReminders.isEnabled = false
        followUpFlags.asksLocation = true
        markSeen()
    }

    private func askNotifications() async -> Bool {
        hasAskedNotifications = true
        return (try? await notifications.requestAuthorization()) ?? false
    }

    private func markSeen() {
        hasSeenIntroduction = true
        defaults.set(true, forKey: Self.defaultsKey)
    }
}
