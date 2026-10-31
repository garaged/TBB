# TBB-CUR-001 — Currency and exchange-rate integrity

## Intent

Make money values accurate, comprehensible, and portable across currencies without requiring a market-data service.

## Rules

- Every monetary amount is an integer count of the currency’s minor unit together with an ISO 4217 currency code. Binary floating point is forbidden.
- Every private or household `BudgetSpace` has one base/reporting currency selected at creation. Changing it later is a guided migration, never a display preference.
- A transaction may use a currency different from its budget space base currency.
- For a cross-currency transaction, TBB persists the original amount/currency and the applied exchange rate, rate scale, source label, and effective date. Historical reports never silently recalculate old values using a newer rate.
- v1 supports user-entered rates and an explicit same-day default rate. Live exchange-rate providers are deferred; their later addition must be optional, documented, and never required for core budgeting.
- Currency formatting follows the user’s locale for presentation but never changes the stored currency code, integer amount, or rate.
- Household budgets use their own base currency; every participant sees the same financial conversion result, localized only in presentation.

## Acceptance criteria

- Given USD 12.34, when stored and restored, then its value is exactly 1234 minor units and USD.
- Given a MXN-base budget and a USD expense with a chosen rate, when a later rate changes, then the original report remains unchanged.
- Given a user changes device language or region, when viewing the same record, then its numeric value and ISO currency remain unchanged while formatting adapts safely.
- Given a transfer between accounts in different currencies, when recorded, then both original amounts and the effective rate are retained as one balanced transfer.
- Given an unsupported/obsolete code or invalid rate, when importing or entering it, then TBB rejects it with a clear recoverable error.
