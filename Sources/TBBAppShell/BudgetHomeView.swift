#if canImport(SwiftUI) && canImport(CoreData)
import SwiftUI
import TBBFoundation

struct BudgetHomeView: View {
    let privacyMode: PrivacyMode
    @ObservedObject var model: LedgerViewModel
    @State private var cadence: BudgetCadence = .month
    @State private var anchor = Date()
    @State private var showingNewBudget = false
    @State private var editingBudget: BudgetPlan?
    @State private var budgetPendingDeletion: BudgetPlan?

    private var navigator: DashboardNavigator {
        DashboardNavigator(period: cadence.dashboardPeriod, anchor: anchor)
    }

    private var currentBudgets: [BudgetPlan] {
        model.state.budgets.filter { $0.cadence == cadence }
    }

    var body: some View {
        List {
            Section {
                Picker("Budget cadence", selection: $cadence) {
                    ForEach(BudgetCadence.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack {
                    Button { anchor = navigator.moving(by: -1).anchor } label: { Label("Previous", systemImage: "chevron.left") }
                        .buttonStyle(.bordered)
                    Spacer()
                    Text(rangeTitle).font(.headline)
                    Spacer()
                    Button { anchor = navigator.moving(by: 1).anchor } label: { Label("Next", systemImage: "chevron.right") }
                        .buttonStyle(.bordered)
                }
                Text("Full category balances carry into the next \(cadence.rawValue).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Category budgets") {
                if currentBudgets.isEmpty {
                    ContentUnavailableView("Add a category budget", systemImage: "target", description: Text("Plans automatically recur and carry their full balance into the next period."))
                } else {
                    ForEach(currentBudgets) { plan in
                        let progress = BudgetInsights.progress(plan: plan, state: model.state, anchor: anchor)
                        Button { editingBudget = plan } label: {
                            budgetRow(plan: plan, progress: progress)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens budget editing")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Edit") { editingBudget = plan }.tint(.accentColor)
                            Button("Delete", role: .destructive) { budgetPendingDeletion = plan }
                        }
                        .contextMenu {
                            Button("Edit budget") { editingBudget = plan }
                            Button("Delete budget", role: .destructive) { budgetPendingDeletion = plan }
                        }
                    }
                }
                Button { showingNewBudget = true } label: { Label("Add budget", systemImage: "plus.circle.fill") }
                    .disabled(model.state.categories.filter { $0.kind == .expense }.isEmpty)
            }
        }
        .navigationTitle("Budgets")
        .sheet(isPresented: $showingNewBudget) {
            BudgetEntryView(state: model.state, defaultCadence: cadence, privacyMode: privacyMode) { categoryID, cadence, amount, startsAt in
                model.addBudget(categoryID: categoryID, cadence: cadence, minorUnits: CurrencyFormatter.minorUnits(from: amount), startsAt: startsAt)
            }
        }
        .sheet(item: $editingBudget) { plan in
            BudgetEntryView(state: model.state, plan: plan, defaultCadence: cadence, privacyMode: privacyMode) { categoryID, cadence, amount, startsAt in
                model.updateBudget(id: plan.id, categoryID: categoryID, cadence: cadence, minorUnits: CurrencyFormatter.minorUnits(from: amount), startsAt: startsAt)
            }
        }
        .alert("Delete budget?", isPresented: Binding(get: { budgetPendingDeletion != nil }, set: { if !$0 { budgetPendingDeletion = nil } })) {
            Button("Delete", role: .destructive) {
                if let budgetPendingDeletion { model.deleteBudget(id: budgetPendingDeletion.id) }
                budgetPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { budgetPendingDeletion = nil }
        } message: {
            Text("This removes the plan but leaves all recorded transactions unchanged.")
        }
        .alert("Could not update budget", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.dismissError() } })) {
            Button("OK", role: .cancel) { model.dismissError() }
        } message: { Text(model.errorMessage ?? "") }
    }

