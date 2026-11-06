#if canImport(SwiftUI) && canImport(CoreData)
import SwiftUI
import TBBFoundation

@MainActor
private final class DashboardViewModel: ObservableObject {
    @Published private(set) var state: LedgerState
    @Published var navigator: DashboardNavigator

    init() {
        let zone = TimeZone.current
        navigator = DashboardNavigator(period: .month, timeZone: zone)
        state = try! LedgerState(baseCurrencyCode: "MXN")
        if let store = try? CoreDataLedgerStore() {
            state = (try? store.load(baseCurrencyCode: "MXN")) ?? state
        }
    }

    var summary: DashboardSummary {
        LedgerInsights.summarize(state: state, range: navigator.range)
    }

    func move(_ offset: Int) { navigator = navigator.moving(by: offset) }
    func change(_ period: DashboardPeriod) { navigator = navigator.changingPeriod(to: period) }
}

struct DashboardHomeView: View {
    let privacyMode: PrivacyMode
    @StateObject private var model = DashboardViewModel()

    var body: some View {
        List {
            Section {
                Picker("Period", selection: Binding(get: { model.navigator.period }, set: { model.change($0) })) {
                    ForEach(DashboardPeriod.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack {
                    Button { model.move(-1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Previous period")
                    Spacer()
                    Text(rangeTitle).font(.headline)
                    Spacer()
                    Button { model.move(1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Next period")
                }
            }

            Section("Cash flow") {
                dashboardRow("Income", value: model.summary.incomeMinorUnits)
                dashboardRow("Spending", value: -model.summary.expenseMinorUnits)
                dashboardRow("Net cash flow", value: model.summary.netCashFlowMinorUnits, emphasized: true)
            }

            Section("Spending by category") {
                if model.summary.spendingByCategory.isEmpty {
                    Text("No expenses in this period.").foregroundStyle(.secondary)
                } else {
                    ForEach(model.summary.spendingByCategory.keys.sorted { $0.uuidString < $1.uuidString }, id: \.self) { id in
                        HStack {
                            Text(model.state.categories.first(where: { $0.id == id })?.name ?? "Uncategorized")
                            Spacer()
                            Text(display(model.summary.spendingByCategory[id] ?? 0)).monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("Dashboard")
    }

    private var rangeTitle: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = model.navigator.timeZone
        formatter.dateFormat = model.navigator.period == .year ? "yyyy" : "MMM yyyy"
        return formatter.string(from: model.navigator.range.start)
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
