# TBB-BUD-001 — Recurring category budgets and alerts

## Intent

Let a person plan category spending, understand what remains in each period, and receive private, local reminders before an avoidable overrun.

## Acceptance criteria

- Given an expense category, when a person creates a budget with a positive minor-unit amount and cadence, then the plan recurs automatically for each week, month, quarter, or year.
- Given a category already has a budget for a cadence, when another is created for the same category and cadence, then TBB rejects it without mutating the existing plan.
- Given a budget period ends, when the next period starts, then the full remaining balance—including a deficit—carries into the next period.
- Given expenses are recorded, edited, or deleted, when a budget projection is read, then its spent, remaining, and alert state are recomputed deterministically from the ledger.
- Given a person edits a budget, when valid details are saved, then the budget identity is retained; when validation fails, the previous budget remains unchanged.
- Given a person confirms budget deletion, when the plan is removed, then recorded transactions remain unchanged.
- Given spending reaches 80 percent of the available budget, when local notification permission is granted, then TBB may send an amount-free local warning; at or beyond the available amount, it may send an amount-free exceeded notification.
- Given notification permission is not granted, when a threshold is crossed, then the in-app alert state remains available and TBB does not degrade budgeting behavior.
- Given Privacy Mode is concealed, when a budget list or existing budget editor renders, then monetary values are masked.
- Given an M2 or M3 ledger snapshot without budgets, when M4 loads it, then it decodes as an empty budget collection.

## Design constraints

Budgets are immutable-ledger projections: they never alter or manufacture transactions. Plans and their rollover policy are stored in the canonical versioned ledger snapshot. Notifications are device-local, contain no money amounts, use no server, and are deduplicated by plan, period, and alert state.

## M4 scope boundary

M4 supports one recurring plan per expense category and cadence, with the approved carry-full-balance rollover policy. Shared household budget notifications, advanced rules, income allocation, and forecasts follow later milestones.
