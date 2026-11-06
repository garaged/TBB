#if canImport(CoreData)
import Foundation
import Testing
@testable import TBBFoundation

@Test @MainActor func coreDataLedgerStoreRoundTripsTheExactLedgerState() throws {
    let store = try CoreDataLedgerStore(inMemory: true)
    var state = try LedgerState(baseCurrencyCode: "MXN")
    let account = try LedgerAccount(name: "Wallet", kind: .cash, currencyCode: "MXN", openingBalanceMinorUnits: 500)
    let category = LedgerCategory(name: "Food", kind: .expense)
    try state.addAccount(account)
    try state.addCategory(category)
    try state.recordExpense(
        amount: Money(minorUnits: 125, currencyCode: "MXN"),
        accountID: account.id,
        categoryID: category.id,
        occurredAt: Date(timeIntervalSince1970: 1_000)
    )

    try store.save(state)
    let restored = try store.load(baseCurrencyCode: "USD")

    #expect(restored == state)
    #expect(try restored.balance(of: account.id).minorUnits == 375)
}
#endif
