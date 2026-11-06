# Architecture

TBB is an Apple-native, local-first modular monolith implemented in Swift. iPhone is the primary interaction surface; iPad expands analysis and planning; Watch supports focused capture and safe glanceability.

## Storage decision

TBB uses Core Data backed by NSPersistentCloudKitContainer, with separate private and shared stores. SwiftUI is the UI layer; domain services and repositories remain independent of it.

M2 persists a versioned canonical LedgerState snapshot through Core Data. M4 extends that same snapshot with budget plans; decoding an older snapshot defaults the missing collection to empty. This gives users durable local data now while retaining a clean migration boundary: M5 replaces the local snapshot adapter with the private/shared CloudKit store adapter without changing money, ledger, budget, or UI contracts.

Budget plans are deterministic projections over ledger transactions. They never manufacture transactions or change the ledger to represent a plan. Local notifications are a device-only presentation adapter: their identifiers and payloads contain no amounts, and they have no server or CloudKit dependency.

## Module rules

| Module | May depend on | Must not depend on |
|---|---|---|
| Domain | Foundation | SwiftUI, Core Data, CloudKit, platform UI |
| Application | Domain, contracts | concrete UI |
| Persistence | Domain contracts, Core Data/CloudKit | SwiftUI |
| Platform UI | Application, design system | persistence implementation |
| Security | contracts, Security/LocalAuthentication | feature views |
| Backup | Domain contracts, CryptoKit | UI implementations |

## Household-sharing boundary

A BudgetSpace is either private or shared. A shared space forms one CloudKit shareable object graph: accounts, transactions, categories, budget plans, rules, and audit entries belong to that space. Cross-space relationships are forbidden.

## Performance rules

- Use aggregate projections and bounded caches for dashboard cards; do not load the full ledger to render a card.
- Recompute only affected periods after mutation.
- Background work is cancellable and observable.
- Long-session memory, cold launch, and dashboard-render operation budgets are tested with deterministic fixtures.
