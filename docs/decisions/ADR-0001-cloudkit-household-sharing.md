# ADR-0001: CloudKit household sharing without a TBB server

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

TBB must let people share selected household budgets while remaining FLOSS, private, and free from an app-operated financial-data backend.

## Decision

Use CloudKit private databases and invite-only `CKShare` sharing for a complete household budget object graph. Persist private and shared objects in separate Core Data stores backed by one `NSPersistentCloudKitContainer`.

The owner invites participants through Apple’s system sharing UI. Participants require an active iCloud account. TBB uses no public CloudKit database for financial data and creates no TBB identity or account.

## Consequences

- Sharing is Apple-ecosystem-only in v1.
- A household budget must be modeled as a self-contained graph; cross-share references are prohibited.
- The owner controls participant access. Participants use their own local app locks.
- TBB has no server operation or financial-data hosting cost; shared data consumes the originating owner’s iCloud quota.
- Future non-iCloud providers implement repository/sync contracts, not replacements to the domain model.

## Alternatives rejected

- Central TBB service: creates cost, operational burden, identity/security scope, and vendor dependence.
- Export/import collaboration: weak conflict handling and poor household experience.
- SwiftData-only managed sync: insufficiently explicit for the private/shared-store sharing model.
