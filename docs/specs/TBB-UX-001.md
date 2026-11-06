# TBB-UX-001 — Dashboard time navigation

## Intent

Let a person move confidently through financial time ranges without creating conflicting date filters across dashboard cards.

## Acceptance criteria

- Given a dashboard period of week, month, quarter, or year, when a person moves previous or next, then every card uses the same adjacent calendar interval.
- Given a selected period, when the person changes its granularity, then the new range remains anchored to the same point in time.
- Given a dashboard range, when income and expense totals are calculated, then only transactions inside its half-open range are included.
- Given transfers inside a dashboard range, when cash flow cards are calculated, then transfers do not appear as income or expenses.
- Given Privacy Mode is on, when dashboard totals or chart values render, then all money amounts are masked while labels and navigation remain usable.
- Given a configured budget-space time zone, when a range is calculated, then it uses that time zone and does not silently shift with the viewing device.
- Given any selected range, when it is rendered, then its title identifies the full week, month, quarter, or year represented and changes with period navigation.
- Given a person opens Dashboard, when they need to conceal amounts or adjust local protection, then the always-available Privacy Mode and Security controls are available there as on Overview.

## M3 scope boundary

M3 provides summary cards and reusable time navigation. Configurable card layout, custom ranges, budgets, and forecasts follow in later milestones.
