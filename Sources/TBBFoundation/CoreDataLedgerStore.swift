#if canImport(CoreData)
@preconcurrency import CoreData
#if canImport(CloudKit)
import CloudKit
#endif
import Foundation

public enum LedgerPersistenceError: Error, Equatable, Sendable {
    case unreadableSnapshot
    case unknownBudgetSpace
    case sharingUnavailable
}

public struct StoredBudgetSpace: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let scope: BudgetSpaceScope
    public let role: BudgetSpaceRole

    public init(id: UUID, name: String, scope: BudgetSpaceScope, role: BudgetSpaceRole) {
        self.id = id
        self.name = name
        self.scope = scope
        self.role = role
    }
}

#if canImport(CloudKit)
public struct CloudKitShareSession {
    public let share: CKShare
    public let container: CKContainer

    public init(share: CKShare, container: CKContainer) {
        self.share = share
        self.container = container
    }
}
#endif

@MainActor
public final class CoreDataLedgerStore {
    private let container: NSPersistentContainer
    private let legacyStore: NSPersistentStore?
    private let privateStore: NSPersistentStore?
    #if canImport(CloudKit)
    private let sharedStore: NSPersistentStore?
    #endif

    private let legacySnapshotKey = "primary-ledger"
    private let defaultSpaceName = "Personal"

    public init(inMemory: Bool = false) throws {
        let model = Self.makeModel()
        let cloud = !inMemory ? Self.makeCloudContainer(model: model) : nil

        do {
            if let cloud {
                try Self.load(cloud)
                container = cloud
            } else {
                let local = Self.makeLocalContainer(model: model, inMemory: inMemory)
                try Self.load(local)
                container = local
            }
        } catch {
            let local = Self.makeLocalContainer(model: model, inMemory: inMemory)
            try Self.load(local)
            container = local
        }

        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true

        let stores = container.persistentStoreCoordinator.persistentStores
        legacyStore = stores.first(where: { $0.configurationName == "Legacy" })
        privateStore = stores.first(where: { $0.configurationName == "CloudPrivate" })
        #if canImport(CloudKit)
        sharedStore = stores.first(where: { $0.configurationName == "CloudShared" })
        #endif
    }

    public func load(baseCurrencyCode: String) throws -> LedgerState {
        let space = try defaultSpace(baseCurrencyCode: baseCurrencyCode)
        return try load(spaceID: requiredSpaceID(space))
    }

    public func load(spaceID: UUID) throws -> LedgerState {
        let space = try managedSpace(id: spaceID)
        return try projection(for: space).state
    }

    public func budgetSpaces(baseCurrencyCode: String) throws -> [StoredBudgetSpace] {
        _ = try defaultSpace(baseCurrencyCode: baseCurrencyCode)
        let request = NSFetchRequest<NSManagedObject>(entityName: "BudgetSpace")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let spaces = try container.viewContext.fetch(request)
        return spaces.compactMap(storedSpace)
    }

    public func defaultBudgetSpace(baseCurrencyCode: String) throws -> StoredBudgetSpace {
        storedSpace(try defaultSpace(baseCurrencyCode: baseCurrencyCode))!
    }

    public func save(_ state: LedgerState) throws {
        let space = try defaultSpace(baseCurrencyCode: state.baseCurrencyCode)
        try save(state, in: try requiredSpaceID(space))
    }

    public func save(_ state: LedgerState, in spaceID: UUID) throws {
        let space = try managedSpace(id: spaceID)
        let current = try projection(for: space).state
        let timestamp = Int64(Date.now.timeIntervalSince1970 * 1_000)
        let origin = Self.originDeviceID()
        var sequence = Int64(space.value(forKey: "logicalClock") as? Int64 ?? 0)

        for payload in mutations(from: current, to: state) {
            sequence += 1
            let mutation = NSEntityDescription.insertNewObject(forEntityName: "BudgetMutation", into: container.viewContext)
            mutation.setValue(UUID(), forKey: "mutationID")
            mutation.setValue(timestamp + sequence, forKey: "logicalTimestamp")
            mutation.setValue(origin, forKey: "originDeviceID")
            mutation.setValue(try JSONEncoder().encode(payload), forKey: "payload")
            mutation.setValue(Date.now, forKey: "createdAt")
            mutation.setValue(space, forKey: "space")
        }

        space.setValue(sequence, forKey: "logicalClock")
        try container.viewContext.save()
    }

