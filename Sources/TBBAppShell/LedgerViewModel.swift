#if canImport(SwiftUI) && canImport(CoreData)
import Combine
import Foundation
import TBBFoundation

@MainActor
final class LedgerViewModel: ObservableObject {
    @Published private(set) var state: LedgerState
    @Published private(set) var errorMessage: String? = nil

    private var store: CoreDataLedgerStore?
    private let budgetNotifications = BudgetNotificationCoordinator()

    init() {
        do {
            let persistentStore = try CoreDataLedgerStore()
            store = persistentStore
            state = try persistentStore.load(baseCurrencyCode: "MXN")
            seedCategoriesIfNeeded()
            budgetNotifications.refresh(state: state)
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

    func addBudget(categoryID: UUID, cadence: BudgetCadence, minorUnits: Int64, startsAt: Date) {
        do {
            try state.addBudget(.init(categoryID: categoryID, cadence: cadence, plannedMinorUnits: minorUnits, startsAt: startsAt))
            try persist()
            budgetNotifications.requestAuthorizationAndRefresh(state: state)
        } catch {
            errorMessage = "TBB could not add that budget. Choose an expense category with no existing budget for this cadence."
        }
    }

    func updateBudget(id: UUID, categoryID: UUID, cadence: BudgetCadence, minorUnits: Int64, startsAt: Date) {
        do {
            try state.updateBudget(.init(id: id, categoryID: categoryID, cadence: cadence, plannedMinorUnits: minorUnits, startsAt: startsAt))
            try persist()
            budgetNotifications.refresh(state: state)
        } catch {
            errorMessage = "TBB could not update that budget. Choose an expense category with no existing budget for this cadence."
        }
    }

    func deleteBudget(id: UUID) {
        do {
            try state.deleteBudget(id: id)
            try persist()
        } catch {
            errorMessage = "TBB could not delete that budget."
        }
    }

    func record(kind: LedgerTransactionKind, minorUnits: Int64, accountID: UUID, categoryID: UUID?, destinationID: UUID?, occurredAt: Date, note: String) {
        do {
            let amount = try Money(minorUnits: minorUnits, currencyCode: state.baseCurrencyCode)
            switch kind {
            case .expense:
                guard let categoryID else { return }
                try state.recordExpense(amount: amount, accountID: accountID, categoryID: categoryID, occurredAt: occurredAt, note: note)
            case .income:
                guard let categoryID else { return }
                try state.recordIncome(amount: amount, accountID: accountID, categoryID: categoryID, occurredAt: occurredAt, note: note)
            case .transfer:
                guard let destinationID else { return }
                try state.recordTransfer(amount: amount, fromAccountID: accountID, toAccountID: destinationID, occurredAt: occurredAt, note: note)
            }
            try persist()
            budgetNotifications.refresh(state: state)
        } catch {
            errorMessage = "TBB could not record that transaction. Check the account, category, and amount."
        }
    }

    func update(transactionID: UUID, kind: LedgerTransactionKind, minorUnits: Int64, accountID: UUID, categoryID: UUID?, destinationID: UUID?, occurredAt: Date, note: String) {
        do {
            try state.updateTransaction(
                id: transactionID,
                kind: kind,
                amount: Money(minorUnits: minorUnits, currencyCode: state.baseCurrencyCode),
                accountID: accountID,
                categoryID: categoryID,
                counterpartyAccountID: destinationID,
                occurredAt: occurredAt,
                note: note
            )
            try persist()
            budgetNotifications.refresh(state: state)
        } catch {
            errorMessage = "TBB could not update that transaction. Check the account, category, and amount."
        }
    }

    func delete(transactionID: UUID) {
        do {
            try state.deleteTransaction(id: transactionID)
            try persist()
            budgetNotifications.refresh(state: state)
        } catch {
            errorMessage = "TBB could not delete that transaction."
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
