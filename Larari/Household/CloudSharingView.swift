import CloudKit
import LarariCore
import UIKit

/// The system sharing UI (participants, Add People, permissions; Remove Me for a participant).
///
/// Presented with UIKit from the top view controller, as Apple's CoreDataCloudKitShare sample and the P0-01 spike do.
/// Wrapped in a SwiftUI `.sheet` it closed itself at once and took the settings sheet under it along (C-02).
@MainActor
enum CloudSharingPresenter {
    /// The delegate of the controller on screen; `UICloudSharingController.delegate` is weak.
    private static var current: Coordinator?

    static func present(share: CKShare, space: Space, sharing: SharingService,
                        onError: @escaping @MainActor (String) -> Void) {
        guard let top = topViewController() else { return }
        let coordinator = Coordinator(space: space, title: space.name, zoneID: share.recordID.zoneID,
                                      wasOwner: sharing.role(for: space) == .owner, sharing: sharing, onError: onError)
        let controller = UICloudSharingController(share: share, container: CKContainer(identifier: AppModel.containerIdentifier))
        controller.availablePermissions = [.allowPrivate, .allowReadOnly, .allowReadWrite]
        controller.delegate = coordinator
        controller.popoverPresentationController?.sourceView = top.view
        current = coordinator
        top.present(controller, animated: true)
    }

    /// The topmost presented controller of the foreground key window, so the controller opens over the settings sheet.
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    @MainActor
    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        private let space: Space
        private let title: String
        private let zoneID: CKRecordZone.ID
        private let wasOwner: Bool
        private let sharing: SharingService
        private let onError: @MainActor (String) -> Void

        init(space: Space, title: String, zoneID: CKRecordZone.ID, wasOwner: Bool,
             sharing: SharingService, onError: @escaping @MainActor (String) -> Void) {
            self.space = space
            self.title = title
            self.zoneID = zoneID
            self.wasOwner = wasOwner
            self.sharing = sharing
            self.onError = onError
        }

        func itemTitle(for csc: UICloudSharingController) -> String? { title }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            onError(error.localizedDescription)
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            guard let share = csc.share else { return }
            Task {
                do { try await sharing.saveUpdatedShare(share, for: space) }
                catch { onError(error.localizedDescription) }
            }
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            Task {
                do { try await sharing.sharingStopped(for: space, zoneID: zoneID, wasOwner: wasOwner) }
                catch { onError(error.localizedDescription) }
            }
        }
    }
}
