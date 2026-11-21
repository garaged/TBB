#if canImport(CoreData)
import CoreData
import Testing
@testable import TBBFoundation

@Test func cloudKitBackedAttributesAreOptional() {
    let model = CoreDataLedgerStore.makeModel()

    for entityName in ["BudgetSpace", "BudgetMutation"] {
        let attributes = model.entitiesByName[entityName]?.attributesByName ?? [:]
        #expect(!attributes.isEmpty)

        for attribute in attributes.values {
            #expect(attribute.isOptional)
        }
    }
}
#endif
