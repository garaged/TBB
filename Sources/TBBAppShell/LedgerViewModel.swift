#if canImport(SwiftUI) && canImport(CoreData)
import Combine
import Foundation
#if canImport(CloudKit)
import CloudKit
#endif
import TBBFoundation

@MainActor
final class LedgerViewModel: ObservableObject {
    @Published private(set) var state: LedgerState
    @Published private(set) var errorMessage: String? = nil
    @Published private(set) var spaces: [StoredBudgetSpace] = []
    @Published private(set) var activeSpace: StoredBudgetSpace? = nil

    private var store: CoreDataLedgerStore?
    private let budgetNotifications = BudgetNotificationCoordinator()

    init() {
        do {
            let persistentStore = try CoreDataLedgerStore()
            store = persistentStore
            let active = try persistentStore.defaultBudgetSpace(baseCurrencyCode: "MXN")
            state = try persistentStore.load(spaceID: active.id)
            activeSpace = active
            spaces = try persistentStore.budgetSpaces(baseCurrencyCode: "MXN")
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

    func selectBudgetSpace(id: UUID) {
        do {
            guard let selected = spaces.first(where: { $0.id == id }) else { return }
            state = try store?.load(spaceID: id) ?? state
            activeSpace = selected
            budgetNotifications.refresh(state: state)
        } catch {
            errorMessage = "TBB could not open that household budget."
        }
    }

    func renameActiveBudgetSpace(to name: String) -> Bool {
        guard let store, let activeSpace else { return false }
        do {
            try store.renameBudgetSpace(id: activeSpace.id, to: name)
            try refreshSpaces()
            return true
        } catch LedgerPersistenceError.invalidBudgetSpaceName {
            errorMessage = "Enter a budget name between 1 and 80 characters."
        } catch {
            errorMessage = "TBB could not rename this budget."
        }
        return false
    }

    #if canImport(CloudKit)
    func createOrFetchShareForActiveSpace() async -> CloudKitShareSession? {
        guard let store, let activeSpace else {
            errorMessage = "TBB could not prepare household sharing."
            return nil
        }
        do {
            let session = try await store.createOrFetchShare(for: activeSpace.id)
            try refreshSpaces()
            return session
        } catch {
            #if DEBUG
            print("TBB CloudKit sharing failed: \(error)")
            #endif
            errorMessage = householdSharingMessage(for: error)
            return nil
        }
    }

    func acceptShareInvitation(_ metadata: CKShare.Metadata) {
        store?.accept(metadata)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try self.refreshSpaces()
            } catch {
                self.errorMessage = "TBB received the household invite but could not refresh shared budgets yet."
            }
        }
    }

    func refreshHouseholdData() {
        do {
            try refreshSpaces()
            if let activeSpace {
                state = try store?.load(spaceID: activeSpace.id) ?? state
            }
            budgetNotifications.refresh(state: state)
        } catch {
            errorMessage = "TBB could not refresh household data."
        }
    }
    #endif

    #if canImport(CloudKit)
    private func householdSharingMessage(for error: Error) -> String {
        if let cloudError = error as? CKError {
            switch cloudError.code {
            case .notAuthenticated:
                return "Sign in to iCloud in Settings, enable iCloud Drive, then close and reopen TBB before sharing."
            case .accountTemporarilyUnavailable:
                return "Your iCloud account is not ready for sharing yet. Wait a moment, then try again."
            case .networkUnavailable, .networkFailure:
                return "TBB needs an internet connection to start household sharing. Check the connection and try again."
            default:
                break
            }
        }

        if let persistenceError = error as? LedgerPersistenceError {
            switch persistenceError {
            case .cloudContainerUnavailable:
                return "TBB started in local-only mode because CloudKit could not load. Reinstall the current build, then check the Xcode console."
            case .privateCloudStoreUnavailable:
                return "TBB could not configure its private CloudKit store. Reinstall the current build, then check the Xcode console."
            case .sharingUnavailable:
                return "iCloud sharing is unavailable in this build. Confirm the CloudKit container is enabled for TBB, then reinstall and try again."
            default:
                break
            }
        }

        return "TBB could not start iCloud sharing. Confirm this device is signed in to iCloud, then try again."
    }
    #endif

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

    private func persist() throws {
        if let activeSpace {
            try store?.save(state, in: activeSpace.id)
        } else {
            try store?.save(state)
        }
        try refreshSpaces()
    }

    private func refreshSpaces() throws {
        guard let store else { return }
        spaces = try store.budgetSpaces(baseCurrencyCode: state.baseCurrencyCode)
        if let activeSpace {
            self.activeSpace = spaces.first(where: { $0.id == activeSpace.id }) ?? activeSpace
        } else {
            self.activeSpace = try store.defaultBudgetSpace(baseCurrencyCode: state.baseCurrencyCode)
        }
    }
}
#endif
