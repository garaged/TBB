#if canImport(SwiftUI) && canImport(CoreData)
import SwiftUI
import TBBFoundation

struct LedgerHomeView: View {
    let privacyMode: PrivacyMode
    @StateObject private var model = LedgerViewModel()
    @State private var showingAccountEntry = false

    var body: some View {
        List {
            Section {
                Text(totalBalanceText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .accessibilityLabel(privacyMode == .concealed ? "Amounts hidden" : totalBalanceText)
            } header: {
                Text("Available")
            }

            Section("Accounts") {
                if model.state.accounts.isEmpty {
                    ContentUnavailableView(
                        "Add your first account",
                        systemImage: "wallet.bifold",
                        description: Text("Start with cash, checking, savings, or a credit card.")
                    )
                } else {
                    ForEach(model.state.accounts) { account in
                        HStack {
                            Label(account.name, systemImage: icon(for: account.kind))
                            Spacer()
                            Text(display(model.balance(for: account)))
                                .monospacedDigit()
                        }
                    }
                }

                Button {
                    showingAccountEntry = true
                } label: {
                    Label("Add account", systemImage: "plus.circle.fill")
                }
            }

            Section {
                Text("Transactions will appear here after you record income, expenses, or transfers.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Recent activity")
            }
        }
        .navigationTitle("Overview")
        .sheet(isPresented: $showingAccountEntry) {
            AccountEntryView(baseCurrencyCode: model.state.baseCurrencyCode) { name, kind, openingBalance in
                model.addAccount(name: name, kind: kind, openingBalanceMinorUnits: openingBalance)
            }
        }
        .alert(
            "Could not update budget",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.dismissError() } }
            )
        ) {
            Button("OK", role: .cancel) { model.dismissError() }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var totalBalanceText: String {
        let total = model.state.accounts.reduce(Int64(0)) { $0 + model.balance(for: $1).minorUnits }
        let money = try! Money(minorUnits: total, currencyCode: model.state.baseCurrencyCode)
        return display(money)
    }

    private func display(_ money: Money) -> String {
        privacyMode.displayAmount(
            CurrencyFormatter.string(minorUnits: money.minorUnits, currencyCode: money.currencyCode)
        )
    }

    private func icon(for kind: AccountKind) -> String {
        switch kind {
        case .cash: "banknote"
        case .checking: "building.columns"
        case .savings: "archivebox"
        case .creditCard: "creditcard"
        }
    }
}

private struct AccountEntryView: View {
    let baseCurrencyCode: String
    let onSave: (String, AccountKind, Int64) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: AccountKind = .checking
    @State private var openingBalance = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Account name", text: $name)
                    .textInputAutocapitalization(.words)
                Picker("Type", selection: $kind) {
                    Text("Cash").tag(AccountKind.cash)
                    Text("Checking").tag(AccountKind.checking)
                    Text("Savings").tag(AccountKind.savings)
                    Text("Credit card").tag(AccountKind.creditCard)
                }
                TextField("Opening balance", text: $openingBalance)
                    .keyboardType(.decimalPad)
                Text("Currency: \(baseCurrencyCode)")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("New account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), kind, CurrencyFormatter.minorUnits(from: openingBalance))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

enum CurrencyFormatter {
    static func string(minorUnits: Int64, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: Double(minorUnits) / 100)) ?? "\(minorUnits) \(currencyCode)"
    }

    static func minorUnits(from text: String) -> Int64 {
        guard let decimal = Decimal(string: text, locale: .current) else { return 0 }
        return NSDecimalNumber(decimal: decimal * 100).rounding(accordingToBehavior: nil).int64Value
    }
}
#endif
