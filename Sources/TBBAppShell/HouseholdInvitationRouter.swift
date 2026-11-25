#if canImport(CloudKit)
import CloudKit

@MainActor
enum HouseholdInvitationRouter {
    private static var pending: [CKShare.Metadata] = []
    private static var receiver: ((CKShare.Metadata) -> Void)?

    static func register(_ handler: @escaping (CKShare.Metadata) -> Void) {
        receiver = handler
        let invitations = pending
        pending.removeAll()
        invitations.forEach(handler)
    }

    static func route(_ metadata: CKShare.Metadata) {
        if let receiver {
            receiver(metadata)
        } else {
            pending.append(metadata)
        }
    }
}
#endif
