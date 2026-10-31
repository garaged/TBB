# Traceability

| Intent / invariant | ADR | Specification | Planned evidence |
|---|---|---|---|
| No TBB financial-data backend | ADR-0001 | TBB-SHR-001 | architecture + sharing acceptance |
| Private/shared budget isolation | ADR-0001 | TBB-SHR-001 | persistence isolation tests |
| Privacy masking is global/local | — | TBB-SEC-001 | UI/accessibility tests |
| Deterministic financial values | — | TBB-DAT-001, TBB-CUR-001 | property tests |
| Currency/rate history never changes silently | — | TBB-CUR-001 | multi-currency fixtures |
| Localization changes presentation, not meaning | — | TBB-I18N-001 | locale/time-zone/UI tests |
| Recoverable encrypted backups | — | TBB-BKP-001 | restore vectors |
| Quality before merge | — | TBB-FND-001 | CI + PR evidence |
