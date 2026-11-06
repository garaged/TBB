import Foundation
import TBBFoundation
#if canImport(UserNotifications)
import UserNotifications
#endif

@MainActor
final class BudgetNotificationCoordinator {
    private let deliveredAlertKeysKey = "tbb.delivered-budget-alert-keys"

    func requestAuthorizationAndRefresh(state: LedgerState) {
        Task {
            #if canImport(UserNotifications)
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return }
            await scheduleAlerts(state: state, center: center)
            #endif
        }
    }

    func refresh(state: LedgerState) {
        Task {
            #if canImport(UserNotifications)
            await scheduleAlerts(state: state, center: UNUserNotificationCenter.current())
            #endif
        }
    }

    #if canImport(UserNotifications)
    private func scheduleAlerts(state: LedgerState, center: UNUserNotificationCenter) async {
        var delivered = Set(UserDefaults.standard.stringArray(forKey: deliveredAlertKeysKey) ?? [])

        for plan in state.budgets {
            let progress = BudgetInsights.progress(plan: plan, state: state)
            guard progress.alertState != .onTrack else { continue }

            let rangeKey = Int64(progress.range.start.timeIntervalSince1970)
            let alertKey = "\(plan.id.uuidString):\(rangeKey):\(progress.alertState.rawValue)"
            guard !delivered.contains(alertKey) else { continue }

            let categoryName = state.categories.first(where: { $0.id == plan.categoryID })?.name ?? "Category"
            let content = UNMutableNotificationContent()
            content.title = "\(categoryName) budget alert"
            content.body = progress.alertState == .exceeded ? "This category budget has been exceeded." : "This category budget is nearly spent."
            content.sound = .default

            let request = UNNotificationRequest(identifier: "tbb-budget-\(alertKey)", content: content, trigger: nil)
            guard (try? await center.add(request)) != nil else { continue }
            delivered.insert(alertKey)
        }

        UserDefaults.standard.set(Array(delivered.suffix(500)), forKey: deliveredAlertKeysKey)
    }
    #endif
}
