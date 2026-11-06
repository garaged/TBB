#if canImport(SwiftUI) && canImport(CloudKit) && canImport(UIKit)
import CloudKit
import SwiftUI
import TBBFoundation
import UIKit

struct HouseholdHomeView: View {
    @ObservedObject var model: LedgerViewModel
    @State private var shareSession: ShareSheetSession?

    var body: some View {
        Form {
            Section("Current budget") {
                Picker("Budget space", selection: selectedSpaceID) {
                    ForEach(model.spaces) { space in
                        Text(space.name).tag(Optional(space.id))
                    }
                }
                .accessibilityLabel("Active household budget")
                if let active = model.activeSpace {
                    Label(active.scope == .shared ? "Shared household budget" : "Private budget", systemImage: active.scope == .shared ? "person.2.fill" : "lock.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Sharing") {
                if let active = model.activeSpace, active.role == .owner {
                    Button(active.scope == .shared ? "Manage household sharing" : "Share household budget") {
                        Task {
                            if let session = await model.createOrFetchShareForActiveSpace() {
                                shareSession = .init(value: session)
                            }
                        }
                    }
                    .accessibilityLabel(active.scope == .shared ? "Manage household sharing" : "Share household budget")
                    Text("TBB uses Apple’s private CloudKit sharing. It does not create a TBB account or send your financial data to a TBB server.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let active = model.activeSpace {
                    Label("This budget is shared with you", systemImage: "person.2.fill")
                    Text("The owner manages participants. Your local lock and Privacy Mode remain private to this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No household budget is available yet.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Privacy") {
                Text("Privacy Mode masks amounts only on this device. It does not change the shared records or another participant’s display.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Household")
        .sheet(item: $shareSession) { session in
            SystemCloudSharingSheet(session: session.value)
        }
        .alert("Household sharing", isPresented: errorIsPresented) {
            Button("OK") { model.dismissError() }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var selectedSpaceID: Binding<UUID?> {
        .init(
            get: { model.activeSpace?.id },
            set: { if let id = $0 { model.selectBudgetSpace(id: id) } }
        )
    }

    private var errorIsPresented: Binding<Bool> {
        .init(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.dismissError() } }
        )
    }
}

private struct ShareSheetSession: Identifiable {
    let id = UUID()
    let value: CloudKitShareSession
}

private struct SystemCloudSharingSheet: UIViewControllerRepresentable {
    let session: CloudKitShareSession

    func makeUIViewController(context: Context) -> UICloudSharingController {
        UICloudSharingController(share: session.share, container: session.container)
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}
#endif
