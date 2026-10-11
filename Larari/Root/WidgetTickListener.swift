import CoreFoundation
import Foundation
import LarariShared

/// The extension's "a tick is queued" ping (iOS 26 path, N-05). Darwin notifications reach the app only while it
/// runs; every completed share refresh (launch and foreground) drains the queue as well (`AppModel`).
enum WidgetTickListener {
    private static var handler: (@MainActor () -> Void)?

    static func start(_ handler: @escaping @MainActor () -> Void) {
        let isFirst = self.handler == nil
        self.handler = handler
        guard isFirst else { return }
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, widgetTickCallback,
                                        WidgetTickPing.name as CFString, nil, .deliverImmediately)
    }

    static func fire() {
        handler?()
    }
}

/// A plain C callback: no captures, no actor isolation.
private nonisolated func widgetTickCallback(_ center: CFNotificationCenter?, _ observer: UnsafeMutableRawPointer?,
                                           _ name: CFNotificationName?, _ object: UnsafeRawPointer?,
                                           _ userInfo: CFDictionary?) {
    Task { @MainActor in WidgetTickListener.fire() }
}
