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

Run `make m5-evidence` to capture the branch, full SHA, last-fetched remote comparison, configured container, and booted simulators. Enter the owner and participant device models, OS versions, and network conditions when prompted. Physical device details and all role/network entries are user-reported. The script does not verify the installed app or current PR head; compare the SHA against the PR yourself. Review the output before sharing because simulator inventory includes device identifiers. Optionally save it with `make m5-evidence > /tmp/tbb-m5-evidence.txt`.

## Required setup

- Two real Apple devices signed into different Apple Accounts. Simulator-only validation is insufficient for this milestone.
- A signed build with the `iCloud.org.garaged.TBB` container enabled for the TBB bundle ID.
- One owner account and one participant account with iCloud Drive enabled.
- Network controls sufficient to put the participant device offline and online.

## Optional simulator smoke test

Simulator validation may exercise the development path but does not replace the required real-device acceptance. After updating the branch, regenerate the Xcode project with `xcodegen generate` and rebuild TBB on both simulators. Confirm the recipient app's built `Info.plist` contains `CKSharingSupported = true`.

1. Sign the owner simulator into an Apple Account in **Settings**, enable **iCloud Drive**, then force-quit and relaunch TBB.
2. Sign a second simulator into a different Apple Account for the invitation-acceptance check.
3. On the owner simulator, tap **Share household budget**. The first Debug share attempt initializes TBB’s **Development** CloudKit schema; wait for it to complete, then retry if iCloud reports that the account is still becoming available.
4. Do not add records manually, import a schema, reset the environment, or deploy schema changes to Production. Inspect the Development schema only after TBB completes its initialization.

Refresh reloads the local store; it does not force iCloud to synchronize or confirm delivery to another device. Verify the refresh feedback states this distinction and that a failure is visible.

## Name and ownership checks

1. With one private and one shared space bearing the same name, verify their picker labels distinguish their ownership and sharing status.
2. On the owner device, rename the shared space to a distinctive test name. Refresh the participant after sync and verify the shared name changes without altering ledger data.
3. Rename the participant's own private space and verify the shared space is unaffected. Verify the participant cannot rename the owner's space.
4. Verify blank and over-80-character names are rejected.

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
