# TBB-SEC-001 — Local lock and Privacy Mode

## Intent

Let a person immediately hide financial amounts in public and protect access on an unattended device without exposing or transmitting a password.

## Acceptance criteria

- Given any TBB screen that renders an amount, when Privacy Mode is concealed, then the amount is replaced by a consistent non-numeric mask and an accessible summary explains that amounts are hidden.
- Given Privacy Mode is revealed, when the person taps the always-visible eye control, then all app-controlled monetary presentation conceals in the same interaction.
- Given a configured local lock, when TBB launches or returns from background according to the chosen policy, then financial content is unavailable until local authentication succeeds.
- Given biometric authentication is unavailable or fails, when the app requests unlock, then TBB offers its configured safe fallback without revealing content.
- Given an unlocked app is displayed on a shared budget, when Privacy Mode changes, then only local presentation changes; no household record or participant state is mutated.
- Given a privacy or lock state transition, when diagnostics are written, then no amount or secret is included.

## Design constraints

Authentication implementation must use Apple Security/LocalAuthentication APIs behind `LocalAuthenticationClient`. The initial package contains the policy and contract only; platform adapters, Keychain secret handling, and passcode setup UI are completed before M1 closes.
