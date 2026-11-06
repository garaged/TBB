import Foundation
import Testing
@testable import TBBFoundation

@Test func sharedProjectionIsIdempotentAndUsesDeterministicMutationOrder() throws {
    let (space, base, transaction) = try sharedFixture()
    let device = UUID()
    let first = LedgerTransaction(
        id: transaction.id,
        kind: .expense,
        amount: try Money(minorUnits: 1_000, currencyCode: "MXN"),
        accountID: transaction.accountID,
        categoryID: transaction.categoryID,
        occurredAt: transaction.occurredAt
    )
    let later = LedgerTransaction(
        id: transaction.id,
        kind: .expense,
        amount: try Money(minorUnits: 2_500, currencyCode: "MXN"),
        accountID: transaction.accountID,
        categoryID: transaction.categoryID,
        occurredAt: transaction.occurredAt
    )
    let initial = BudgetSpaceMutation(spaceID: space.id, logicalTimestamp: 10, originDeviceID: device, payload: .upsertTransaction(first))
    let winning = BudgetSpaceMutation(spaceID: space.id, logicalTimestamp: 20, originDeviceID: device, payload: .upsertTransaction(later))

    let projection = BudgetSpaceProjector.rebuild(space: space, baseState: base, mutations: [winning, initial, winning])

    #expect(projection.state.transactions.first?.amount.minorUnits == 2_500)
    #expect(projection.auditEntries.map(\.disposition) == [.applied, .applied, .ignoredDuplicate])
}

@Test func sharedProjectionTombstonesPreventOfflineUpdatesFromResurrectingRecords() throws {
    let (space, base, transaction) = try sharedFixture()
    let device = UUID()
    let delete = BudgetSpaceMutation(spaceID: space.id, logicalTimestamp: 10, originDeviceID: device, payload: .deleteTransaction(transaction.id))
    let staleUpdate = BudgetSpaceMutation(
        spaceID: space.id,
        logicalTimestamp: 20,
        originDeviceID: device,
        payload: .upsertTransaction(transaction)
    )

    let projection = BudgetSpaceProjector.rebuild(space: space, baseState: base, mutations: [staleUpdate, delete])

    #expect(projection.state.transactions.isEmpty)
    #expect(projection.auditEntries.map(\.disposition) == [.applied, .ignoredTombstone])
}

@Test func sharedProjectionRejectsMutationsFromAnotherBudgetSpace() throws {
    let (space, base, transaction) = try sharedFixture()
    let foreign = BudgetSpaceMutation(
        spaceID: UUID(),
        logicalTimestamp: 1,
        originDeviceID: UUID(),
        payload: .deleteTransaction(transaction.id)
    )

    let projection = BudgetSpaceProjector.rebuild(space: space, baseState: base, mutations: [foreign])

    #expect(projection.state == base)
    #expect(projection.auditEntries.first?.disposition == .ignoredWrongSpace)
}

private func sharedFixture() throws -> (BudgetSpace, LedgerState, LedgerTransaction) {
    let space = BudgetSpace(name: "Household", scope: .shared, role: .owner)
    let account = try LedgerAccount(name: "Checking", kind: .checking, currencyCode: "MXN")
    let category = LedgerCategory(name: "Food", kind: .expense)
    let transaction = LedgerTransaction(
        kind: .expense,
        amount: try Money(minorUnits: 500, currencyCode: "MXN"),
        accountID: account.id,
        categoryID: category.id,
        occurredAt: Date(timeIntervalSince1970: 1_704_067_200)
    )
    let state = try LedgerState(
        baseCurrencyCode: "MXN",
        accounts: [account],
        categories: [category],
        transactions: [transaction]
    )
    return (space, state, transaction)
}
