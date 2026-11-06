#if canImport(SwiftUI) && canImport(CoreData)
import SwiftUI
import TBBFoundation

struct LedgerHomeView: View {
    let privacyMode: PrivacyMode
    @ObservedObject var model: LedgerViewModel
    @State private var showingAccountEntry = false
    @State private var showingTransactionEntry = false
    @State private var editingTransaction: LedgerTransaction?
    @State private var transactionPendingDeletion: LedgerTransaction?

    var body: some View {
        List {
            Section {
                Text(totalBalanceText).font(.system(size: 32, weight: .bold, design: .rounded))
                    .accessibilityLabel(privacyMode == .concealed ? "Amounts hidden" : totalBalanceText)
            } header: { Text("Available") }

            Section("Accounts") {
                if model.state.accounts.isEmpty {
                    ContentUnavailableView("Add your first account", systemImage: "wallet.bifold", description: Text("Start with cash, checking, savings, or a credit card."))
                } else {
                    ForEach(model.state.accounts) { account in
                        HStack {
                            Label(account.name, systemImage: icon(for: account.kind))
                            Spacer()
                            Text(display(model.balance(for: account))).monospacedDigit()
                        }
                    }
                }
                Button { showingAccountEntry = true } label: { Label("Add account", systemImage: "plus.circle.fill") }
            }

            Section("Recent activity") {
                if model.state.transactions.isEmpty {
                    Text("Record your first expense, income, or transfer.").foregroundStyle(.secondary)
                } else {
                    ForEach(model.state.transactions.sorted(by: { $0.occurredAt > $1.occurredAt })) { transaction in
                        Button { editingTransaction = transaction } label: {
                            transactionRow(transaction)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens transaction editing")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Edit") { editingTransaction = transaction }
                                .tint(.accentColor)
                            Button("Delete", role: .destructive) { transactionPendingDeletion = transaction }
                        }
                        .contextMenu {
                            Button("Edit transaction") { editingTransaction = transaction }
                            Button("Delete transaction", role: .destructive) { transactionPendingDeletion = transaction }
                        }
                    }
                }
                Button { showingTransactionEntry = true } label: { Label("Record transaction", systemImage: "plus.circle.fill") }
                    .disabled(model.state.accounts.isEmpty)
            }
        }
        .navigationTitle("Overview")
        .sheet(isPresented: $showingAccountEntry) {
            AccountEntryView(baseCurrencyCode: model.state.baseCurrencyCode) { name, kind, openingBalance in
                model.addAccount(name: name, kind: kind, openingBalanceMinorUnits: openingBalance)
            }
        }
        .sheet(isPresented: $showingTransactionEntry) {
            TransactionEntryView(state: model.state, privacyMode: privacyMode) { kind, amount, account, category, destination, occurredAt, note in
                model.record(
                    kind: kind,
                    minorUnits: CurrencyFormatter.minorUnits(from: amount),
                    accountID: account,
                    categoryID: category,
                    destinationID: destination,
                    occurredAt: occurredAt,
                    note: note
                )
            }
        }
        .sheet(item: $editingTransaction) { transaction in
            TransactionEntryView(state: model.state, transaction: transaction, privacyMode: privacyMode) { kind, amount, account, category, destination, occurredAt, note in
                model.update(
                    transactionID: transaction.id,
                    kind: kind,
                    minorUnits: CurrencyFormatter.minorUnits(from: amount),
                    accountID: account,
                    categoryID: category,
                    destinationID: destination,
                    occurredAt: occurredAt,
                    note: note
                )
            }
        }
        .alert("Delete transaction?", isPresented: Binding(
            get: { transactionPendingDeletion != nil },
            set: { if !$0 { transactionPendingDeletion = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let transactionPendingDeletion {
                    model.delete(transactionID: transactionPendingDeletion.id)
                }
                transactionPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { transactionPendingDeletion = nil }
        } message: {
            Text("This permanently removes the transaction and recalculates affected balances and dashboard periods.")
        }
        .alert("Could not update budget", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.dismissError() } })) {
            Button("OK", role: .cancel) { model.dismissError() }
        } message: { Text(model.errorMessage ?? "") }
    }

    private func transactionRow(_ transaction: LedgerTransaction) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(model.categoryName(for: transaction.categoryID))
                if !transaction.note.isEmpty { Text(transaction.note).font(.footnote).foregroundStyle(.secondary) }
                Text(transaction.occurredAt, format: .dateTime.year().month(.abbreviated).day().hour().minute())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(display(transaction.amount)).monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    private var totalBalanceText: String {
        let total = model.state.accounts.reduce(Int64(0)) { $0 + model.balance(for: $1).minorUnits }
        return display(try! Money(minorUnits: total, currencyCode: model.state.baseCurrencyCode))
    }

    private func display(_ money: Money) -> String {
        privacyMode.displayAmount(CurrencyFormatter.string(minorUnits: money.minorUnits, currencyCode: money.currencyCode))
    }

    private func icon(for kind: AccountKind) -> String {
        switch kind { case .cash: "banknote"; case .checking: "building.columns"; case .savings: "archivebox"; case .creditCard: "creditcard" }
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
                Picker("Type", selection: $kind) { Text("Cash").tag(AccountKind.cash); Text("Checking").tag(AccountKind.checking); Text("Savings").tag(AccountKind.savings); Text("Credit card").tag(AccountKind.creditCard) }
                TextField("Opening balance", text: $openingBalance)
                Text("Currency: \(baseCurrencyCode)").foregroundStyle(.secondary)
            }.navigationTitle("New account").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), kind, CurrencyFormatter.minorUnits(from: openingBalance)); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }
}

