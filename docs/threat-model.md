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
| Data corruption or failed restore | Signed/versioned envelope, preflight validation, transactional restore, retained recovery diagnostics | fixture/property/restore tests |
| Backup disclosure | Optional password-based authenticated encryption; keys never persisted in the export | crypto vectors + wrong-password tests |
| Conflict/offline edits | Stable IDs, idempotent mutations, persistent history, deterministic conflict policy | offline/sync fixtures |
| Sensitive leakage through logs | Redacted structured diagnostics; no transaction descriptions/amounts in production logs | log-policy tests |

## Explicit limitations

Privacy Mode cannot control system-level screenshots taken before the app masks its own content, nor prevent a person with physical access to an already-unlocked device from viewing it. CloudKit share participants authorized by an owner can read shared financial records; local app passwords do not revoke CloudKit authorization.
