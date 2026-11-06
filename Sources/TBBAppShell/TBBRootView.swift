#if canImport(SwiftUI) && canImport(CommonCrypto) && canImport(Security) && canImport(LocalAuthentication)
import SwiftUI
import TBBFoundation

public struct TBBRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var lockController = AppLockController()
    @StateObject private var ledgerModel = LedgerViewModel()
    @State private var privacyMode: PrivacyMode = .revealed
    @State private var showingSecurity = false
    @State private var password = ""

    public init() {}

    public var body: some View {
        Group {
            if lockController.state == .locked { lockedView } else { applicationTabs }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .background { lockController.lockForBackground() } }
        .onAppear {
            #if canImport(CloudKit)
            HouseholdInvitationRouter.register { metadata in
                ledgerModel.acceptShareInvitation(metadata)
            }
            #endif
        }
    }

    private var applicationTabs: some View {
        TabView {
            NavigationStack {
                LedgerHomeView(privacyMode: privacyMode, model: ledgerModel)
                    .toolbar { globalToolbar }
            }
            .tabItem { Label("Overview", systemImage: "list.bullet") }

            NavigationStack {
                DashboardHomeView(privacyMode: privacyMode, model: ledgerModel)
                    .toolbar { globalToolbar }
            }
            .tabItem { Label("Dashboard", systemImage: "chart.bar") }

            NavigationStack {
                BudgetHomeView(privacyMode: privacyMode, model: ledgerModel)
                    .toolbar { globalToolbar }
            }
            .tabItem { Label("Budgets", systemImage: "target") }

            #if canImport(CloudKit) && canImport(UIKit)
            NavigationStack {
                HouseholdHomeView(model: ledgerModel)
                    .toolbar { globalToolbar }
            }
            .tabItem { Label("Household", systemImage: "person.2") }
            #endif
        }
        .sheet(isPresented: $showingSecurity) { SecuritySettingsView(controller: lockController) }
    }

    @ToolbarContentBuilder
    private var globalToolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button { privacyMode.toggle() } label: { Image(systemName: privacyMode == .revealed ? "eye" : "eye.slash") }
                .accessibilityLabel(privacyMode == .revealed ? "Hide monetary amounts" : "Show monetary amounts")
        }
        ToolbarItem(placement: .automatic) {
            Button { showingSecurity = true } label: { Image(systemName: "lock") }
                .accessibilityLabel("Security settings")
        }
    }

    private var lockedView: some View {
        VStack(spacing: 20) {
            ContentUnavailableView("TBB is locked", systemImage: "lock.fill", description: Text("Authenticate to view your financial information."))
            Button("Unlock with Face ID or device passcode") { Task { await lockController.unlockWithDeviceAuthentication() } }
            SecureField("Local password", text: $password).textContentType(.password).padding(.horizontal)
            Button("Unlock") { lockController.unlockWithPassword(password); password = "" }
            if let message = lockController.errorMessage { Text(message).foregroundStyle(.red).font(.footnote) }
        }.padding()
    }
}

private struct SecuritySettingsView: View {
    @ObservedObject var controller: AppLockController
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Local lock") {
                    if controller.isPasswordConfigured {
                        Text("A local password is configured for this device.")
                        Button("Remove local password", role: .destructive) { controller.removePassword() }
                    } else {
                        SecureField("New password", text: $password).textContentType(.newPassword)
                        SecureField("Confirm password", text: $confirmation).textContentType(.newPassword)
                        Button("Enable local lock") { controller.setPassword(password, confirmation: confirmation); if controller.isPasswordConfigured { password = ""; confirmation = "" } }
                    }
                    Text("Face ID, Touch ID, or device passcode can unlock TBB after a local password is configured.").font(.footnote).foregroundStyle(.secondary)
                }
                if let message = controller.errorMessage { Section { Text(message).foregroundStyle(.red) } }
            }.navigationTitle("Security").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
#endif
