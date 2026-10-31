# TBB Engineering Rules

1. Inspect the relevant intent, architecture, ADRs, and specifications before changing code.
2. Use the sequence: intent → decision → specification → test design → implementation → verification → evidence.
3. Keep TBB a local-first, single-product modular monolith. Do not introduce a TBB-operated backend without an approved ADR.
4. Financial calculations are deterministic domain services; views never become the source of financial truth.
5. Preserve private/shared household boundaries, privacy masking, and recovery guarantees. Treat regressions here as security defects.
6. Every milestone updates specifications, traceability, tests, user documentation, and manual acceptance evidence.
7. One focused branch and PR per milestone by default. Do not merge without explicit user approval.
8. No telemetry, ads, trackers, or monetization gates. Voluntary support links must remain optional and non-disruptive.
9. Run the repository quality commands before requesting review. Do not weaken a gate to make it pass.
