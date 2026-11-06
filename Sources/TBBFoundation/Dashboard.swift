import Foundation

public enum DashboardPeriod: String, CaseIterable, Codable, Sendable {
    case week
    case month
    case quarter
    case year

    fileprivate var component: Calendar.Component {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .quarter: .quarter
        case .year: .year
        }
    }
}

public struct DashboardDateRange: Equatable, Sendable {
    public let start: Date
    public let endExclusive: Date

    public func contains(_ date: Date) -> Bool {
        date >= start && date < endExclusive
    }
}

public struct DashboardNavigator: Equatable, Sendable {
    public let period: DashboardPeriod
    public let anchor: Date
    public let timeZone: TimeZone

    public init(period: DashboardPeriod, anchor: Date = .now, timeZone: TimeZone = .current) {
        self.period = period
        self.anchor = anchor
        self.timeZone = timeZone
    }

    public var range: DashboardDateRange {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = timeZone
        let interval = calendar.dateInterval(of: period.component, for: anchor)!
        return DashboardDateRange(start: interval.start, endExclusive: interval.end)
    }

    public func moving(by offset: Int) -> DashboardNavigator {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = timeZone
        let nextAnchor = calendar.date(byAdding: period.component, value: offset, to: anchor)!
        return DashboardNavigator(period: period, anchor: nextAnchor, timeZone: timeZone)
    }

    public func changingPeriod(to newPeriod: DashboardPeriod) -> DashboardNavigator {
        DashboardNavigator(period: newPeriod, anchor: anchor, timeZone: timeZone)
    }
}

public struct DashboardSummary: Equatable, Sendable {
    public let incomeMinorUnits: Int64
    public let expenseMinorUnits: Int64
    public let netCashFlowMinorUnits: Int64
    public let spendingByCategory: [UUID: Int64]
}

public enum LedgerInsights {
    public static func summarize(state: LedgerState, range: DashboardDateRange) -> DashboardSummary {
        let selected = state.transactions.filter { range.contains($0.occurredAt) }
        let income = selected.filter { $0.kind == .income }.reduce(Int64(0)) { $0 + $1.amount.minorUnits }
        let expenseTransactions = selected.filter { $0.kind == .expense }
        let expense = expenseTransactions.reduce(Int64(0)) { $0 + $1.amount.minorUnits }
        let categories = expenseTransactions.reduce(into: [UUID: Int64]()) { totals, transaction in
            guard let categoryID = transaction.categoryID else { return }
            totals[categoryID, default: 0] += transaction.amount.minorUnits
        }
        return DashboardSummary(
            incomeMinorUnits: income,
            expenseMinorUnits: expense,
            netCashFlowMinorUnits: income - expense,
            spendingByCategory: categories
        )
    }
}
