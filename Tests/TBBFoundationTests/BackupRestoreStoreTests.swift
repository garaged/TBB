#if canImport(CoreData)
import CoreData
import Foundation
import Testing
@testable import TBBFoundation

@MainActor @Test func restoreCreatesIndependentPrivateCopy() throws {
    let store = try CoreDataLedgerStore(inMemory: true)
    let original = try store.defaultBudgetSpace(baseCurrencyCode: "MXN")
    let originalState = try store.load(spaceID: original.id)
    var restoredState = try LedgerState(baseCurrencyCode: "USD")
    try restoredState.addAccount(LedgerAccount(name: "Cash", kind: .cash, currencyCode: "USD"))
    let copyID = try store.restorePrivateCopy(restoredState, name: "Recovered")
    try store.refreshLocalView()
    let spaces = try store.budgetSpaces(baseCurrencyCode: "MXN")
    #expect(copyID != original.id)
    #expect(spaces.first(where: { $0.id == copyID })?.scope == .privateSpace)
    #expect(spaces.first(where: { $0.id == copyID })?.role == .owner)
    #expect(try store.load(spaceID: copyID) == restoredState)
    #expect(try store.load(spaceID: original.id) == originalState)
}

@MainActor @Test func invalidRestoreLeavesExistingSpaceUntouched() throws {
    let store = try CoreDataLedgerStore(inMemory: true)
    let original = try store.defaultBudgetSpace(baseCurrencyCode: "MXN")
    let originalState = try store.load(spaceID: original.id)
    let bad = LedgerTransaction(kind: .expense, amount: try Money(minorUnits: 1, currencyCode: "MXN"), accountID: UUID(), categoryID: UUID(), occurredAt: .now)
    let invalid = try LedgerState(baseCurrencyCode: "MXN", transactions: [bad])
    #expect(throws: BackupValidationError.invalidLedger) {
        try store.restorePrivateCopy(invalid, name: "Recovered")
    }
    #expect(try store.budgetSpaces(baseCurrencyCode: "MXN").count == 1)
    #expect(try store.load(spaceID: original.id) == originalState)
}

@MainActor @Test func failedSaveRollsBackAndExplicitRetriesCreateIndependentCopies() throws {
    enum SaveFailure: Error { case unavailable }
    let store = try CoreDataLedgerStore(inMemory: true)
    let original = try store.defaultBudgetSpace(baseCurrencyCode: "MXN")
    let state = try store.load(spaceID: original.id)
    let payload = try JSONEncoder().encode(state)
    #expect(throws: SaveFailure.unavailable) {
        try store.insertPrivateCopy(payload, name: "Copy") { context in
            #expect(context.insertedObjects.count == 1)
            throw SaveFailure.unavailable
        }
    }
    #expect(try store.budgetSpaces(baseCurrencyCode: "MXN") == [original])
    let first = try store.restorePrivateCopy(state, name: "Copy")
    let second = try store.restorePrivateCopy(state, name: "Copy")
    #expect(Set([original.id, first, second]).count == 3)
    #expect(try store.defaultBudgetSpace(baseCurrencyCode: "MXN").id == original.id)
    #expect(try store.load(spaceID: original.id) == state)
}
#endif
