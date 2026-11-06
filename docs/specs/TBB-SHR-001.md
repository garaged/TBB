# TBB-SHR-001 — Household budget sharing

## Intent

Allow an owner to privately share selected household budget spaces with invited iCloud users without a TBB-operated server, account, or public financial-data database.

## Acceptance criteria

- Given a private budget space, when its owner chooses Share, then TBB creates or updates an invite-only CloudKit share for that space only.
- Given an invited participant accepts on a supported Apple device, when CloudKit finishes importing, then that shared space appears alongside—not merged with—their private spaces.
- Given a write-enabled participant records, edits, or deletes data while offline, when connectivity returns, then each mutation is synchronized at most once and replaying it does not change the projection.
- Given concurrent mutations affect the same record, when clients rebuild their projection, then all clients choose the same result using the documented deterministic ordering and retain redacted conflict evidence in the audit projection.
- Given an owner removes a participant or stops sharing, when the CloudKit change arrives, then the participant loses that shared-space view while all unrelated spaces remain intact.
- Given Privacy Mode is concealed, when a shared space renders, then monetary amounts are masked locally without modifying CloudKit records or other participants’ views.
- Given a user has no active iCloud account, is offline, or CloudKit is unavailable, when they attempt sharing, then TBB explains the condition, keeps private budgeting usable, and provides a retry without creating a TBB account.
- Given a build lacks a configured CloudKit entitlement, when sharing is opened, then the app identifies the missing setup and does not claim that data is shared.

## Data and conflict rules

- A `BudgetSpace` has a stable UUID, display name, owner/participant role, and private/shared scope. Accounts, categories, transactions, budget plans, and audit entries belong to exactly one space. Cross-space references are rejected.
- Shared persistence is an append-only mutation log plus a derived ledger projection. Each mutation has a stable UUID, space ID, operation payload, origin device ID, and logical timestamp. Mutation UUID makes the log idempotent.
- Rebuild order is `(logicalTimestamp, mutationUUID)`. A later ordered mutation wins for the same field or record. Deletes are tombstones; earlier or duplicate updates cannot resurrect them. Audit entries preserve identifiers and redacted metadata, never transaction amounts or notes.
- CloudKit is an Apple service dependency, not a TBB central server. TBB uses private and shared databases only; it stores no financial records in a public database and creates no TBB identity.
- A local TBB password or Face ID protects only that device; it never grants or revokes CloudKit access.

## M5 scope boundary

M5 introduces space isolation, private/shared CloudKit stores, invite/accept/manage/revoke presentation, idempotent offline mutation replay, and a redacted audit projection. Multi-currency conversion, portable encrypted backups, Watch capture, and non-iCloud providers remain later milestones.
