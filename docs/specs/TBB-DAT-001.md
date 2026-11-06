# TBB-DAT-001 — Deterministic ledger and money model

## Intent

Record the financial facts a person enters with exact arithmetic, understandable rules, and no hidden conversion or recalculation.

## Acceptance criteria

- Given an account, when its opening balance and recorded transactions are unchanged, then TBB always derives the same balance from integer minor units.
- Given an expense, when it is recorded, then the selected account decreases by the positive entered amount and the category must be an expense category.
- Given income, when it is recorded, then the selected account increases by the positive entered amount and the category must be an income category.
- Given a same-currency transfer, when it is recorded, then the source decreases and destination increases by exactly the same minor-unit amount.
- Given an invalid currency, zero/negative amount, unknown account/category, wrong category kind, or self-transfer, when a mutation is requested, then no transaction is added and TBB returns a recoverable validation error.
- Given an account or transaction with a currency, when the device locale changes, then stored amount and ISO currency stay unchanged.
- Given a person chooses a date and time while recording a transaction, when it is saved, then the exact selected occurrence timestamp is retained and determines its dashboard period.
- Given a person edits a transaction, when valid replacement details are saved, then its stable identity is retained and balances and dashboard periods derive only from the replacement.
- Given a transaction edit is invalid, when validation fails, then the original transaction and all derived balances remain unchanged.
- Given a person deletes a transaction and confirms the destructive action, then it is removed and affected balances and dashboard periods are recalculated.

## M2 scope boundary

M2 supports exact single-currency account operations. Multi-currency account transfers and historical exchange-rate application are specified by TBB-CUR-001 and are introduced only with their full conversion/audit model.
