import Foundation
import Network

/// Whether the device has a usable network path, for calls that would otherwise block while offline (C-02: NSPCKC's
/// share call waits over a minute before it answers). Starts as online until the first path update arrives.
@MainActor
public final class NetworkPathMonitor {
    public private(set) var isOnline = true
    /// Called on every path update (the sync status shows "Can't reach iCloud" while offline, C-02).
    public var onChange: (@MainActor (Bool) -> Void)?
    private let monitor = NWPathMonitor()

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                self?.isOnline = online
                self?.onChange?(online)
            }
        }
        monitor.start(queue: DispatchQueue(label: "app.larari.network-path"))
    }

    deinit {
        monitor.cancel()
    }
}
