import Foundation

public enum BudgetSpaceScope: String, Codable, Sendable {
    case privateSpace = "private"
    case shared
}

public enum BudgetSpaceRole: String, Codable, Sendable {
    case owner
    case participant
}

public struct BudgetSpace: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public let scope: BudgetSpaceScope
    public let role: BudgetSpaceRole

    public init(id: UUID = UUID(), name: String, scope: BudgetSpaceScope, role: BudgetSpaceRole) {
        self.id = id
        self.name = name
        self.scope = scope
        self.role = role
    }
}

public enum BudgetSpaceMutationPayload: Codable, Equatable, Sendable {
    case upsertAccount(LedgerAccount)
    case upsertCategory(LedgerCategory)
    case upsertTransaction(LedgerTransaction)
    case upsertBudget(BudgetPlan)
    case deleteTransaction(UUID)
    case deleteBudget(UUID)

    fileprivate var redactedAction: String {
        switch self {
        case .upsertAccount: "account changed"
        case .upsertCategory: "category changed"
        case .upsertTransaction: "transaction changed"
        case .upsertBudget: "budget changed"
        case .deleteTransaction: "transaction deleted"
        case .deleteBudget: "budget deleted"
        }
    }

    fileprivate var recordReference: BudgetSpaceRecordReference? {
        switch self {
        case let .upsertTransaction(transaction): .transaction(transaction.id)
        case let .upsertBudget(plan): .budget(plan.id)
        case let .deleteTransaction(id): .transaction(id)
        case let .deleteBudget(id): .budget(id)
        case .upsertAccount, .upsertCategory: nil
        }
    }
}

public struct BudgetSpaceMutation: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let spaceID: UUID
    public let logicalTimestamp: Int64
    public let originDeviceID: UUID
    public let payload: BudgetSpaceMutationPayload

    public init(
        id: UUID = UUID(),
        spaceID: UUID,
        logicalTimestamp: Int64,
        originDeviceID: UUID,
        payload: BudgetSpaceMutationPayload
    ) {
        self.id = id
        self.spaceID = spaceID
        self.logicalTimestamp = logicalTimestamp
        self.originDeviceID = originDeviceID
        self.payload = payload
    }
}

public enum BudgetSpaceRecordReference: Hashable, Codable, Sendable {
    case transaction(UUID)
    case budget(UUID)
}

public enum BudgetSpaceMutationDisposition: String, Codable, Sendable {
    case applied
    case ignoredDuplicate
    case ignoredTombstone
    case ignoredWrongSpace
    case rejectedInvalid
}

public struct BudgetSpaceAuditEntry: Identifiable, Codable, Equatable, Sendable {
    public let mutationID: UUID
    public let spaceID: UUID
    public let logicalTimestamp: Int64
    public let action: String
    public let disposition: BudgetSpaceMutationDisposition

    public var id: UUID { mutationID }

    public init(
        mutationID: UUID,
        spaceID: UUID,
        logicalTimestamp: Int64,
        action: String,
        disposition: BudgetSpaceMutationDisposition
    ) {
        self.mutationID = mutationID
        self.spaceID = spaceID
        self.logicalTimestamp = logicalTimestamp
        self.action = action
        self.disposition = disposition
    }
}

public struct BudgetSpaceProjection: Equatable, Sendable {
    public let state: LedgerState
    public let auditEntries: [BudgetSpaceAuditEntry]

    public init(state: LedgerState, auditEntries: [BudgetSpaceAuditEntry]) {
        self.state = state
        self.auditEntries = auditEntries
    }
}

public enum BudgetSpaceProjector {
    public static func rebuild(
        space: BudgetSpace,
        baseState: LedgerState,
        mutations: [BudgetSpaceMutation]
    ) -> BudgetSpaceProjection {
        var state = baseState
        var seen = Set<UUID>()
        var tombstones = Set<BudgetSpaceRecordReference>()
        var auditEntries: [BudgetSpaceAuditEntry] = []

        let ordered = mutations.sorted {
            if $0.logicalTimestamp != $1.logicalTimestamp { return $0.logicalTimestamp < $1.logicalTimestamp }
            if $0.id.uuidString != $1.id.uuidString { return $0.id.uuidString < $1.id.uuidString }
            return $0.originDeviceID.uuidString < $1.originDeviceID.uuidString
        }

        for mutation in ordered {
            let action = mutation.payload.redactedAction
            let disposition: BudgetSpaceMutationDisposition

            if mutation.spaceID != space.id {
                disposition = .ignoredWrongSpace
            } else if !seen.insert(mutation.id).inserted {
                disposition = .ignoredDuplicate
            } else if case .deleteTransaction = mutation.payload {
                if let reference = mutation.payload.recordReference { tombstones.insert(reference) }
                state = deleting(mutation.payload, from: state)
                disposition = .applied
            } else if case .deleteBudget = mutation.payload {
                if let reference = mutation.payload.recordReference { tombstones.insert(reference) }
                state = deleting(mutation.payload, from: state)
                disposition = .applied
            } else if let reference = mutation.payload.recordReference, tombstones.contains(reference) {
                disposition = .ignoredTombstone
            } else if let next = try? applying(mutation.payload, to: state) {
                state = next
                disposition = .applied
            } else {
                disposition = .rejectedInvalid
            }

            auditEntries.append(.init(
                mutationID: mutation.id,
                spaceID: mutation.spaceID,
                logicalTimestamp: mutation.logicalTimestamp,
                action: action,
                disposition: disposition
            ))
        }

        return .init(state: state, auditEntries: auditEntries)
    }

