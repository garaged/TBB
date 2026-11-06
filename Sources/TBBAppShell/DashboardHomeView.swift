#if canImport(SwiftUI) && canImport(CoreData)
import SwiftUI
import TBBFoundation

struct DashboardHomeView: View {
    let privacyMode: PrivacyMode
    @ObservedObject var model: LedgerViewModel
    @State private var navigator = DashboardNavigator(period: .month)

    private var summary: DashboardSummary {
        LedgerInsights.summarize(state: model.state, range: navigator.range)
    }

    var body: some View {
        List {
            Section {
                Picker("Period", selection: Binding(
                    get: { navigator.period },
                    set: { navigator = navigator.changingPeriod(to: $0) }
                )) {
                    ForEach(DashboardPeriod.allCases, id: \.self) {
                        Text($0.rawValue.capitalized).tag($0)
                    }
                }
                .pickerStyle(.segmented)

                Text(rangeTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Selected period")
                    .accessibilityValue(rangeTitle)

                HStack {
                    Button {
                        navigator = navigator.moving(by: -1)
                    } label: {
                        Label("Previous", systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Previous \(navigator.period.rawValue)")

                    Spacer(minLength: 16)

                    Button {
                        navigator = navigator.moving(by: 1)
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Next \(navigator.period.rawValue)")
                }
            }

            Section("Cash flow") {
                dashboardRow("Income", value: summary.incomeMinorUnits)
                dashboardRow("Spending", value: -summary.expenseMinorUnits)
                dashboardRow("Net cash flow", value: summary.netCashFlowMinorUnits, emphasized: true)
            }

            Section("Spending by category") {
                if summary.spendingByCategory.isEmpty {
                    Text("No expenses in this period.").foregroundStyle(.secondary)
                } else {
                    ForEach(summary.spendingByCategory.keys.sorted { $0.uuidString < $1.uuidString }, id: \.self) { id in
                        HStack {
                            Text(model.state.categories.first(where: { $0.id == id })?.name ?? "Uncategorized")
                            Spacer()
                            Text(display(summary.spendingByCategory[id] ?? 0)).monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("Dashboard")
    }

    private var rangeTitle: String {
        let calendar = calendarForNavigator
        let range = navigator.range

        switch navigator.period {
        case .week:
            let inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: range.endExclusive) ?? range.endExclusive
            let start = formattedDay(range.start)
            let end = formattedDay(inclusiveEnd)
            return "Week of \(start) – \(end)"
        case .month:
            let formatter = DateFormatter()
            formatter.locale = .current
            formatter.timeZone = navigator.timeZone
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: range.start)
        case .quarter:
            let components = calendar.dateComponents([.quarter, .year], from: range.start)
            return "Q\(components.quarter ?? 1) \(components.year ?? 0)"
        case .year:
            let formatter = DateFormatter()
            formatter.locale = .current
            formatter.timeZone = navigator.timeZone
            formatter.dateFormat = "yyyy"
            return formatter.string(from: range.start)
        }
    }

    private var calendarForNavigator: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = navigator.timeZone
        return calendar
    }

    private func formattedDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = navigator.timeZone
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func dashboardRow(_ title: String, value: Int64, emphasized: Bool = false) -> some View {
        HStack {
            Text(title).fontWeight(emphasized ? .semibold : .regular)
            Spacer()
            Text(display(value)).fontWeight(emphasized ? .semibold : .regular).monospacedDigit()
        }
    }

    private func display(_ minorUnits: Int64) -> String {
        privacyMode.displayAmount(CurrencyFormatter.string(minorUnits: minorUnits, currencyCode: model.state.baseCurrencyCode))
    }
}
#endif
