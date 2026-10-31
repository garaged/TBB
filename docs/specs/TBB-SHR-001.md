# TBB-SHR-001 — Household budget sharing

## Intent

Allow an owner to privately share one household budget with invited iCloud users without a TBB-operated server.

## Acceptance criteria

- Given a private budget space, when the owner chooses Share, then TBB creates or updates an invite-only CloudKit share for that space only.
- Given an invited participant accepts on any supported Apple device, when sync completes, then the complete shared space appears without exposing owner-private spaces.
- Given a write-enabled participant records a transaction offline, when connectivity returns, then the mutation is synchronized exactly once according to the deterministic conflict policy.
- Given an owner removes a participant or stops sharing, when the CloudKit change arrives, then the participant loses the shared-space view while private spaces remain unaffected.
- Given a user enables Privacy Mode, when viewing a shared space, then TBB masks amounts locally without changing shared records.
- Given a user has no active iCloud account, when they attempt sharing, then TBB explains the requirement and leaves private budgeting functional.

## Data rules

Every shared object has one `budgetSpaceID`. References across spaces are rejected. Participant identity is represented only by privacy-minimizing CloudKit/audit metadata required for collaboration.
