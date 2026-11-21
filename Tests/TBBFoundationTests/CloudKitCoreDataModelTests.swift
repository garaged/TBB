#if canImport(CoreData)
import CoreData
import Testing
@testable import TBBFoundation

@Test func cloudKitBackedAttributesAreOptional() {
    let model = CoreDataLedgerStore.makeModel()

    for entityName in ["BudgetSpace", "BudgetMutation"] {
        let attributes = model.entitiesByName[entityName]?.attributesByName.values ?? []
        #expect(!attributes.isEmpty)

        for attribute in attributes {
            #expect(attribute.isOptional)
        }
    }
}
#endif
