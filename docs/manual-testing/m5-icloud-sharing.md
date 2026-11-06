# M5 Manual Acceptance — iCloud household sharing

## Required preflight

```bash
git fetch origin
git switch feature/m5-icloud-sharing
git pull --ff-only origin feature/m5-icloud-sharing
git rev-parse --short HEAD
git rev-parse HEAD
```

Record the full SHA and verify it matches the M5 pull request before testing. See the Manual Acceptance Protocol.

## Required setup

- Two real Apple devices signed into different Apple Accounts. Simulator-only validation is insufficient for this milestone.
- A signed build with the `iCloud.org.garaged.TBB` container enabled for the TBB bundle ID.
- One owner account and one participant account with iCloud Drive enabled.
- Network controls sufficient to put the participant device offline and online.

## Acceptance

1. On the owner device, create or choose a private household space and record an account, expense category, transaction, and budget.
2. Open Sharing. Verify the explanation says iCloud is required and no TBB account or central TBB service is used.
3. Invite the participant with Apple’s sharing sheet. Accept on the participant device.
4. Verify the participant sees exactly the shared space and its accounts, categories, transactions, and budgets; verify neither device exposes unrelated private data.
5. On the participant device, record one transaction while offline. Reopen the app, then restore connectivity. Verify the transaction appears once on both devices.
6. Edit the same shared item independently on both devices while they cannot reach each other. Restore connectivity. Verify both devices converge on the documented deterministic result and the audit view identifies a redacted conflict event.
7. Enable Privacy Mode on only one device. Verify its amounts are masked while the other participant’s device remains unchanged.
8. From the owner device, remove the participant. After sync, verify the participant loses the shared-space view, cannot mutate it, and still retains unrelated private spaces.
9. Sign out of iCloud or disable the CloudKit capability in a test configuration. Verify sharing shows a truthful recoverable error and private budgeting continues.
10. With VoiceOver, verify household-space selection, share state, invite, manage participants, revoke, retry, and audit controls have understandable labels.

Record branch, full SHA, device models, OS versions, both Apple Account roles, network states, CloudKit container, and PASS/FAIL results in the pull request before merge.