    #if canImport(CloudKit)
    public func createOrFetchShare(for spaceID: UUID) async throws -> CloudKitShareSession {
        guard let cloud = container as? NSPersistentCloudKitContainer,
              privateStore != nil else {
            throw LedgerPersistenceError.sharingUnavailable
        }

        let space = try managedSpace(id: spaceID)
        let existing = try cloud.fetchShares(matching: [space.objectID])[space.objectID]

        return try await withCheckedThrowingContinuation { continuation in
            cloud.share([space], to: existing) { _, share, cloudKitContainer, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let share, let cloudKitContainer else {
                    continuation.resume(throwing: LedgerPersistenceError.sharingUnavailable)
                    return
                }
                space.setValue(BudgetSpaceScope.shared.rawValue, forKey: "scope")
                do {
                    try self.container.viewContext.save()
                    continuation.resume(returning: .init(share: share, container: cloudKitContainer))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func accept(_ metadata: CKShare.Metadata) {
        guard let cloud = container as? NSPersistentCloudKitContainer,
              let sharedStore else { return }

        cloud.acceptShareInvitations(from: [metadata], into: sharedStore) { _, _ in }
    }
    #endif

    private func defaultSpace(baseCurrencyCode: String) throws -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: "BudgetSpace")
        request.fetchLimit = 1
        request.affectedStores = privateStore.map { [$0] }

        if let existing = try container.viewContext.fetch(request).first {
            return existing
        }

        let initialState = try migratedLegacyState(baseCurrencyCode: baseCurrencyCode)
        let space = NSEntityDescription.insertNewObject(forEntityName: "BudgetSpace", into: container.viewContext)
        space.setValue(UUID(), forKey: "spaceID")
        space.setValue(defaultSpaceName, forKey: "name")
        space.setValue(BudgetSpaceScope.privateSpace.rawValue, forKey: "scope")
        space.setValue(try JSONEncoder().encode(initialState), forKey: "initialState")
        space.setValue(Int64(0), forKey: "logicalClock")
        space.setValue(Date.now, forKey: "createdAt")
        try container.viewContext.save()
        return space
    }

    private func migratedLegacyState(baseCurrencyCode: String) throws -> LedgerState {
        guard let legacyStore else { return try LedgerState(baseCurrencyCode: baseCurrencyCode) }

        let request = NSFetchRequest<NSManagedObject>(entityName: "LedgerSnapshot")
        request.predicate = NSPredicate(format: "key == %@", legacySnapshotKey)
        request.fetchLimit = 1
        request.affectedStores = [legacyStore]

        guard let object = try container.viewContext.fetch(request).first else {
            return try LedgerState(baseCurrencyCode: baseCurrencyCode)
        }
        guard let payload = object.value(forKey: "payload") as? Data,
              let state = try? JSONDecoder().decode(LedgerState.self, from: payload) else {
            throw LedgerPersistenceError.unreadableSnapshot
        }
        return state
    }

    private func managedSpace(id: UUID) throws -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: "BudgetSpace")
        request.predicate = NSPredicate(format: "spaceID == %@", id as CVarArg)
        request.fetchLimit = 1
        guard let space = try container.viewContext.fetch(request).first else {
            throw LedgerPersistenceError.unknownBudgetSpace
        }
        return space
    }

    private func projection(for space: NSManagedObject) throws -> BudgetSpaceProjection {
        guard let stateData = space.value(forKey: "initialState") as? Data,
              let initialState = try? JSONDecoder().decode(LedgerState.self, from: stateData) else {
            throw LedgerPersistenceError.unreadableSnapshot
        }
        guard let spaceID = space.value(forKey: "spaceID") as? UUID else {
            throw LedgerPersistenceError.unknownBudgetSpace
        }

        let mutationObjects = (space.value(forKey: "mutations") as? Set<NSManagedObject>) ?? []
        let mutations = mutationObjects.compactMap { object -> BudgetSpaceMutation? in
            guard let mutationID = object.value(forKey: "mutationID") as? UUID,
                  let logicalTimestamp = object.value(forKey: "logicalTimestamp") as? Int64,
                  let originDeviceID = object.value(forKey: "originDeviceID") as? UUID,
                  let payloadData = object.value(forKey: "payload") as? Data,
                  let payload = try? JSONDecoder().decode(BudgetSpaceMutationPayload.self, from: payloadData) else {
                return nil
            }
            return .init(
                id: mutationID,
                spaceID: spaceID,
                logicalTimestamp: logicalTimestamp,
                originDeviceID: originDeviceID,
                payload: payload
            )
        }

        let stored = storedSpace(space)
        guard let stored else { throw LedgerPersistenceError.unknownBudgetSpace }
        return BudgetSpaceProjector.rebuild(
            space: .init(id: stored.id, name: stored.name, scope: stored.scope, role: stored.role),
            baseState: initialState,
            mutations: mutations
        )
    }

