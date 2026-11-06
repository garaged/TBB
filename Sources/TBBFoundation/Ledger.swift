import Foundation

public enum LedgerError: Error, Equatable, Sendable {
    case invalidCurrencyCode
    case nonPositiveAmount
    case duplicateAccountName
    case duplicateCategoryName
    case unknownAccount
    case unknownCategory
    case unknownTransaction
    case wrongCategoryKind
    case accountCurrencyMismatch
    case sameTransferAccount
}

public struct Money: Codable, Equatable, Sendable {
    public let minorUnits: Int64
    public let currencyCode: String

    public init(minorUnits: Int64, currencyCode: String) throws {
        let normalized = currencyCode.uppercased()
        guard normalized.count == 3, normalized.allSatisfy({ $0.isLetter }) else {
            throw LedgerError.invalidCurrencyCode
        }
        self.minorUnits = minorUnits
        self.currencyCode = normalized
    }
}

public enum AccountKind: String, Codable, Sendable {
    case cash
    case checking
    case savings
    case creditCard
}

public struct LedgerAccount: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let kind: AccountKind
    public let currencyCode: String
    public let openingBalanceMinorUnits: Int64

    public init(
        id: UUID = UUID(),
        name: String,
        kind: AccountKind,
        currencyCode: String,
        openingBalanceMinorUnits: Int64 = 0
    ) throws {
        self.id = id
        self.name = name
        self.kind = kind
        self.currencyCode = try Money(minorUnits: 0, currencyCode: currencyCode).currencyCode
        self.openingBalanceMinorUnits = openingBalanceMinorUnits
    }
}

public enum CategoryKind: String, Codable, Sendable {
    case expense
    case income
}

public struct LedgerCategory: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let kind: CategoryKind

    public init(id: UUID = UUID(), name: String, kind: CategoryKind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

public enum LedgerTransactionKind: String, Codable, Sendable {
    case expense
    case income
    case transfer
}

public struct LedgerTransaction: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let kind: LedgerTransactionKind
    public let amount: Money
    public let accountID: UUID
    public let counterpartyAccountID: UUID?
    public let categoryID: UUID?
    public let occurredAt: Date
    public let note: String

    public init(
        id: UUID = UUID(),
        kind: LedgerTransactionKind,
        amount: Money,
        accountID: UUID,
        counterpartyAccountID: UUID? = nil,
        categoryID: UUID? = nil,
        occurredAt: Date,
        note: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.accountID = accountID
        self.counterpartyAccountID = counterpartyAccountID
        self.categoryID = categoryID
        self.occurredAt = occurredAt
        self.note = note
    }
}

public struct LedgerState: Codable, Equatable, Sendable {
    public let baseCurrencyCode: String
    public private(set) var accounts: [LedgerAccount]
    public private(set) var categories: [LedgerCategory]
    public private(set) var transactions: [LedgerTransaction]

    public init(baseCurrencyCode: String, accounts: [LedgerAccount] = [], categories: [LedgerCategory] = [], transactions: [LedgerTransaction] = []) throws {
        self.baseCurrencyCode = try Money(minorUnits: 0, currencyCode: baseCurrencyCode).currencyCode
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions
    }

    public mutating func addAccount(_ account: LedgerAccount) throws {
        guard !accounts.contains(where: { $0.name.localizedCaseInsensitiveCompare(account.name) == .orderedSame }) else {
            throw LedgerError.duplicateAccountName
        }
        accounts.append(account)
    }

    public mutating func addCategory(_ category: LedgerCategory) throws {
        guard !categories.contains(where: { $0.name.localizedCaseInsensitiveCompare(category.name) == .orderedSame && $0.kind == category.kind }) else {
            throw LedgerError.duplicateCategoryName
        }
        categories.append(category)
    }

    public mutating func recordExpense(amount: Money, accountID: UUID, categoryID: UUID, occurredAt: Date, note: String = "") throws {
        transactions.append(try validatedTransaction(
            id: UUID(),
            kind: .expense,
            amount: amount,
            accountID: accountID,
            categoryID: categoryID,
            counterpartyAccountID: nil,
            occurredAt: occurredAt,
            note: note
        ))
    }

    public mutating func recordIncome(amount: Money, accountID: UUID, categoryID: UUID, occurredAt: Date, note: String = "") throws {
        transactions.append(try validatedTransaction(
            id: UUID(),
            kind: .income,
            amount: amount,
            accountID: accountID,
            categoryID: categoryID,
            counterpartyAccountID: nil,
            occurredAt: occurredAt,
            note: note
        ))
    }

