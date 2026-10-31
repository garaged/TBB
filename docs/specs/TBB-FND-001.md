# TBB-FND-001 — Foundation workflow and quality gates

## Intent

Maintain a repository in which product decisions, behavior, architecture, tests, and release evidence remain traceable.

## Acceptance criteria

- Given any merged milestone, when a contributor inspects it, then intent, ADRs, specs, traceability, and verification instructions identify the behavior delivered.
- Given a pull request, when CI runs, then specification structure, Markdown hygiene, and repository commands execute without requiring an Apple signing identity.
- Given a new behavior, when it changes a user-visible or security-sensitive outcome, then it receives a stable specification ID and automated or manual verification evidence.
- Given a merge request, when checks are incomplete, then it remains unmerged until explicitly approved by the repository owner.

## Quality commands

```bash
make spec-check
make ci
```
