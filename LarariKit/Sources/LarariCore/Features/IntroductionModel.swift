import Foundation
import Observation

/// The pages of the animated introduction (spec 2026-09-26-animated-introduction-design.md), in order. `purchase`
/// asks whether purchases go into inventory by default (P4-07, I-A).
public enum IntroductionPage: Int, CaseIterable, Identifiable, Sendable {
    case welcome, free, inventory, shopping, purchase, spaces, privacy, notifications
    public var id: Int { rawValue }
}

/// First-launch introduction. Shown once; finishing or skipping hides it for good. When "Get started" gets
/// notification permission, the summary choice (P2-10a, G-A) is asked over the last page, and the introduction
/// closes with it.
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

    /// The summary choice sheet is up: "Get started" got notification permission (P2-10a).
    public var showsSummaryChoice = false
    /// The sheet's selection, written by "Done" only; swiping the sheet away keeps the switches as they are.
    public var summaryChoice: NotificationKinds

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let notifications: any NotificationAuthorizing
    @ObservationIgnored private let purchaseDefaults: PurchaseDefaults
    @ObservationIgnored private let notificationPreferences: NotificationPreferences
    @ObservationIgnored private var hasRequestedPermission = false

    /// `purchaseDefaults` and `notificationPreferences` default to the same `defaults`.
    public init(defaults: UserDefaults = .standard, notifications: any NotificationAuthorizing,
                purchaseDefaults: PurchaseDefaults? = nil, notificationPreferences: NotificationPreferences? = nil) {
        self.defaults = defaults
        self.notifications = notifications
        let purchase = purchaseDefaults ?? PurchaseDefaults(defaults: defaults)
        self.purchaseDefaults = purchase
        let preferences = notificationPreferences ?? NotificationPreferences(defaults: defaults)
        self.notificationPreferences = preferences
        hasSeenIntroduction = defaults.bool(forKey: Self.defaultsKey)
        addsToInventory = purchase.addsToInventory
        summaryChoice = preferences.kinds.isEmpty ? .all : preferences.kinds
    }

    public var shouldShow: Bool { !hasSeenIntroduction }

    public var isOnLastPage: Bool { currentPage == IntroductionPage.allCases.last }

    public func next() {
        if let following = IntroductionPage(rawValue: currentPage.rawValue + 1) {
            currentPage = following
        }
    }

    /// "Skip": hides the introduction without the notification prompt.
    public func skip() {
        markSeen()
    }

    /// "Get started": asks for notification permission once. Allowed, the summary choice comes up and the
    /// introduction stays until it closes; declined (or failed), the introduction closes with nothing more said
    /// (P2-10a, D-B), and nothing else in the app changes.
    public func finish() async {
        guard !hasSeenIntroduction, !hasRequestedPermission else { return }
        hasRequestedPermission = true
        let granted = (try? await notifications.requestAuthorization()) ?? false
        if granted {
            showsSummaryChoice = true
        } else {
            markSeen()
        }
    }

    /// "Done" on the summary choice: writes the Settings switches and closes the sheet.
    public func confirmSummaryChoice() {
        notificationPreferences.set(summaryChoice)
        showsSummaryChoice = false
    }

    /// The summary choice sheet has gone, by "Done" or by a swipe: the introduction closes.
    public func summaryChoiceClosed() {
        showsSummaryChoice = false
        markSeen()
    }

    private func markSeen() {
        hasSeenIntroduction = true
        defaults.set(true, forKey: Self.defaultsKey)
    }
}