    private func storedSpace(_ space: NSManagedObject) -> StoredBudgetSpace? {
        guard let id = space.value(forKey: "spaceID") as? UUID,
              let name = space.value(forKey: "name") as? String,
              let rawScope = space.value(forKey: "scope") as? String,
              let scope = BudgetSpaceScope(rawValue: rawScope) else { return nil }

        let role: BudgetSpaceRole
        #if canImport(CloudKit)
        role = space.objectID.persistentStore == sharedStore ? .participant : .owner
        #else
        role = .owner
        #endif
        return .init(id: id, name: name, scope: scope, role: role)
    }

    private func requiredSpaceID(_ space: NSManagedObject) throws -> UUID {
        guard let id = space.value(forKey: "spaceID") as? UUID else {
            throw LedgerPersistenceError.unknownBudgetSpace
        }
        return id
    }

    private func mutations(from old: LedgerState, to new: LedgerState) -> [BudgetSpaceMutationPayload] {
        var result: [BudgetSpaceMutationPayload] = []

        appendUpserts(old.accounts, new.accounts, payload: BudgetSpaceMutationPayload.upsertAccount, to: &result)
        appendUpserts(old.categories, new.categories, payload: BudgetSpaceMutationPayload.upsertCategory, to: &result)
        appendUpserts(old.transactions, new.transactions, payload: BudgetSpaceMutationPayload.upsertTransaction, to: &result)
        appendUpserts(old.budgets, new.budgets, payload: BudgetSpaceMutationPayload.upsertBudget, to: &result)

        for transaction in old.transactions where !new.transactions.contains(where: { $0.id == transaction.id }) {
            result.append(.deleteTransaction(transaction.id))
        }
        for budget in old.budgets where !new.budgets.contains(where: { $0.id == budget.id }) {
            result.append(.deleteBudget(budget.id))
        }
        return result
    }

    private func appendUpserts<T: Identifiable & Equatable>(
        _ old: [T],
        _ new: [T],
        payload: (T) -> BudgetSpaceMutationPayload,
        to result: inout [BudgetSpaceMutationPayload]
    ) where T.ID == UUID {
        for value in new where old.first(where: { $0.id == value.id }) != value {
            result.append(payload(value))
        }
    }