private struct TransactionEntryView: View {
    let state: LedgerState
    let transactionID: UUID?
    let privacyMode: PrivacyMode
    let onSave: (LedgerTransactionKind, String, UUID, UUID?, UUID?, Date, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var kind: LedgerTransactionKind
    @State private var amount: String
    @State private var accountID: UUID?
    @State private var categoryID: UUID?
    @State private var destinationID: UUID?
    @State private var occurredAt: Date
    @State private var note: String

    init(
        state: LedgerState,
        transaction: LedgerTransaction? = nil,
        privacyMode: PrivacyMode,
        onSave: @escaping (LedgerTransactionKind, String, UUID, UUID?, UUID?, Date, String) -> Void
    ) {
        self.state = state
        transactionID = transaction?.id
        self.privacyMode = privacyMode
        self.onSave = onSave
        _kind = State(initialValue: transaction?.kind ?? .expense)
        _amount = State(initialValue: transaction.map { CurrencyFormatter.inputString(minorUnits: $0.amount.minorUnits) } ?? "")
        _accountID = State(initialValue: transaction?.accountID)
        _categoryID = State(initialValue: transaction?.categoryID)
        _destinationID = State(initialValue: transaction?.counterpartyAccountID)
        _occurredAt = State(initialValue: transaction?.occurredAt ?? Date())
        _note = State(initialValue: transaction?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) { Text("Expense").tag(LedgerTransactionKind.expense); Text("Income").tag(LedgerTransactionKind.income); Text("Transfer").tag(LedgerTransactionKind.transfer) }
                if transactionID != nil && privacyMode == .concealed {
                    SecureField("Amount", text: $amount)
                        .accessibilityLabel("Amount hidden")
                } else {
                    TextField("Amount", text: $amount)
                }
                DatePicker("Date and time", selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
                Picker("Account", selection: $accountID) { Text("Select account").tag(UUID?.none); ForEach(state.accounts) { Text($0.name).tag(Optional($0.id)) } }
                if kind == .transfer {
                    Picker("To account", selection: $destinationID) { Text("Select destination").tag(UUID?.none); ForEach(state.accounts) { Text($0.name).tag(Optional($0.id)) } }
                } else {
                    Picker("Category", selection: $categoryID) { Text("Select category").tag(UUID?.none); ForEach(state.categories.filter { $0.kind == (kind == .expense ? .expense : .income) }) { Text($0.name).tag(Optional($0.id)) } }
                }
                TextField("Note (optional)", text: $note)
            }.navigationTitle(transactionID == nil ? "New transaction" : "Edit transaction").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(transactionID == nil ? "Save" : "Update") {
                        if let accountID {
                            onSave(kind, amount, accountID, categoryID, destinationID, occurredAt, note)
                            dismiss()
                        }
                    }
                    .disabled(accountID == nil || CurrencyFormatter.minorUnits(from: amount) <= 0 || (kind == .transfer ? destinationID == nil : categoryID == nil))
                }
            }
        }
    }
}

enum CurrencyFormatter {
    static func string(minorUnits: Int64, currencyCode: String) -> String {
        let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: Double(minorUnits) / 100)) ?? "\(minorUnits) \(currencyCode)"
    }

    static func inputString(minorUnits: Int64) -> String {
        NSDecimalNumber(decimal: Decimal(minorUnits) / 100).stringValue
    }

    static func minorUnits(from text: String) -> Int64 {
        guard let decimal = Decimal(string: text, locale: .current) else { return 0 }
        return NSDecimalNumber(decimal: decimal * 100).rounding(accordingToBehavior: nil).int64Value
    }
}
#endif
