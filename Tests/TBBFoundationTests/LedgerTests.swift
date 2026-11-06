import Foundation
import Testing
@testable import TBBFoundation

@Test func ledgerUsesExactMinorUnitsAndCalculatesBalances() throws {
    var ledger = try LedgerState(baseCurrencyCode: "MXN")
    let checking = try LedgerAccount(name: "Checking", kind: .checking, currencyCode: "MXN", openingBalanceMinorUnits: 10_000)
    let groceries = LedgerCategory(name: "Groceries", kind: .expense)
    let salary = LedgerCategory(name: "Salary", kind: .income)
    try ledger.addAccount(checking)
    try ledger.addCategory(groceries)
    try ledger.addCategory(salary)

    try ledger.recordExpense(amount: Money(minorUnits: 1_250, currencyCode: "MXN"), accountID: checking.id, categoryID: groceries.id, occurredAt: .now)
    try ledger.recordIncome(amount: Money(minorUnits: 2_500, currencyCode: "MXN"), accountID: checking.id, categoryID: salary.id, occurredAt: .now)

    #expect(try ledger.balance(of: checking.id) == Money(minorUnits: 11_250, currencyCode: "MXN"))
}

@Test func ledgerPreservesUserSelectedOccurrenceDateAndTime() throws {
    var ledger = try LedgerState(baseCurrencyCode: "MXN")
    let cash = try LedgerAccount(name: "Cash", kind: .cash, currencyCode: "MXN")
    let food = LedgerCategory(name: "Food", kind: .expense)
    let occurredAt = Date(timeIntervalSince1970: 1_704_112_496) // 2024-01-01T12:34:56Z
    try ledger.addAccount(cash)
    try ledger.addCategory(food)

    try ledger.recordExpense(amount: Money(minorUnits: 1_500, currencyCode: "MXN"), accountID: cash.id, categoryID: food.id, occurredAt: occurredAt)

    #expect(ledger.transactions.first?.occurredAt == occurredAt)
    let january = DashboardNavigator(period: .month, anchor: occurredAt, timeZone: TimeZone(secondsFromGMT: 0)!).range
    #expect(LedgerInsights.summarize(state: ledger, range: january).expenseMinorUnits == 1_500)
}

@Test func transfersPreserveTotalAcrossAccounts() throws {
    var ledger = try LedgerState(baseCurrencyCode: "USD")
    let cash = try LedgerAccount(name: "Cash", kind: .cash, currencyCode: "USD", openingBalanceMinorUnits: 10_000)
    let savings = try LedgerAccount(name: "Savings", kind: .savings, currencyCode: "USD")
    try ledger.addAccount(cash)
    try ledger.addAccount(savings)

    try ledger.recordTransfer(amount: Money(minorUnits: 3_000, currencyCode: "USD"), fromAccountID: cash.id, toAccountID: savings.id, occurredAt: .now)

    #expect(try ledger.balance(of: cash.id).minorUnits == 7_000)
    #expect(try ledger.balance(of: savings.id).minorUnits == 3_000)
}

@Test func ledgerRejectsInvalidFinancialMutations() throws {
    var ledger = try LedgerState(baseCurrencyCode: "MXN")
    let cash = try LedgerAccount(name: "Cash", kind: .cash, currencyCode: "MXN")
    let transport = LedgerCategory(name: "Transport", kind: .expense)
    try ledger.addAccount(cash)
    try ledger.addCategory(transport)

    #expect(throws: LedgerError.nonPositiveAmount) {
        try ledger.recordExpense(amount: Money(minorUnits: 0, currencyCode: "MXN"), accountID: cash.id, categoryID: transport.id, occurredAt: .now)
    }
    #expect(throws: LedgerError.sameTransferAccount) {
        try ledger.recordTransfer(amount: Money(minorUnits: 100, currencyCode: "MXN"), fromAccountID: cash.id, toAccountID: cash.id, occurredAt: .now)
    }
}
