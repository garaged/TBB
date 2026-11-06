# M2 Manual Acceptance — Ledger

Run this after completing M1 device acceptance. M2 stores only local test data; do not use production financial data yet.

## Required preflight

Confirm you are testing the PR branch, not `main` or a stale local copy:

```bash
git fetch origin
git switch feature/m2-ledger
git pull --ff-only origin feature/m2-ledger
git rev-parse --short HEAD
git rev-parse HEAD
```

Copy the full SHA into PR #3 and verify it exactly matches the PR head SHA before building. See [Manual Acceptance Protocol](README.md) for the permanent rule.

## Setup

```bash
brew install xcodegen
xcodegen generate
open TBB.xcodeproj
```

Set a development team, run TBB on an iPhone and iPad, and complete the same flow on both devices.

## Acceptance

1. On a clean install, verify the Overview explains that an account is needed and exposes **Add account**.
2. Add a checking account with a nonzero opening balance. Relaunch the app and verify the account and exact balance remain.
3. Add a cash or savings account. Verify account names, icons, and balances remain readable at larger Dynamic Type sizes.
4. Record an expense using the General expense category. Verify the source account and overview total decrease by exactly that amount.
5. Record income using the Income category. Verify the source account and overview total increase by exactly that amount.
6. Record a transfer between two different accounts. Verify the source decreases, destination increases by the same amount, and the overall total is unchanged.
7. Try to save a zero or malformed amount. Verify the action remains disabled.
8. Try a self-transfer. Verify TBB shows a recoverable error and adds no transaction.
9. Enable Privacy Mode. Verify the overview total, account balances, and recent transaction amounts are all masked; category and note remain readable.
10. Background and relaunch the app with a local password enabled. Verify lock behavior does not discard entered ledger data.
11. With VoiceOver enabled, verify account, transaction, add-account, record-transaction, and privacy controls have understandable announcements.

Record branch, full SHA, device model, iOS/iPadOS version, and PASS/FAIL results in PR #3 before merge.
