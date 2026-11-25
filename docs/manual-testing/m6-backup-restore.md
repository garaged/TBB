# M6 Manual Acceptance — Backup and restore

## Required preflight

```bash
git fetch origin
git switch feature/m6-backup-restore
git pull --ff-only origin feature/m6-backup-restore
git rev-parse --short HEAD
git rev-parse HEAD
```

Compare the full SHA with the PR head before testing. Use disposable test data and retain independent copies.

## Acceptance (pending implementation)

- Export an encrypted private budget; restore it offline as a new private space. Verify account, category, transaction, budget, currency, and date parity on iPhone and iPad.
- Verify wrong password, changed file, truncated file, unsupported version, cancellation, and denied document access leave all existing spaces unchanged.
- Verify an explicitly unencrypted export warns that contents are readable and unauthenticated.
- Export a shared budget with the warning visible. Restore it as a separate private space; verify no participants or share permissions are recreated and existing shared data is untouched.
- Verify the local password and backup password can differ, and the backup remains readable after the local password changes.
- Test VoiceOver and privacy masking throughout export and restore.

Record branch, full SHA, device/OS, account role, network state, archive mode, and individual PASS/FAIL outcomes.
