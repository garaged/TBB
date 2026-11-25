#!/usr/bin/env bash
set -euo pipefail

prompt() {
  local label="$1" value=""
  if [[ -r /dev/tty && -w /dev/tty ]] && { : </dev/tty; } 2>/dev/null; then
    printf '%s: ' "$label" > /dev/tty
    IFS= read -r value < /dev/tty || true
  fi
  printf '%s' "${value:-Not recorded}"
}

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
branch="$(git symbolic-ref --quiet --short HEAD || printf 'DETACHED HEAD')"
sha="$(git rev-parse HEAD)"
expected_branch="${TBB_EXPECTED_BRANCH:-}"
upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
remote_sha=""
if [[ -n "$upstream" ]]; then
  remote_sha="$(git rev-parse --verify "$upstream" 2>/dev/null || true)"
fi
dirty="$(git status --porcelain)"
container="$(python3 -c 'import plistlib; print(plistlib.load(open("TBB.entitlements", "rb"))["com.apple.developer.icloud-container-identifiers"][0])' 2>/dev/null || printf 'Unavailable; inspect TBB.entitlements')"

printf '%s\n' 'Enter device models, OS versions, and network conditions as observed during testing.' >&2
printf '%s\n' 'Do not enter account addresses, credentials, or invitation links.' >&2
owner_device="$(prompt 'Owner device model and OS version')"
owner_network="$(prompt 'Owner network state (online/offline/conditions)')"
participant_device="$(prompt 'Participant device model and OS version')"
participant_network="$(prompt 'Participant network state (online/offline/conditions)')"

printf '\n%s\n' '## TBB test environment'
printf -- '- Branch: %s\n' "$branch"
printf -- '- Full commit SHA: %s\n' "$sha"
if [[ -z "$expected_branch" ]]; then
  printf -- '- Expected branch: not specified; verify against the test checklist\n'
elif [[ "$branch" == "$expected_branch" ]]; then
  printf -- '- Expected branch: yes\n'
else
  printf -- '- Expected branch: NO (expected %s)\n' "$expected_branch"
fi
if [[ -z "$remote_sha" ]]; then
  printf -- '- Upstream comparison: unavailable; check tracking and fetch your remote\n'
elif [[ "$sha" == "$remote_sha" ]]; then
  printf -- '- Local SHA matches last-fetched %s: yes\n' "$upstream"
else
  printf -- '- Local SHA matches last-fetched %s: NO (%s)\n' "$upstream" "$remote_sha"
fi
if [[ -n "$dirty" ]]; then
  printf -- '- Working tree: modified (review git status)\n'
else
  printf -- '- Working tree: clean\n'
fi
printf -- '- Owner: %s; network: %s\n' "$owner_device" "$owner_network"
printf -- '- Participant: %s; network: %s\n' "$participant_device" "$participant_network"
printf -- '- CloudKit container configured in TBB.entitlements: %s\n' "$container"
printf -- '- PR head match: verify against the current GitHub PR head\n'
printf '\n%s\n' 'Booted simulator inventory (local machine; includes device identifiers):'
if command -v xcrun >/dev/null 2>&1; then
  xcrun simctl list devices booted || printf '%s\n' 'Unable to obtain simulator inventory.'
else
  printf '%s\n' 'Unavailable: xcrun not found.'
fi
printf '\n%s\n' 'Network conditions, account roles, and physical device details are user-reported, not automatically verified.'
printf '%s\n' 'The container is repository configuration, not a check of the installed app or Developer account.'
