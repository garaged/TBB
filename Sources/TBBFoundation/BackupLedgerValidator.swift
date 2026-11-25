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
        guard validCurrency(ledger.baseCurrencyCode),
              Set(ledger.accounts.map(\.id)).count == ledger.accounts.count,
              Set(ledger.categories.map(\.id)).count == ledger.categories.count,
              Set(ledger.transactions.map(\.id)).count == ledger.transactions.count,
              Set(ledger.budgets.map(\.id)).count == ledger.budgets.count else {
            throw BackupValidationError.invalidLedger
        }

        var checked = try LedgerState(baseCurrencyCode: ledger.baseCurrencyCode)
        do {
            for account in ledger.accounts {
                guard validCurrency(account.currencyCode) else { throw BackupValidationError.invalidLedger }
                try checked.addAccount(account)
            }
            for category in ledger.categories {
                try checked.addCategory(category)
            }
            for budget in ledger.budgets {
                guard budget.startsAt.timeIntervalSinceReferenceDate.isFinite else { throw BackupValidationError.invalidLedger }
                try checked.addBudget(budget)
            }
            for transaction in ledger.transactions {
                guard validCurrency(transaction.amount.currencyCode),
                      transaction.occurredAt.timeIntervalSinceReferenceDate.isFinite else {
                    throw BackupValidationError.invalidLedger
                }
                switch transaction.kind {
                case .expense:
                    guard let category = transaction.categoryID, transaction.counterpartyAccountID == nil else {
                        throw BackupValidationError.invalidLedger
                    }
                    try checked.recordExpense(amount: transaction.amount, accountID: transaction.accountID, categoryID: category, occurredAt: transaction.occurredAt, note: transaction.note)
                case .income:
                    guard let category = transaction.categoryID, transaction.counterpartyAccountID == nil else {
                        throw BackupValidationError.invalidLedger
                    }
                    try checked.recordIncome(amount: transaction.amount, accountID: transaction.accountID, categoryID: category, occurredAt: transaction.occurredAt, note: transaction.note)
                case .transfer:
                    guard let destination = transaction.counterpartyAccountID, transaction.categoryID == nil else {
                        throw BackupValidationError.invalidLedger
                    }
                    try checked.recordTransfer(amount: transaction.amount, fromAccountID: transaction.accountID, toAccountID: destination, occurredAt: transaction.occurredAt, note: transaction.note)
                }
            }
        } catch {
            throw BackupValidationError.invalidLedger
        }

        // Check the exact accumulation order used by LedgerState.balance before restore.
        for account in ledger.accounts {
            var movements: Int64 = 0
            for transaction in ledger.transactions {
                var result: (partialValue: Int64, overflow: Bool)?
                switch transaction.kind {
                case .expense where transaction.accountID == account.id:
                    result = movements.subtractingReportingOverflow(transaction.amount.minorUnits)
                case .income where transaction.accountID == account.id:
                    result = movements.addingReportingOverflow(transaction.amount.minorUnits)
                case .transfer where transaction.accountID == account.id:
                    result = movements.subtractingReportingOverflow(transaction.amount.minorUnits)
                case .transfer where transaction.counterpartyAccountID == account.id:
                    result = movements.addingReportingOverflow(transaction.amount.minorUnits)
                default:
                    break
                }
                if let result {
                    guard !result.overflow else { throw BackupValidationError.invalidLedger }
                    movements = result.partialValue
                }
            }
            guard !account.openingBalanceMinorUnits.addingReportingOverflow(movements).overflow else {
                throw BackupValidationError.invalidLedger
            }
        }
        return ledger
    }
}
