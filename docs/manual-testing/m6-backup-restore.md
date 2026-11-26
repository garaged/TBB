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

Run `TBB_EXPECTED_BRANCH=feature/m6-backup-restore make test-evidence` and keep the resulting environment block with the outcomes. Generate the project with XcodeGen after pulling so the new app source and localization catalog are included.

## Acceptance

Open **Household**, use the budget picker, and choose **Export selected budget**. For import use **Household → Restore from a backup → Choose backup file → Preview backup → Create private copy**.

- Save an encrypted file in Files. On a fresh installation with a different Apple Account, download or transfer a local copy, go offline, and restore it. Verify dates, transaction notes, transfers, budget plans and record counts against the source.
- In preview, cancel and verify the number of spaces. Repeat and confirm twice with different copy names. Edit one restored copy and verify the other and the source.
- With a local password configured, background TBB during preview. Verify the lock screen appears on return and that unlocking requires starting a fresh restore.
- Complete export and restore in Spanish. Check the warning, error, confirmation and success messages with VoiceOver and large text.

- Export an encrypted private budget; restore it offline as a new private space. Verify account, category, transaction, budget, currency, and date parity on iPhone and iPad.
- Verify wrong password, changed file, truncated file, unsupported version, cancellation, and denied document access leave all existing spaces unchanged.
- Verify an explicitly unencrypted export warns that contents are readable and unauthenticated.
- Export a shared budget with the warning visible. Restore it as a separate private space; verify no participants or share permissions are recreated and existing shared data is untouched.
- Verify the local password and backup password can differ, and the backup remains readable after the local password changes.
- Test VoiceOver and privacy masking throughout export and restore.

Record branch, full SHA, device/OS, account role, network state, archive mode, and individual PASS/FAIL outcomes.

## Results

Manual device results are pending. Record each case separately at the tested PR head. Use a synthetic budget and omit passwords, financial content, account addresses and share URLs from evidence.
