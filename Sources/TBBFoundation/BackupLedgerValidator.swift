import Foundation

/// Validation used before any restored ledger is persisted (TBB-BKP-001).
public enum BackupValidationError: Error, Equatable, Sendable {
    case invalidLedger
}

public enum BackupLedgerValidator {
    /// Returns the original ledger only after checking references, uniqueness and arithmetic.
    public static func validate(_ ledger: LedgerState) throws -> LedgerState {
        func validCurrency(_ code: String) -> Bool {
            code.utf8.count == 3 && code.utf8.allSatisfy { $0 >= 65 && $0 <= 90 }
        }
        // Bound work before constructing sets or performing reference validation.
        guard ledger.accounts.count <= 1_000, ledger.categories.count <= 1_000,
              ledger.budgets.count <= 1_000, ledger.transactions.count <= 10_000,
              ledger.transactions.allSatisfy({ $0.note.utf8.count <= 4_096 }) else {
            throw BackupValidationError.invalidLedger
        }
        guard validCurrency(ledger.baseCurrencyCode),
              Set(ledger.accounts.map(\.id)).count == ledger.accounts.count,
              Set(ledger.categories.map(\.id)).count == ledger.categories.count,
              Set(ledger.transactions.map(\.id)).count == ledger.transactions.count,
              Set(ledger.budgets.map(\.id)).count == ledger.budgets.count else {
            throw BackupValidationError.invalidLedger
        }

        let dateRange = Date.distantPast...Date.distantFuture
        var checked = try LedgerState(baseCurrencyCode: ledger.baseCurrencyCode)
        do {
            for account in ledger.accounts {
                guard validCurrency(account.currencyCode) else { throw BackupValidationError.invalidLedger }
                try checked.addAccount(account)
            }
            for category in ledger.categories { try checked.addCategory(category) }
            for budget in ledger.budgets {
                // Reserve headroom for rollover across the supported calendar range.
                guard dateRange.contains(budget.startsAt),
                      budget.plannedMinorUnits <= Int64.max / 1_000_000 else { throw BackupValidationError.invalidLedger }
                try checked.addBudget(budget)
            }
        } catch { throw BackupValidationError.invalidLedger }

        func add(_ a: Int64, _ b: Int64) throws -> Int64 {
            let sum = a.addingReportingOverflow(b)
            guard !sum.overflow else { throw BackupValidationError.invalidLedger }
            return sum.partialValue
        }

        let accounts = Dictionary(uniqueKeysWithValues: ledger.accounts.map { ($0.id, $0.currencyCode) })
        let categories = Dictionary(uniqueKeysWithValues: ledger.categories.map { ($0.id, $0.kind) })
        var movements: [UUID: Int64] = [:]
        var income: Int64 = 0
        var expenses: Int64 = 0
        for entry in ledger.transactions {
            let amount = entry.amount.minorUnits
            guard amount > 0, accounts[entry.accountID] == entry.amount.currencyCode,
                  dateRange.contains(entry.occurredAt) else { throw BackupValidationError.invalidLedger }
            switch entry.kind {
            case .income, .expense:
                let kind: CategoryKind = entry.kind == .income ? .income : .expense
                guard let id = entry.categoryID, categories[id] == kind,
                      entry.counterpartyAccountID == nil else { throw BackupValidationError.invalidLedger }
                if entry.kind == .income {
                    income = try add(income, amount)
                } else {
                    expenses = try add(expenses, amount)
                }
            case .transfer:
                guard entry.categoryID == nil, let destination = entry.counterpartyAccountID,
                      destination != entry.accountID, accounts[destination] == entry.amount.currencyCode else {
                    throw BackupValidationError.invalidLedger
                }
                movements[destination] = try add(movements[destination, default: 0], amount)
            }
            movements[entry.accountID] = try add(movements[entry.accountID, default: 0], entry.kind == .income ? amount : -amount)
        }
        // Budget progress scales spending by 1,000. Overview sums balances in account order.
        guard ledger.budgets.isEmpty || expenses <= Int64.max / 1_000 else { throw BackupValidationError.invalidLedger }
        var totalBalance: Int64 = 0
        for account in ledger.accounts {
            let balance = try add(account.openingBalanceMinorUnits, movements[account.id, default: 0])
            totalBalance = try add(totalBalance, balance)
        }
        return ledger
    }
}
