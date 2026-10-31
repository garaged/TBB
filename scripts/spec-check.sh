#!/usr/bin/env bash
set -euo pipefail

required=(
  AGENTS.md
  docs/intent.md
  docs/architecture.md
  docs/threat-model.md
  docs/testing.md
  docs/traceability.md
  docs/specs/registry.md
  docs/specs/TBB-FND-001.md
  docs/specs/TBB-CUR-001.md
  docs/specs/TBB-I18N-001.md
  docs/specs/TBB-SHR-001.md
  docs/decisions/ADR-0001-cloudkit-household-sharing.md
)

for file in "${required[@]}"; do
  test -f "$file" || { echo "Missing required foundation artifact: $file" >&2; exit 1; }
done

for id in TBB-FND-001 TBB-CUR-001 TBB-I18N-001 TBB-SHR-001; do
  grep -q "$id" docs/specs/registry.md
done
grep -q 'ADR-0001' docs/traceability.md
grep -q 'MPL-2.0' README.md

echo "Foundation specification checks passed."
