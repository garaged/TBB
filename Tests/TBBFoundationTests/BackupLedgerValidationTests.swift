import Foundation
import Testing
@testable import TBBFoundation

@Test func backupLedgerValidationAcceptsValidLedger() throws {
    var ledger = try LedgerState(baseCurrencyCode: "MXN")
    let cash = try LedgerAccount(name: "Cash", kind: .cash, currencyCode: "MXN")
    let food = LedgerCategory(name: "Food", kind: .expense)
    try ledger.addAccount(cash)
    try ledger.addCategory(food)
    try ledger.recordExpense(amount: Money(minorUnits: 125, currencyCode: "MXN"), accountID: cash.id, categoryID: food.id, occurredAt: Date(timeIntervalSince1970: 1_700_000_000))
    try ledger.addBudget(BudgetPlan(categoryID: food.id, cadence: .month, plannedMinorUnits: 10_000))
    #expect(try BackupLedgerValidator.validate(ledger) == ledger)
}

@Test func backupLedgerValidationRejectsOrphanedTransaction() throws {
    let transaction = LedgerTransaction(kind: .expense, amount: try Money(minorUnits: 1, currencyCode: "MXN"), accountID: UUID(), categoryID: UUID(), occurredAt: .now)
    let ledger = try LedgerState(baseCurrencyCode: "MXN", transactions: [transaction])
    #expect(throws: BackupValidationError.invalidLedger) {
        try BackupLedgerValidator.validate(ledger)
    }
}

@Test func backupLedgerValidationRejectsDuplicateIDsAndInvalidBudgets() throws {
    let cash = try LedgerAccount(name: "Cash", kind: .cash, currencyCode: "MXN")
    let duplicate = try LedgerState(baseCurrencyCode: "MXN", accounts: [cash, cash])
    #expect(throws: BackupValidationError.invalidLedger) {
        try BackupLedgerValidator.validate(duplicate)
    }

    let badBudget = BudgetPlan(categoryID: UUID(), cadence: .month, plannedMinorUnits: -1)
    let invalid = try LedgerState(baseCurrencyCode: "MXN", budgets: [badBudget])
    #expect(throws: BackupValidationError.invalidLedger) {
        try BackupLedgerValidator.validate(invalid)
    }
}

@Test func backupLedgerValidationRejectsBalanceOverflow() throws {
    let cash = try LedgerAccount(name: "Cash", kind: .cash, currencyCode: "MXN", openingBalanceMinorUnits: Int64.max)
    let salary = LedgerCategory(name: "Salary", kind: .income)
    let transaction = LedgerTransaction(kind: .income, amount: try Money(minorUnits: 1, currencyCode: "MXN"), accountID: cash.id, categoryID: salary.id, occurredAt: .now)
    let ledger = try LedgerState(baseCurrencyCode: "MXN", accounts: [cash], categories: [salary], transactions: [transaction])
    #expect(throws: BackupValidationError.invalidLedger) {
        try BackupLedgerValidator.validate(ledger)
    }
}

@Test func backupLedgerValidationRejectsOversizedCollectionsAndNotes() throws {
    let account = try LedgerAccount(name: "Cash", kind: .cash, currencyCode: "MXN")
    let oversized = try LedgerState(baseCurrencyCode: "MXN", accounts: Array(repeating: account, count: 1_001))
    #expect(throws: BackupValidationError.invalidLedger) {
        try BackupLedgerValidator.validate(oversized)
    }

    let category = LedgerCategory(name: "Food", kind: .expense)
    let transaction = LedgerTransaction(kind: .expense, amount: try Money(minorUnits: 1, currencyCode: "MXN"), accountID: account.id, categoryID: category.id, occurredAt: .now, note: String(repeating: "x", count: 4_097))
    let ledger = try LedgerState(baseCurrencyCode: "MXN", accounts: [account], categories: [category], transactions: [transaction])
    #expect(throws: BackupValidationError.invalidLedger) {
        try BackupLedgerValidator.validate(ledger)
    }
}
