#if canImport(SwiftUI) && canImport(CoreData)
import Combine
import Foundation
import TBBFoundation

@MainActor
final class LedgerViewModel: ObservableObject {
    @Published private(set) var state: LedgerState
    @Published private(set) var errorMessage: String?

    private let store: CoreDataLedgerStore?

    init() {
        do {
            let persistentStore = try CoreDataLedgerStore()
            store = persistentStore
            state = try persistentStore.load(baseCurrencyCode: "MXN")
            seedCategoriesIfNeeded()
        } catch {
            store = nil
            state = try! LedgerState(baseCurrencyCode: "MXN")
            errorMessage = "TBB could not open local budget storage."
        }
    }

    func addAccount(name: String, kind: AccountKind, openingBalanceMinorUnits: Int64 = 0) {
        do {
            let account = try LedgerAccount(
                name: name,
                kind: kind,
                currencyCode: state.baseCurrencyCode,
                openingBalanceMinorUnits: openingBalanceMinorUnits
            )
            try state.addAccount(account)
            try persist()
        } catch {
            errorMessage = "TBB could not add that account. Account names must be unique."
        }
    }

    func balance(for account: LedgerAccount) -> Money {
        (try? state.balance(of: account.id)) ?? (try! Money(minorUnits: 0, currencyCode: account.currencyCode))
    }

    func dismissError() {
        errorMessage = nil
    }

    private func seedCategoriesIfNeeded() {
        guard state.categories.isEmpty else { return }
        do {
            try state.addCategory(LedgerCategory(name: "General", kind: .expense))
            try state.addCategory(LedgerCategory(name: "Income", kind: .income))
            try persist()
        } catch {
            errorMessage = "TBB could not prepare default categories."
        }
    }

    private func persist() throws {
        try store?.save(state)
    }
}
#endif