    private static func deleting(_ payload: BudgetSpaceMutationPayload, from state: LedgerState) -> LedgerState {
        switch payload {
        case let .deleteTransaction(id):
            return try! LedgerState(
                baseCurrencyCode: state.baseCurrencyCode,
                accounts: state.accounts,
                categories: state.categories,
                transactions: state.transactions.filter { $0.id != id },
                budgets: state.budgets
            )
        case let .deleteBudget(id):
            return try! LedgerState(
                baseCurrencyCode: state.baseCurrencyCode,
                accounts: state.accounts,
                categories: state.categories,
                transactions: state.transactions,
                budgets: state.budgets.filter { $0.id != id }
            )
        default:
            return state
        }
    }

    private static func applying(_ payload: BudgetSpaceMutationPayload, to state: LedgerState) throws -> LedgerState {
        var accounts = state.accounts
        var categories = state.categories
        var transactions = state.transactions
        var budgets = state.budgets

        switch payload {
        case let .upsertAccount(account):
            _ = try Money(minorUnits: 0, currencyCode: account.currencyCode)
            guard !accounts.contains(where: {
                $0.id != account.id &&
                $0.name.localizedCaseInsensitiveCompare(account.name) == .orderedSame
            }) else { throw LedgerError.duplicateAccountName }
            if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                accounts[index] = account
            } else {
                accounts.append(account)
            }

        case let .upsertCategory(category):
            guard !categories.contains(where: {
                $0.id != category.id &&
                $0.kind == category.kind &&
                $0.name.localizedCaseInsensitiveCompare(category.name) == .orderedSame
            }) else { throw LedgerError.duplicateCategoryName }
            if let index = categories.firstIndex(where: { $0.id == category.id }) {
                categories[index] = category
            } else {
                categories.append(category)
            }

        case let .upsertTransaction(transaction):
            try validate(transaction: transaction, accounts: accounts, categories: categories)
            if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
                transactions[index] = transaction
            } else {
                transactions.append(transaction)
            }

        case let .upsertBudget(plan):
            guard plan.plannedMinorUnits > 0 else { throw LedgerError.nonPositiveAmount }
            guard categories.first(where: { $0.id == plan.categoryID })?.kind == .expense else {
                throw LedgerError.wrongCategoryKind
            }
            guard !budgets.contains(where: {
                $0.id != plan.id && $0.categoryID == plan.categoryID && $0.cadence == plan.cadence
            }) else { throw LedgerError.duplicateBudget }
            if let index = budgets.firstIndex(where: { $0.id == plan.id }) {
                budgets[index] = plan
            } else {
                budgets.append(plan)
            }

        case .deleteTransaction, .deleteBudget:
            return state
        }

        return try LedgerState(
            baseCurrencyCode: state.baseCurrencyCode,
            accounts: accounts,
            categories: categories,
            transactions: transactions,
            budgets: budgets
        )
    }

    private static func validate(
        transaction: LedgerTransaction,
        accounts: [LedgerAccount],
        categories: [LedgerCategory]
    ) throws {
        guard transaction.amount.minorUnits > 0 else { throw LedgerError.nonPositiveAmount }
        guard let account = accounts.first(where: { $0.id == transaction.accountID }) else {
            throw LedgerError.unknownAccount
        }
        guard account.currencyCode == transaction.amount.currencyCode else {
            throw LedgerError.accountCurrencyMismatch
        }

        switch transaction.kind {
        case .expense, .income:
            guard let categoryID = transaction.categoryID,
                  let category = categories.first(where: { $0.id == categoryID }) else {
                throw LedgerError.unknownCategory
            }
            let expected: CategoryKind = transaction.kind == .expense ? .expense : .income
            guard category.kind == expected else { throw LedgerError.wrongCategoryKind }
        case .transfer:
            guard let counterpartyID = transaction.counterpartyAccountID,
                  counterpartyID != transaction.accountID,
                  let counterparty = accounts.first(where: { $0.id == counterpartyID }) else {
                throw LedgerError.sameTransferAccount
            }
            guard counterparty.currencyCode == transaction.amount.currencyCode else {
                throw LedgerError.accountCurrencyMismatch
            }
        }
    }
}
