#if canImport(SwiftUI) && canImport(CoreData)
import Combine
import Foundation
import TBBFoundation

@MainActor
final class LedgerViewModel: ObservableObject {
    @Published private(set) var state: LedgerState
    @Published private(set) var errorMessage: String? = nil

    private var store: CoreDataLedgerStore?

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
            try state.addAccount(.init(name: name, kind: kind, currencyCode: state.baseCurrencyCode, openingBalanceMinorUnits: openingBalanceMinorUnits))
            try persist()
        } catch {
            errorMessage = "TBB could not add that account. Account names must be unique."
        }
    }

    func record(kind: LedgerTransactionKind, minorUnits: Int64, accountID: UUID, categoryID: UUID?, destinationID: UUID?, note: String) {
        do {
            let amount = try Money(minorUnits: minorUnits, currencyCode: state.baseCurrencyCode)
            switch kind {
            case .expense:
                guard let categoryID else { return }
                try state.recordExpense(amount: amount, accountID: accountID, categoryID: categoryID, occurredAt: .now, note: note)
            case .income:
                guard let categoryID else { return }
                try state.recordIncome(amount: amount, accountID: accountID, categoryID: categoryID, occurredAt: .now, note: note)
            case .transfer:
                guard let destinationID else { return }
                try state.recordTransfer(amount: amount, fromAccountID: accountID, toAccountID: destinationID, occurredAt: .now, note: note)
            }
            try persist()
        } catch {
            errorMessage = "TBB could not record that transaction. Check the account, category, and amount."
        }
    }

    func balance(for account: LedgerAccount) -> Money {
        (try? state.balance(of: account.id)) ?? (try! Money(minorUnits: 0, currencyCode: account.currencyCode))
    }

    func categoryName(for id: UUID?) -> String {
        state.categories.first(where: { $0.id == id })?.name ?? "Transfer"
    }

    func dismissError() { errorMessage = nil }

    private func seedCategoriesIfNeeded() {
        guard state.categories.isEmpty else { return }
        do {
            try state.addCategory(.init(name: "General", kind: .expense))
            try state.addCategory(.init(name: "Income", kind: .income))
            try persist()
        } catch {
            errorMessage = "TBB could not prepare default categories."
        }
    }

    private func persist() throws { try store?.save(state) }
}
#endif
