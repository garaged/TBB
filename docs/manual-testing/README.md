# Manual Acceptance Protocol

Every TBB manual acceptance document follows this protocol before any product check.

## Required preflight

1. Fetch remote references.
2. Check out the exact branch named by the open PR.
3. Fast-forward that branch only.
4. Record the tested short and full commit SHA.
5. Compare the full SHA with the PR head SHA in GitHub. Stop if they differ.

For PR #3, the branch is `feature/m2-ledger`. Use HTTPS for the repository remote:

```bash
git fetch origin
git switch feature/m2-ledger
git pull --ff-only origin feature/m2-ledger
git rev-parse --short HEAD
git rev-parse HEAD
```

The acceptance report must include branch, full SHA, device model, OS version, checklist results, and deviations. A result from another branch or SHA is not valid evidence.
