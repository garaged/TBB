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
3. Select **Week**, **Month**, **Quarter**, and **Year**. Verify the title explains the full selected interval and changes immediately with the picker.
4. Tap **Previous**. Verify the displayed interval and every dashboard card move to the adjacent period and exclude current-period transactions.
5. Tap **Next**. Verify the original current-period title and results return exactly.
6. Record an expense dated in the previous month with a distinct note and time. Verify it appears in Overview with that date/time, does not alter the current month, and appears after Dashboard moves to the previous month.
7. Tap a transaction in **Recent activity**. Edit its amount, category/account (or transfer destination), date/time, and note. Verify its revised details appear in Overview and the affected account balances and Dashboard periods recalculate correctly.
8. With Privacy Mode enabled, open an existing transaction. Verify its amount is masked in the edit form. Reveal amounts and verify editing remains possible.
9. Use the transaction’s swipe action or context menu to choose **Delete**, cancel once, then confirm deletion. Verify cancellation changes nothing and confirmation removes the transaction and recalculates affected balances and dashboard periods.
10. Verify spending by category totals only expense transactions in the active period.
11. Use the eye button on **Dashboard**, then verify every money value there is masked while labels and period navigation remain usable. Use the lock button and verify Security opens.
12. On iPad, verify the period picker, explicit Previous/Next controls, and privacy/lock controls remain visible in portrait and landscape.
13. With VoiceOver, verify transaction editing, deletion, previous/next buttons, period picker, date/time picker, eye button, and lock button have understandable labels.
14. Confirm the new TBB app icon appears in the Xcode target and on the installed app.

Record branch, full SHA, device model, OS version, and PASS/FAIL results in PR #4 before merge.
