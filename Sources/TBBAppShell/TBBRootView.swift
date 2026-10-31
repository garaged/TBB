#if canImport(SwiftUI)
import SwiftUI
import TBBFoundation

public struct TBBRootView: View {
    @State private var privacyMode: PrivacyMode = .revealed
    @State private var lockState: AppLockState = .unlocked

    public init() {}

    public var body: some View {
        Group {
            if lockState == .locked {
                ContentUnavailableView(
                    "TBB is locked",
                    systemImage: "lock.fill",
                    description: Text("Authenticate to view your financial information.")
                )
            } else {
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
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                privacyMode.toggle()
                            } label: {
                                Image(systemName: privacyMode == .revealed ? "eye" : "eye.slash")
                            }
                            .accessibilityLabel(privacyMode == .revealed ? "Hide monetary amounts" : "Show monetary amounts")
                            .accessibilityHint("Changes only this device's display.")
                        }
                    }
                }
            }
        }
    }
}
#endif