    private var rangeTitle: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = navigator.timeZone
        switch cadence {
        case .week:
            let calendar = Calendar.autoupdatingCurrent
            let end = calendar.date(byAdding: .day, value: -1, to: navigator.range.endExclusive) ?? navigator.range.endExclusive
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: navigator.range.start)) – \(formatter.string(from: end))"
        case .month:
            formatter.dateFormat = "LLLL yyyy"
        case .quarter:
            let components = Calendar.autoupdatingCurrent.dateComponents([.quarter, .year], from: navigator.range.start)
            return "Q\(components.quarter ?? 1) \(components.year ?? 0)"
        case .year:
            formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: navigator.range.start)
    }

    private func budgetRow(plan: BudgetPlan, progress: BudgetProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.categoryName(for: plan.categoryID)).fontWeight(.semibold)
                Spacer()
                Text(statusLabel(progress.alertState))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(statusColor(progress.alertState))
            }
            ProgressView(value: Double(min(progress.consumedPermille, 1_000)), total: 1_000)
                .tint(statusColor(progress.alertState))
            HStack {
                Text("Remaining")
                Spacer()
                Text(display(progress.remainingMinorUnits)).monospacedDigit()
            }
            .font(.footnote)
        }
    }

    private func display(_ minorUnits: Int64) -> String {
        privacyMode.displayAmount(CurrencyFormatter.string(minorUnits: minorUnits, currencyCode: model.state.baseCurrencyCode))
    }

    private func statusLabel(_ status: BudgetAlertState) -> String {
        switch status {
        case .onTrack: "On track"
        case .warning: "Nearly spent"
        case .exceeded: "Exceeded"
        }
    }

    private func statusColor(_ status: BudgetAlertState) -> Color {
        switch status {
        case .onTrack: .green
        case .warning: .orange
        case .exceeded: .red
        }
    }
}

private struct BudgetEntryView: View {
    let state: LedgerState
    let planID: UUID?
    let privacyMode: PrivacyMode
    let onSave: (UUID, BudgetCadence, String, Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var categoryID: UUID?
    @State private var cadence: BudgetCadence
    @State private var amount: String
    @State private var startsAt: Date

    init(state: LedgerState, plan: BudgetPlan? = nil, defaultCadence: BudgetCadence, privacyMode: PrivacyMode, onSave: @escaping (UUID, BudgetCadence, String, Date) -> Void) {
        self.state = state
        planID = plan?.id
        self.privacyMode = privacyMode
        self.onSave = onSave
        _categoryID = State(initialValue: plan?.categoryID)
        _cadence = State(initialValue: plan?.cadence ?? defaultCadence)
        _amount = State(initialValue: plan.map { CurrencyFormatter.inputString(minorUnits: $0.plannedMinorUnits) } ?? "")
        _startsAt = State(initialValue: plan?.startsAt ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $categoryID) {
                    Text("Select category").tag(UUID?.none)
                    ForEach(state.categories.filter { $0.kind == .expense }) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("Cadence", selection: $cadence) {
                    ForEach(BudgetCadence.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                if planID != nil && privacyMode == .concealed {
                    SecureField("Planned amount", text: $amount).accessibilityLabel("Planned amount hidden")
                } else {
                    TextField("Planned amount", text: $amount)
                }
                DatePicker("Starts", selection: $startsAt, displayedComponents: .date)
                Text("Full unused or overspent balance carries forward automatically. Alerts are sent locally at 80% and 100%.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(planID == nil ? "New budget" : "Edit budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(planID == nil ? "Add" : "Update") {
                        if let categoryID {
                            onSave(categoryID, cadence, amount, startsAt)
                            dismiss()
                        }
                    }
                    .disabled(categoryID == nil || CurrencyFormatter.minorUnits(from: amount) <= 0)
                }
            }
        }
    }
}
#endif
