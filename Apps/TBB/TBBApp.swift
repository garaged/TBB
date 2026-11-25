import SwiftUI

#if canImport(UIKit) && canImport(CloudKit)
import CloudKit
import UIKit

final class TBBAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = TBBSceneDelegate.self
        return configuration
    }
}

final class TBBSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            HouseholdInvitationRouter.route(cloudKitShareMetadata)
        }
    }
}
#endif

@main
struct TBBApp: App {
    #if canImport(UIKit) && canImport(CloudKit)
    @UIApplicationDelegateAdaptor(TBBAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            TBBRootView()
        }
    }
}
