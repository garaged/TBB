# TBB Product Intent

## Mission

Give individuals and households a calm, quick, and trustworthy way to understand and direct their money across Apple devices, without turning financial data into a service-provider asset.

## Primary user loop

1. Open TBB and immediately see a privacy-safe summary.
2. Record an income, expense, or transfer in seconds.
3. See the selected budget period update deterministically.
4. Adjust a budget or inspect a category when needed.
5. Continue offline; sync recovers when iCloud becomes available.

## Product invariants

- Monetary values use integer minor units plus ISO currency code; binary floating point is forbidden for accounting values.
- Privacy Mode masks every money amount in application-controlled UI, including charts, widgets, screenshots where supported, and watch surfaces.
- An individual owns private budgets. A household budget is visible only to explicitly invited iCloud participants.
- TBB never operates a financial-data service, creates TBB accounts, serves ads, or collects analytics.
- Backup export is versioned, validates before restore, and can be encrypted with a user-selected backup password.
- Local password/biometric lock is a local-device boundary. It is not a substitute for access control to a CloudKit household share.

## Non-goals for v1

- Banking aggregation, card payments, investment advice, credit decisions, tax filing, web/Android clients, or a TBB cloud account.
- Public, link-open household budgets.
- Paid features or sponsorship-driven behavior.

## Accessibility and localization

VoiceOver, Dynamic Type, sufficient contrast, reduced motion, keyboard support on iPad, and robust English/Spanish localization are acceptance requirements—not polish deferred to release.
