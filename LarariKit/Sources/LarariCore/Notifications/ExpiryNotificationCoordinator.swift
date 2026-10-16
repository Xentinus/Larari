import CoreData
import Foundation
import Observation

/// Recomputes the notification schedule and the badge. Trigger names are the hooks P5-04 uses. Every refresh reads
/// the summary switches (P2-10a), so a kind switched off in Settings leaves the schedule on the next refresh, and the
/// Ikonjelvény values (P2-10b), so the badge counts what Settings asks for.
@MainActor
@Observable
public final class ExpiryNotificationCoordinator {
    public enum Trigger: String, Sendable { case foreground, localSave, remoteChange }

    public private(set) var lastPlan: [PlannedNotification] = []
    public private(set) var lastBadgeCount: Int?
    public private(set) var lastTrigger: Trigger?
    public private(set) var pendingRefresh: Task<Void, Never>?

    private let context: NSManagedObjectContext
    private let center: any NotificationCentering
    private let scheduler: NotificationScheduler
    private let preferences: NotificationPreferences
    private let calendar: Calendar
    private let locale: Locale
    private let debounce: Duration
    private let now: @MainActor () -> Date

    public init(context: NSManagedObjectContext, center: any NotificationCentering,
                preferences: NotificationPreferences = NotificationPreferences(defaults: .standard),
                calendar: Calendar = .current,
                locale: Locale = .current, debounce: Duration = .milliseconds(500),
                now: @escaping @MainActor () -> Date = { .now }) {
        self.context = context
        self.center = center
        self.scheduler = NotificationScheduler(center: center)
        self.preferences = preferences
        self.calendar = calendar
        self.locale = locale
        self.debounce = debounce
        self.now = now
    }

    public func refresh() async {
        let date = now()
        let snapshots = (try? BadgeCounter.snapshots(in: context, now: date, calendar: calendar)) ?? []
        let count = (try? BadgeCounter.count(preferences.badge, in: context, now: date, calendar: calendar)) ?? 0
        let plan = NotificationPlanner.plan(items: snapshots, now: date, calendar: calendar, locale: locale,
                                            kinds: preferences.kinds)
        lastPlan = await scheduler.reschedule(plan)
        try? await center.setBadgeCount(count)
        lastBadgeCount = count
    }

    /// Coalesces bursts (a save storm, several remote changes) into one refresh after `debounce`.
    public func scheduleRefresh(_ trigger: Trigger) {
        lastTrigger = trigger
        pendingRefresh?.cancel()
        let delay = debounce
        pendingRefresh = Task { [weak self] in
            if delay > .zero {
                do { try await Task.sleep(for: delay) } catch { return }
            }
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }
}
