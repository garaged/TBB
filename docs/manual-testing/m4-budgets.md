# M4 Manual Acceptance — Budgets

## Required preflight

    git fetch origin
    git switch feature/m4-budgets
    git pull --ff-only origin feature/m4-budgets
    git rev-parse --short HEAD
    git rev-parse HEAD

Record the full SHA and verify it matches the M4 pull request before testing. See Manual Acceptance Protocol.

## Setup

    brew install xcodegen
    bash scripts/generate-app-icon.sh
    xcodegen generate
    open TBB.xcodeproj

Prepare one expense category and account. Use two consecutive months to validate rollover.

## Acceptance

1. Open Budgets on iPhone and iPad. Verify the eye and Security controls remain available.
2. Add a monthly budget to an expense category. Verify the amount, category, and active period display correctly.
3. Attempt a second monthly budget for that category. Verify TBB rejects it without changing the original budget.
4. Record an expense for less than the budget. Verify Remaining decreases and the status remains on track.
5. Record or edit expenses until the budget reaches 80 percent. Verify the in-app status becomes nearly spent. If notification permission is granted, verify the local notification contains no amount.
6. Record or edit expenses beyond the available amount. Verify the status becomes exceeded and any local notification contains no amount.
7. Move to the next budget period. Verify the full positive or negative balance carries into the new period.
8. Edit a budget’s category, cadence, planned amount, and start date. Verify the budget updates and the related projection recalculates.
9. Delete a budget, cancel once, then confirm. Verify cancellation preserves the plan; confirmation removes only the plan and leaves ledger transactions intact.
10. Enable Privacy Mode. Verify all displayed and existing-editor budget amounts are masked while controls remain usable.
11. With VoiceOver, verify budget cadence, previous/next period, status, add/edit/delete, and notification-permission-related controls have understandable labels.

Record branch, full SHA, device model, OS version, permission decision, and PASS/FAIL results in the PR before merge.