    private static func originDeviceID() -> UUID {
        let key = "TBB.household.origin-device-id"
        if let raw = UserDefaults.standard.string(forKey: key), let id = UUID(uuidString: raw) {
            return id
        }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: key)
        return id
    }

    private static func load(_ container: NSPersistentContainer) throws {
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
    }

    private static func makeCloudContainer(model: NSManagedObjectModel) -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: "TBBLedger", managedObjectModel: model)
        let legacy = description(
            url: persistentURL(named: "TBBLedger.sqlite"),
            configuration: "Legacy",
            options: nil
        )
        let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: CloudKitConfiguration.containerIdentifier)
        privateOptions.databaseScope = .private
        let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: CloudKitConfiguration.containerIdentifier)
        sharedOptions.databaseScope = .shared
        let privateStore = description(
            url: persistentURL(named: "TBBHousehold-private.sqlite"),
            configuration: "CloudPrivate",
            options: privateOptions
        )
        let sharedStore = description(
            url: persistentURL(named: "TBBHousehold-shared.sqlite"),
            configuration: "CloudShared",
            options: sharedOptions
        )
        container.persistentStoreDescriptions = [legacy, privateStore, sharedStore]
        return container
    }

    private static func makeLocalContainer(model: NSManagedObjectModel, inMemory: Bool) -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "TBBLedger", managedObjectModel: model)
        let legacy = description(
            url: inMemory ? transientURL(named: "TBBLedger.sqlite") : persistentURL(named: "TBBLedger.sqlite"),
            configuration: "Legacy",
            options: nil,
            inMemory: inMemory
        )
        let privateStore = description(
            url: inMemory ? transientURL(named: "TBBHousehold-private.sqlite") : persistentURL(named: "TBBHousehold-private.sqlite"),
            configuration: "CloudPrivate",
            options: nil,
            inMemory: inMemory
        )
        container.persistentStoreDescriptions = [legacy, privateStore]
        return container
    }

    private static func description(
        url: URL?,
        configuration: String,
        options: NSPersistentCloudKitContainerOptions?,
        inMemory: Bool = false
    ) -> NSPersistentStoreDescription {
        let description = NSPersistentStoreDescription()
        description.configuration = configuration
        if inMemory { description.type = NSInMemoryStoreType }
        description.url = url
        description.cloudKitContainerOptions = options
        return description
    }

    private static func persistentURL(named name: String) -> URL {
        NSPersistentContainer.defaultDirectoryURL().appendingPathComponent(name)
    }

    private static func transientURL(named name: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString)-\(name)")
    }

    private static func makeModel() -> NSManagedObjectModel {
        let key = attribute(name: "key", type: .stringAttributeType)
        let payload = attribute(name: "payload", type: .binaryDataAttributeType)
        payload.allowsExternalBinaryDataStorage = true
        let updatedAt = attribute(name: "updatedAt", type: .dateAttributeType)

        let legacy = NSEntityDescription()
        legacy.name = "LedgerSnapshot"
        legacy.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        legacy.properties = [key, payload, updatedAt]
        legacy.uniquenessConstraints = [["key"]]

        let spaceID = attribute(name: "spaceID", type: .UUIDAttributeType)
        let name = attribute(name: "name", type: .stringAttributeType)
        let scope = attribute(name: "scope", type: .stringAttributeType)
        let initialState = attribute(name: "initialState", type: .binaryDataAttributeType)
        initialState.allowsExternalBinaryDataStorage = true
        let logicalClock = attribute(name: "logicalClock", type: .integer64AttributeType)
        let createdAt = attribute(name: "createdAt", type: .dateAttributeType)

        let space = NSEntityDescription()
        space.name = "BudgetSpace"
        space.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        space.properties = [spaceID, name, scope, initialState, logicalClock, createdAt]

        let mutationID = attribute(name: "mutationID", type: .UUIDAttributeType)
        let logicalTimestamp = attribute(name: "logicalTimestamp", type: .integer64AttributeType)
        let originDeviceID = attribute(name: "originDeviceID", type: .UUIDAttributeType)
        let mutationPayload = attribute(name: "payload", type: .binaryDataAttributeType)
        mutationPayload.allowsExternalBinaryDataStorage = true
        let mutationCreatedAt = attribute(name: "createdAt", type: .dateAttributeType)

        let mutation = NSEntityDescription()
        mutation.name = "BudgetMutation"
        mutation.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        mutation.properties = [mutationID, logicalTimestamp, originDeviceID, mutationPayload, mutationCreatedAt]

        let mutations = NSRelationshipDescription()
        mutations.name = "mutations"
        mutations.destinationEntity = mutation
        mutations.minCount = 0
        mutations.maxCount = 0
        mutations.deleteRule = .cascadeDeleteRule
        mutations.isOptional = true

        let owner = NSRelationshipDescription()
        owner.name = "space"
        owner.destinationEntity = space
        owner.minCount = 0
        owner.maxCount = 1
        owner.deleteRule = .nullifyDeleteRule
        owner.isOptional = true

        mutations.inverseRelationship = owner
        owner.inverseRelationship = mutations
        space.properties.append(mutations)
        mutation.properties.append(owner)

        let model = NSManagedObjectModel()
        model.entities = [legacy, space, mutation]
        model.setEntities([legacy], forConfigurationName: "Legacy")
        model.setEntities([space, mutation], forConfigurationName: "CloudPrivate")
        model.setEntities([space, mutation], forConfigurationName: "CloudShared")
        return model
    }

    private static func attribute(name: String, type: NSAttributeType) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = false
        return attribute
    }
}
#endif
