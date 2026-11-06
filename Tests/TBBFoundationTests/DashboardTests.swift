import Foundation
import Testing
@testable import TBBFoundation

@Test func dashboardNavigatorMovesByTheSelectedCalendarPeriod() {
    let zone = TimeZone(secondsFromGMT: 0)!
    let anchor = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01T00:00:00Z
    let navigator = DashboardNavigator(period: .month, anchor: anchor, timeZone: zone)
    let next = navigator.moving(by: 1)

    #expect(navigator.range.contains(anchor))
    #expect(next.range.contains(Date(timeIntervalSince1970: 1_706_745_600))) // 2024-02-01T00:00:00Z
    #expect(!navigator.range.contains(Date(timeIntervalSince1970: 1_706_745_600)))
}

@Test func dashboardNavigatorUsesTheSameAnchorWhenChangingGranularity() {
    let zone = TimeZone(secondsFromGMT: 0)!
    let anchor = Date(timeIntervalSince1970: 1_718_409_600) // 2024-06-15T00:00:00Z
    let navigator = DashboardNavigator(period: .month, anchor: anchor, timeZone: zone)

    let week = navigator.changingPeriod(to: .week)
    let quarter = navigator.changingPeriod(to: .quarter)

    #expect(week.range.contains(anchor))
    #expect(quarter.range.contains(anchor))
    #expect(week.range != navigator.range)
    #expect(quarter.range != navigator.range)
}

@Test func dashboardSummaryExcludesTransfersAndOtherPeriods() throws {
    var state = try LedgerState(baseCurrencyCode: "MXN")
    let account = try LedgerAccount(name: "Wallet", kind: .cash, currencyCode: "MXN")
    let food = LedgerCategory(name: "Food", kind: .expense)
    let income = LedgerCategory(name: "Pay", kind: .income)
    try state.addAccount(account)
    try state.addCategory(food)
    try state.addCategory(income)

    let january = Date(timeIntervalSince1970: 1_704_067_200)
    let february = Date(timeIntervalSince1970: 1_706_745_600)
    try state.recordExpense(amount: Money(minorUnits: 1_500, currencyCode: "MXN"), accountID: account.id, categoryID: food.id, occurredAt: january)
    try state.recordIncome(amount: Money(minorUnits: 5_000, currencyCode: "MXN"), accountID: account.id, categoryID: income.id, occurredAt: january)
    try state.recordExpense(amount: Money(minorUnits: 2_000, currencyCode: "MXN"), accountID: account.id, categoryID: food.id, occurredAt: february)

    let range = DashboardNavigator(period: .month, anchor: january, timeZone: TimeZone(secondsFromGMT: 0)!).range
    let summary = LedgerInsights.summarize(state: state, range: range)

    #expect(summary.incomeMinorUnits == 5_000)
    #expect(summary.expenseMinorUnits == 1_500)
    #expect(summary.netCashFlowMinorUnits == 3_500)
    #expect(summary.spendingByCategory[food.id] == 1_500)
}
