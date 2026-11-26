# Threat Model

## Assets

Financial records, balances, household membership, backup contents, local unlock material, and audit history.

## Boundaries and mitigations

| Threat | Mitigation | Verification |
|---|---|---|
| Casual shoulder surfing | Persistent Privacy Mode masks amounts and chart labels immediately | UI + screenshot tests |
| Lost/unattended device | Optional local password; Face ID/Touch ID unlock; automatic lock on configured lifecycle events | security integration tests |
| Biometric unavailability | Device passcode/local-password fallback; no biometric secret is exposed to the app | integration tests |
| Unauthorized household access | Invite-only CloudKit share; explicit participant roles; owner-managed removal | CloudKit/manual acceptance |
| Data corruption or failed restore | Versioned envelope, authenticated encryption when enabled, preflight validation, transactional restore, redacted recovery diagnostics | fixture/property/restore tests |
| Backup disclosure | Optional password-based authenticated encryption; keys never persisted in the export | crypto vectors + wrong-password tests |
| Conflict/offline edits | Stable IDs, idempotent mutations, persistent history, deterministic conflict policy | offline/sync fixtures |
| Sensitive leakage through logs | Redacted structured diagnostics; no transaction descriptions/amounts in production logs | log-policy tests |

## Explicit limitations

Privacy Mode cannot control system-level screenshots taken before the app masks its own content, nor prevent a person with physical access to an already-unlocked device from viewing it. CloudKit share participants authorized by an owner can read shared financial records; local app passwords do not revoke CloudKit authorization.

## Backup security review

An encrypted file exposes its version, protection mode, work factor, salt and approximate payload size. Wrong passwords and failed authentication share a redacted error. Fixed KDF parameters and byte limits are checked before password derivation. Plaintext exports require a second confirmation. Their digest detects accidental damage, and someone with the file can replace both the data and its digest.

The codec accepts a space name and ledger snapshot. It has no reference to the device credential store, CloudKit share, participant list or mutation audit log. The app supplies a generic default filename, holds passwords and preview data in memory and releases them on dismissal. The document provider controls the exported file and any provider-managed copies. Exporting a shared budget creates a copy outside the owner's revocation controls.

Review evidence includes independent v1 and v2 fixtures, header and ciphertext modification tests, absence of plaintext markers, and an injected persistence failure. Device acceptance covers the OS picker, background locking and recovery with a second account.
