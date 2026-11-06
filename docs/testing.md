# Testing and Verification Strategy

## Automated layers

1. **Specification:** registry links, required headings, traceability IDs.
2. **Domain:** unit and property tests for currency-safe money, ledger invariants, period navigation, and budget projections.
3. **Persistence/sync:** schema migration, private/shared store isolation, offline replay, idempotence, currency/rate history, and conflict fixtures.
4. **Security:** Keychain access rules, lock lifecycle, backup cryptography vectors, redacted diagnostics.
5. **UI/accessibility:** VoiceOver labels, Dynamic Type, privacy masking, iPhone snapshots, iPad layouts, Watch flows.
6. **Performance:** operation-count and bounded-cache budgets, not flaky wall-clock simulator claims.
7. **Recovery:** export/import fixtures across supported format versions; malformed and wrong-password cases.

## Manual acceptance protocol

Every manual acceptance begins with the exact PR branch and commit preflight in `docs/manual-testing/README.md`. A manual PASS is valid only when its report records a branch and full SHA matching the PR head.

## Required manual gates

- iPhone physical-device lock/unlock and Privacy Mode.
- iPad layout/keyboard/Dynamic Type.
- M2 account creation, expense, income, transfer, persistence, error, and Privacy Mode loop: `docs/manual-testing/m2-ledger.md`.
- M3 period navigation, dashboard calculations, Privacy Mode, and iPad accessibility: `docs/manual-testing/m3-dashboards.md`.
- Watch quick-capture and masked glance behavior.
- Two Apple Accounts sharing/accepting/revoking a household budget.
- Offline edit then reconciliation.
- Backup export, restore preview, successful restore, wrong-password rejection, and corrupted-file rejection.
- Multi-currency transaction, historical-rate stability, English/Mexican-Spanish presentation, and budget-time-zone boundary checks.

## Localization matrix

Test `en`, `en-US`, `es-MX`, `es-419`, and an unsupported locale fallback. Validate long text, Dynamic Type, VoiceOver, reduced motion, high contrast, and no color-only meaning. No fatal localization assertions.
