# Testing and Verification Strategy

## Automated layers

1. **Specification:** registry links, required headings, traceability IDs.
2. **Domain:** unit and property tests for money, ledger invariants, period navigation, and budget projections.
3. **Persistence/sync:** schema migration, private/shared store isolation, offline replay, idempotence, and conflict fixtures.
4. **Security:** Keychain access rules, lock lifecycle, backup cryptography vectors, redacted diagnostics.
5. **UI/accessibility:** VoiceOver labels, Dynamic Type, privacy masking, iPhone snapshots, iPad layouts, Watch flows.
6. **Performance:** operation-count and bounded-cache budgets, not flaky wall-clock simulator claims.
7. **Recovery:** export/import fixtures across supported format versions; malformed and wrong-password cases.

## Required manual gates

- iPhone physical-device lock/unlock and Privacy Mode.
- iPad layout/keyboard/Dynamic Type.
- Watch quick-capture and masked glance behavior.
- Two Apple Accounts sharing/accepting/revoking a household budget.
- Offline edit then reconciliation.
- Backup export, restore preview, successful restore, wrong-password rejection, and corrupted-file rejection.

## Localization matrix

Test `en`, `en-US`, `es-MX`, `es-419`, and an unsupported locale fallback. No fatal localization assertions.
