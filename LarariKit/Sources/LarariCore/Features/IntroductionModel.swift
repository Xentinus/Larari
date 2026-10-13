import Foundation
import Observation

/// The pages of the animated introduction (spec 2026-09-26-animated-introduction-design.md), in order. `purchase`
/// asks whether purchases go into inventory by default (P4-07, I-A).
public enum IntroductionPage: Int, CaseIterable, Identifiable, Sendable {
    case welcome, free, inventory, shopping, purchase, spaces, privacy, notifications
    public var id: Int { rawValue }
}

/// First-launch introduction. Shown once; finishing or skipping hides it for good.
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

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let notifications: any NotificationAuthorizing
    @ObservationIgnored private let purchaseDefaults: PurchaseDefaults
    @ObservationIgnored private var hasRequestedPermission = false

    /// `purchaseDefaults` defaults to the same `defaults`.
    public init(defaults: UserDefaults = .standard, notifications: any NotificationAuthorizing,
                purchaseDefaults: PurchaseDefaults? = nil) {
        self.defaults = defaults
        self.notifications = notifications
        let purchase = purchaseDefaults ?? PurchaseDefaults(defaults: defaults)
        self.purchaseDefaults = purchase
        hasSeenIntroduction = defaults.bool(forKey: Self.defaultsKey)
        addsToInventory = purchase.addsToInventory
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

    /// "Get started": hides the introduction, then asks for notification permission once.
    /// The answer does not matter; declining changes nothing else in the app.
    public func finish() async {
        let wasShowing = !hasSeenIntroduction
        markSeen()
        guard wasShowing, !hasRequestedPermission else { return }
        hasRequestedPermission = true
        _ = try? await notifications.requestAuthorization()
    }

    private func markSeen() {
        hasSeenIntroduction = true
        defaults.set(true, forKey: Self.defaultsKey)
    }
}
