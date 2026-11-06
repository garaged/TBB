#if canImport(CoreData)
@preconcurrency import CoreData
import Foundation

public enum LedgerPersistenceError: Error, Equatable, Sendable {
    case unreadableSnapshot
}

@MainActor
public final class CoreDataLedgerStore {
    private let container: NSPersistentContainer
    private let snapshotKey = "primary-ledger"

    public init(inMemory: Bool = false) throws {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "TBBLedger", managedObjectModel: model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError { throw loadError }
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    public func load(baseCurrencyCode: String) throws -> LedgerState {
        let request = NSFetchRequest<NSManagedObject>(entityName: "LedgerSnapshot")
        request.predicate = NSPredicate(format: "key == %@", snapshotKey)
        request.fetchLimit = 1

        guard let object = try container.viewContext.fetch(request).first else {
            return try LedgerState(baseCurrencyCode: baseCurrencyCode)
        }
        guard let payload = object.value(forKey: "payload") as? Data,
              let state = try? JSONDecoder().decode(LedgerState.self, from: payload) else {
            throw LedgerPersistenceError.unreadableSnapshot
        }
        return state
    }

    public func save(_ state: LedgerState) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "LedgerSnapshot")
        request.predicate = NSPredicate(format: "key == %@", snapshotKey)
        request.fetchLimit = 1
        let object = try container.viewContext.fetch(request).first
            ?? NSEntityDescription.insertNewObject(forEntityName: "LedgerSnapshot", into: container.viewContext)

        object.setValue(snapshotKey, forKey: "key")
        object.setValue(try JSONEncoder().encode(state), forKey: "payload")
        object.setValue(Date.now, forKey: "updatedAt")
        try container.viewContext.save()
    }

    private static func makeModel() -> NSManagedObjectModel {
        let key = NSAttributeDescription()
        key.name = "key"
        key.attributeType = .stringAttributeType
        key.isOptional = false

        let payload = NSAttributeDescription()
        payload.name = "payload"
        payload.attributeType = .binaryDataAttributeType
        payload.allowsExternalBinaryDataStorage = true
        payload.isOptional = false

        let updatedAt = NSAttributeDescription()
        updatedAt.name = "updatedAt"
        updatedAt.attributeType = .dateAttributeType
        updatedAt.isOptional = false

        let entity = NSEntityDescription()
        entity.name = "LedgerSnapshot"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        entity.properties = [key, payload, updatedAt]
        entity.uniquenessConstraints = [["key"]]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }
}
#endif
