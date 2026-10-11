import Foundation

/// Hands a tick from an App Intent to the app (N-04; N-05's widget tick reuses it). The app registers its handler in
/// `application(_:didFinishLaunchingWithOptions:)`, which also runs when the system launches the app in the
/// background for a `LiveActivityIntent`. The widget extension never registers one, so there `tick` returns false.
@MainActor
public enum ShoppingTickBridge {
    /// Returns whether the app took the tick (false: it has no services, e.g. the account is unavailable), so the
    /// widget's intent can fall back to its queue instead of losing the tick.
    public typealias Handler = @MainActor ([UUID]) async -> Bool

    private static var handler: Handler?

    public static var isRegistered: Bool { handler != nil }

    public static func register(_ handler: @escaping Handler) {
        self.handler = handler
    }

    public static func unregister() {
        handler = nil
    }

    /// False without a handler or when the handler could not take the tick.
    @discardableResult
    public static func tick(_ itemIDs: [UUID]) async -> Bool {
        guard let handler else { return false }
        return await handler(itemIDs)
    }
}