    public mutating func recordTransfer(amount: Money, fromAccountID: UUID, toAccountID: UUID, occurredAt: Date, note: String = "") throws {
        transactions.append(try validatedTransaction(
            id: UUID(),
            kind: .transfer,
            amount: amount,
            accountID: fromAccountID,
            categoryID: nil,
            counterpartyAccountID: toAccountID,
            occurredAt: occurredAt,
            note: note
        ))
    }

    public mutating func updateTransaction(
        id: UUID,
        kind: LedgerTransactionKind,
        amount: Money,
        accountID: UUID,
        categoryID: UUID?,
        counterpartyAccountID: UUID?,
        occurredAt: Date,
        note: String
    ) throws {
        guard let index = transactions.firstIndex(where: { $0.id == id }) else { throw LedgerError.unknownTransaction }
        let replacement = try validatedTransaction(
            id: id,
            kind: kind,
            amount: amount,
            accountID: accountID,
            categoryID: categoryID,
            counterpartyAccountID: counterpartyAccountID,
            occurredAt: occurredAt,
            note: note
        )
        transactions[index] = replacement
    }

    public mutating func deleteTransaction(id: UUID) throws {
        guard let index = transactions.firstIndex(where: { $0.id == id }) else { throw LedgerError.unknownTransaction }
        transactions.remove(at: index)
    }

    public func balance(of accountID: UUID) throws -> Money {
        let account = try account(id: accountID)
        let movements = transactions.reduce(Int64(0)) { total, transaction in
            switch transaction.kind {
            case .expense where transaction.accountID == accountID:
                total - transaction.amount.minorUnits
            case .income where transaction.accountID == accountID:
                total + transaction.amount.minorUnits
            case .transfer where transaction.accountID == accountID:
                total - transaction.amount.minorUnits
            case .transfer where transaction.counterpartyAccountID == accountID:
                total + transaction.amount.minorUnits
            default:
                total
            }
        }
        return try Money(minorUnits: account.openingBalanceMinorUnits + movements, currencyCode: account.currencyCode)
    }

    private func validatedTransaction(
        id: UUID,
        kind: LedgerTransactionKind,
        amount: Money,
        accountID: UUID,
        categoryID: UUID?,
        counterpartyAccountID: UUID?,
        occurredAt: Date,
        note: String
    ) throws -> LedgerTransaction {
        try validatePositive(amount)
        let source = try account(id: accountID)
        guard source.currencyCode == amount.currencyCode else { throw LedgerError.accountCurrencyMismatch }

        switch kind {
        case .expense:
            guard let categoryID else { throw LedgerError.unknownCategory }
            guard try category(id: categoryID).kind == .expense else { throw LedgerError.wrongCategoryKind }
            return .init(id: id, kind: kind, amount: amount, accountID: accountID, categoryID: categoryID, occurredAt: occurredAt, note: note)
        case .income:
            guard let categoryID else { throw LedgerError.unknownCategory }
            guard try category(id: categoryID).kind == .income else { throw LedgerError.wrongCategoryKind }
            return .init(id: id, kind: kind, amount: amount, accountID: accountID, categoryID: categoryID, occurredAt: occurredAt, note: note)
        case .transfer:
            guard let counterpartyAccountID else { throw LedgerError.unknownAccount }
            guard accountID != counterpartyAccountID else { throw LedgerError.sameTransferAccount }
            let destination = try account(id: counterpartyAccountID)
            guard destination.currencyCode == amount.currencyCode else { throw LedgerError.accountCurrencyMismatch }
            return .init(id: id, kind: kind, amount: amount, accountID: accountID, counterpartyAccountID: counterpartyAccountID, occurredAt: occurredAt, note: note)
        }
    }

    private func account(id: UUID) throws -> LedgerAccount {
        guard let account = accounts.first(where: { $0.id == id }) else { throw LedgerError.unknownAccount }
        return account
    }

    private func category(id: UUID) throws -> LedgerCategory {
        guard let category = categories.first(where: { $0.id == id }) else { throw LedgerError.unknownCategory }
        return category
    }

    private func validatePositive(_ amount: Money) throws {
        guard amount.minorUnits > 0 else { throw LedgerError.nonPositiveAmount }
    }
}

public actor LedgerStore {
    private var state: LedgerState

    public init(initialState: LedgerState) {
        self.state = initialState
    }

    public func snapshot() -> LedgerState { state }

    public func replace(with newState: LedgerState) {
        state = newState
    }
}
