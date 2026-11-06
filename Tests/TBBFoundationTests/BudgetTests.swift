import Foundation
import Testing
@testable import TBBFoundation

@Test func monthlyBudgetCarriesBothUnusedAndOverspentBalanceForward() throws {
    let zone = TimeZone(secondsFromGMT: 0)!
    var state = try LedgerState(baseCurrencyCode: "MXN")
    let cash = try LedgerAccount(name: "Cash", kind: .cash, currencyCode: "MXN")
    let food = LedgerCategory(name: "Food", kind: .expense)
    try state.addAccount(cash)
    try state.addCategory(food)

    let january = Date(timeIntervalSince1970: 1_704_067_200)
    let february = Date(timeIntervalSince1970: 1_706_745_600)
    let plan = BudgetPlan(categoryID: food.id, cadence: .month, plannedMinorUnits: 10_000, startsAt: january)
    try state.addBudget(plan)
    try state.recordExpense(amount: Money(minorUnits: 2_500, currencyCode: "MXN"), accountID: cash.id, categoryID: food.id, occurredAt: january)
    try state.recordExpense(amount: Money(minorUnits: 2_000, currencyCode: "MXN"), accountID: cash.id, categoryID: food.id, occurredAt: february)

    let februaryProgress = BudgetInsights.progress(plan: plan, state: state, anchor: february, timeZone: zone)

    #expect(februaryProgress.carriedMinorUnits == 7_500)
    #expect(februaryProgress.availableMinorUnits == 17_500)
    #expect(februaryProgress.spentMinorUnits == 2_000)
    #expect(februaryProgress.remainingMinorUnits == 15_500)
    #expect(februaryProgress.alertState == .onTrack)
}

@Test func budgetProgressExposesWarningAndExceededThresholds() throws {
    let zone = TimeZone(secondsFromGMT: 0)!
    var state = try LedgerState(baseCurrencyCode: "MXN")
    let cash = try LedgerAccount(name: "Cash", kind: .cash, currencyCode: "MXN")
    let food = LedgerCategory(name: "Food", kind: .expense)
    let anchor = Date(timeIntervalSince1970: 1_704_067_200)
    try state.addAccount(cash)
    try state.addCategory(food)
    let plan = BudgetPlan(categoryID: food.id, cadence: .month, plannedMinorUnits: 10_000, startsAt: anchor)
    try state.addBudget(plan)

    try state.recordExpense(amount: Money(minorUnits: 8_000, currencyCode: "MXN"), accountID: cash.id, categoryID: food.id, occurredAt: anchor)
    #expect(BudgetInsights.progress(plan: plan, state: state, anchor: anchor, timeZone: zone).alertState == .warning)

    try state.recordExpense(amount: Money(minorUnits: 2_001, currencyCode: "MXN"), accountID: cash.id, categoryID: food.id, occurredAt: anchor)
    #expect(BudgetInsights.progress(plan: plan, state: state, anchor: anchor, timeZone: zone).alertState == .exceeded)
}

@Test func budgetsRejectDuplicatesAndInvalidCategories() throws {
    var state = try LedgerState(baseCurrencyCode: "MXN")
    let food = LedgerCategory(name: "Food", kind: .expense)
    let salary = LedgerCategory(name: "Salary", kind: .income)
    try state.addCategory(food)
    try state.addCategory(salary)

    try state.addBudget(BudgetPlan(categoryID: food.id, cadence: .month, plannedMinorUnits: 1_000))
    #expect(throws: LedgerError.duplicateBudget) {
        try state.addBudget(BudgetPlan(categoryID: food.id, cadence: .month, plannedMinorUnits: 2_000))
    }
    #expect(throws: LedgerError.wrongCategoryKind) {
        try state.addBudget(BudgetPlan(categoryID: salary.id, cadence: .month, plannedMinorUnits: 1_000))
    }
}

@Test func decodingM2LedgerSnapshotDefaultsBudgetsToEmpty() throws {
    struct M2Snapshot: Codable {
        let baseCurrencyCode: String
        let accounts: [LedgerAccount]
        let categories: [LedgerCategory]
        let transactions: [LedgerTransaction]
    }

    let old = M2Snapshot(baseCurrencyCode: "MXN", accounts: [], categories: [], transactions: [])
    let migrated = try JSONDecoder().decode(LedgerState.self, from: JSONEncoder().encode(old))

    #expect(migrated.budgets.isEmpty)
}
