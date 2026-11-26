import Foundation

public enum BudgetCadence: String, CaseIterable, Codable, Sendable {
    case week
    case month
    case quarter
    case year

    public var dashboardPeriod: DashboardPeriod {
        switch self {
        case .week: .week
        case .month: .month
        case .quarter: .quarter
        case .year: .year
        }
    }
}

public enum BudgetRolloverPolicy: String, Codable, Sendable {
    case carryFullBalance
}

public struct BudgetPlan: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let categoryID: UUID
    public let cadence: BudgetCadence
    public let plannedMinorUnits: Int64
    public let startsAt: Date
    public let rolloverPolicy: BudgetRolloverPolicy

    public init(
        id: UUID = UUID(),
        categoryID: UUID,
        cadence: BudgetCadence,
        plannedMinorUnits: Int64,
        startsAt: Date = .now,
        rolloverPolicy: BudgetRolloverPolicy = .carryFullBalance
    ) {
        self.id = id
        self.categoryID = categoryID
        self.cadence = cadence
        self.plannedMinorUnits = plannedMinorUnits
        self.startsAt = startsAt
        self.rolloverPolicy = rolloverPolicy
    }
}

public enum BudgetAlertState: String, Equatable, Sendable {
    case onTrack
    case warning
    case exceeded
}

public struct BudgetProgress: Equatable, Sendable {
    public let planID: UUID
    public let range: DashboardDateRange
    public let plannedMinorUnits: Int64
    public let carriedMinorUnits: Int64
    public let availableMinorUnits: Int64
    public let spentMinorUnits: Int64
    public let remainingMinorUnits: Int64
    public let consumedPermille: Int64
    public let alertState: BudgetAlertState
}

public enum BudgetInsights {
    public static func progress(
        plan: BudgetPlan,
        state: LedgerState,
        anchor: Date = .now,
        timeZone: TimeZone = .current
    ) -> BudgetProgress {
        let navigator = DashboardNavigator(period: plan.cadence.dashboardPeriod, anchor: anchor, timeZone: timeZone)
        let activeRange = navigator.range
        let firstRange = DashboardNavigator(period: plan.cadence.dashboardPeriod, anchor: plan.startsAt, timeZone: timeZone).range

        guard activeRange.endExclusive > firstRange.start else {
            return BudgetProgress(
                planID: plan.id,
                range: activeRange,
                plannedMinorUnits: 0,
                carriedMinorUnits: 0,
                availableMinorUnits: 0,
                spentMinorUnits: 0,
                remainingMinorUnits: 0,
                consumedPermille: 0,
                alertState: .onTrack
            )
        }

        // A restored plan may span decades. Compute elapsed periods once, and scan
        // historical expenses once regardless of how old the plan is.
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = timeZone
        let component: Calendar.Component
        switch plan.cadence {
        case .week: component = .weekOfYear
        case .month, .quarter: component = .month
        case .year: component = .year
        }
        let elapsed = calendar.dateComponents([component], from: firstRange.start, to: activeRange.start).value(for: component) ?? 0
        let periods = plan.cadence == .quarter ? elapsed / 3 : elapsed
        let history = DashboardDateRange(start: firstRange.start, endExclusive: activeRange.start)
        let historicalSpend = expenseMinorUnits(categoryID: plan.categoryID, state: state, range: history)
        let carriedMinorUnits = Int64(periods) * plan.plannedMinorUnits - historicalSpend

        let spentMinorUnits = expenseMinorUnits(categoryID: plan.categoryID, state: state, range: activeRange)
        let availableMinorUnits = carriedMinorUnits + plan.plannedMinorUnits
        let remainingMinorUnits = availableMinorUnits - spentMinorUnits
        let denominator = max(availableMinorUnits, 1)
        let consumedPermille = max(0, (spentMinorUnits * 1_000) / denominator)

        let alertState: BudgetAlertState
        if remainingMinorUnits <= 0 {
            alertState = .exceeded
        } else if consumedPermille >= 800 {
            alertState = .warning
        } else {
            alertState = .onTrack
        }

        return BudgetProgress(
            planID: plan.id,
            range: activeRange,
            plannedMinorUnits: plan.plannedMinorUnits,
            carriedMinorUnits: carriedMinorUnits,
            availableMinorUnits: availableMinorUnits,
            spentMinorUnits: spentMinorUnits,
            remainingMinorUnits: remainingMinorUnits,
            consumedPermille: consumedPermille,
            alertState: alertState
        )
    }

    private static func expenseMinorUnits(categoryID: UUID, state: LedgerState, range: DashboardDateRange) -> Int64 {
        state.transactions
            .filter { $0.kind == .expense && $0.categoryID == categoryID && range.contains($0.occurredAt) }
            .reduce(Int64(0)) { $0 + $1.amount.minorUnits }
    }
}
