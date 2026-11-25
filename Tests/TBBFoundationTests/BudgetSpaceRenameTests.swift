#if canImport(CoreData)
import Foundation
import Testing
@testable import TBBFoundation

@MainActor @Test func ownerCanRenameBudgetSpaceWithoutChangingItsLedger() throws {
    let store = try CoreDataLedgerStore(inMemory: true)
    let original = try store.defaultBudgetSpace(baseCurrencyCode: "MXN")
    let state = try store.load(spaceID: original.id)

    try store.renameBudgetSpace(id: original.id, to: "  Household  ")

    let renamed = try store.budgetSpaces(baseCurrencyCode: "MXN").first { $0.id == original.id }
    #expect(renamed?.name == "Household")
    #expect(try store.load(spaceID: original.id) == state)
}

@MainActor @Test func budgetRenameRejectsInvalidNames() throws {
    let store = try CoreDataLedgerStore(inMemory: true)
    let space = try store.defaultBudgetSpace(baseCurrencyCode: "MXN")

    #expect(throws: LedgerPersistenceError.invalidBudgetSpaceName) {
        try store.renameBudgetSpace(id: space.id, to: "  ")
    }
    #expect(throws: LedgerPersistenceError.invalidBudgetSpaceName) {
        try store.renameBudgetSpace(id: space.id, to: String(repeating: "x", count: 81))
    }
    #expect(try store.defaultBudgetSpace(baseCurrencyCode: "MXN").name == space.name)
}
@MainActor @Test func refreshingLocalViewPreservesRenamedSpaceAndLedger() throws {
    let store = try CoreDataLedgerStore(inMemory: true)
    let space = try store.defaultBudgetSpace(baseCurrencyCode: "MXN")
    let originalState = try store.load(spaceID: space.id)
    try store.renameBudgetSpace(id: space.id, to: "Family")

    try store.refreshLocalView()

    #expect(try store.defaultBudgetSpace(baseCurrencyCode: "MXN").name == "Family")
    #expect(try store.load(spaceID: space.id) == originalState)
}
#endif
