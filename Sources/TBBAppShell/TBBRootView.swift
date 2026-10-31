#if canImport(SwiftUI) && canImport(CommonCrypto) && canImport(Security) && canImport(LocalAuthentication)
import SwiftUI
import TBBFoundation

public struct TBBRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var lockController = AppLockController()
    @State private var privacyMode: PrivacyMode = .revealed
    @State private var showingSecurity = false
    @State private var password = ""

    public init() {}

    public var body: some View {
        Group {
            if lockController.state == .locked {
                lockedView
            } else {
                overview
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                lockController.lockForBackground()
            }
        }
    }

    private var lockedView: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                "TBB is locked",
                systemImage: "lock.fill",
                description: Text("Authenticate to view your financial information.")
            )
            Button("Unlock with Face ID or device passcode") {
                Task { await lockController.unlockWithDeviceAuthentication() }
            }
            SecureField("Local password", text: $password)
                .textContentType(.password)
                .padding(.horizontal)
            Button("Unlock") {
                lockController.unlockWithPassword(password)
                password = ""
            }
            if let message = lockController.errorMessage {
                Text(message).foregroundStyle(.red).font(.footnote)
            }
        }
        .padding()
    }

    private var overview: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Thy Budget Buddy")
                    .font(.largeTitle.bold())
                Text(PrivacyPresentation(mode: privacyMode).amount("$0.00"))
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .accessibilityLabel(PrivacyPresentation(mode: privacyMode).accessibilitySummary)
                Text("Your first budget will appear here.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        privacyMode.toggle()
                    } label: {
                        Image(systemName: privacyMode == .revealed ? "eye" : "eye.slash")
                    }
                    .accessibilityLabel(privacyMode == .revealed ? "Hide monetary amounts" : "Show monetary amounts")
                    .accessibilityHint("Changes only this device's display.")
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingSecurity = true
                    } label: {
                        Image(systemName: "lock")
                    }
                    .accessibilityLabel("Security settings")
                }
            }
            .sheet(isPresented: $showingSecurity) {
                SecuritySettingsView(controller: lockController)
            }
        }
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
                        Button("Remove local password", role: .destructive) {
                            controller.removePassword()
                        }
                    } else {
                        SecureField("New password", text: $password)
                            .textContentType(.newPassword)
                        SecureField("Confirm password", text: $confirmation)
                            .textContentType(.newPassword)
                        Button("Enable local lock") {
                            controller.setPassword(password, confirmation: confirmation)
                            if controller.isPasswordConfigured {
                                password = ""
                                confirmation = ""
                            }
                        }
                    }
                    Text("Face ID, Touch ID, or device passcode can unlock TBB after a local password is configured.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let message = controller.errorMessage {
                    Section {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Security")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif
