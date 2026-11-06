# M3 Manual Acceptance — Dashboards

## Required preflight

```bash
git fetch origin
git switch feature/m3-dashboards
git pull --ff-only origin feature/m3-dashboards
git rev-parse --short HEAD
git rev-parse HEAD
```

Record the full SHA and verify it matches PR #4 before testing. See [Manual Acceptance Protocol](README.md).

## Setup

```bash
brew install xcodegen
bash scripts/generate-app-icon.sh
xcodegen generate
open TBB.xcodeproj
```

Use the M2 ledger loop to create at least one income, one expense, and one transfer in the current month before evaluating the dashboard.

## Acceptance

1. Open **Dashboard**. Verify income, spending, and net cash flow match the transactions created in Overview.
2. Verify the transfer changes account balances but does not change income, spending, or net cash flow.
3. Move to the previous period. Verify all dashboard cards change together and exclude current-period transactions.
4. Move forward. Verify the original current-period results return exactly.
5. Switch Month, Week, Quarter, and Year. Verify the title and every card change as one range.
6. Verify spending by category totals only expense transactions in the active period.
7. Turn on Privacy Mode in Overview, switch to Dashboard, and verify every money value is masked while labels and period navigation remain usable.
8. On iPad, verify the period picker and previous/next controls remain visible in portrait and landscape.
9. With VoiceOver, verify previous/next buttons and period picker have understandable labels.
10. Confirm the new TBB app icon appears in the Xcode target and on the installed app.

Record branch, full SHA, device model, OS version, and PASS/FAIL results in PR #4 before merge.
