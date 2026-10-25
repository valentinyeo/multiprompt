#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
owner=fixture-owner
jq -n --arg owner "$owner" '{headRefOid: ("a" * 40), isCrossRepository: false, author: {login: $owner}, baseRefName: "master", isDraft: false, labels: [], mergeable: "MERGEABLE", statusCheckRollup: (["test", "no-comments", "extension-version", "secret-scan", "ledger-guard"] | map({__typename: "CheckRun", name: ., status: "COMPLETED", conclusion: "SUCCESS"}))}' > "$temp/green.json"
printf '["README.md"]\n' > "$temp/files.json"
check() {
    local name=$1 expected=$2 filter=$3 behind=${4:-0} files=${5:-'["README.md"]'}
    jq "$filter" "$temp/green.json" > "$temp/info.json"
    printf '%s' "$files" > "$temp/files.json"
    local actual
    actual=$(bash "$root/tools/automerge-admit.sh" "$temp/info.json" "$temp/files.json" "$behind" "$owner")
    if [[ "$actual" != "$expected" ]]; then
        printf '%s: expected <%s>, got <%s>\n' "$name" "$expected" "$actual" >&2
        exit 1
    fi
    printf '%s: %s\n' "$name" "$actual"
}
check green merge .
check draft 'skip (draft)' '.isDraft = true'
check failing 'skip (required checks not green: test)' '.statusCheckRollup[0].conclusion = "FAILURE"'
check behind 'skip (behind master by 1; rebase and push)' . 1
check workflow 'skip (edits release or admission machinery: .github/workflows/test.yml; needs manual review)' . 0 '[".github/workflows/test.yml"]'
check empty 'skip (required checks not green: no checks reported)' '.statusCheckRollup = []'
check hold 'skip (hold label)' '.labels = [{name: "hold"}]'
check fork 'skip (not a same-repo PR by the owner)' '.isCrossRepository = true'
check author 'skip (not a same-repo PR by the owner)' '.author.login = "other"'
check base 'skip (base is not master)' '.baseRefName = "other"'
check unknown-merge 'skip (not mergeable (UNKNOWN))' '.mergeable = "UNKNOWN"'
check missing 'skip (required checks not green: test)' '.statusCheckRollup |= map(select(.name != "test"))'
check pending 'skip (required checks not green: test)' '.statusCheckRollup[0].status = "IN_PROGRESS"'
check skipped 'skip (required checks not green: test)' '.statusCheckRollup[0].conclusion = "SKIPPED"'
check extra-failure 'skip (required checks not green: extra)' '.statusCheckRollup += [{name: "extra", status: "COMPLETED", conclusion: "FAILURE"}]'
check legacy-failure 'skip (required checks not green: legacy)' '.statusCheckRollup += [{__typename: "StatusContext", context: "legacy", state: "FAILURE"}]'
check legacy-green merge '.statusCheckRollup += [{__typename: "StatusContext", context: "legacy", state: "SUCCESS"}]'
check no-compare 'skip (could not compare with master)' . unknown
check bad-head 'skip (invalid PR head)' '.headRefOid = "invalid"'
check bad-info 'skip (invalid PR head)' null
check bad-files 'skip (could not list PR files)' . 0 '{}'
check no-files 'skip (could not list PR files)' . 0 '[]'
for path in tools/automerge-admit.sh tools/automerge-admit.test.sh tools/version-stamp.mjs tools/release-notes.mjs tools/sign-release.mjs src/changelog.zig src/release_signing_public_key.txt build.zig; do
    check "$path" "skip (edits release or admission machinery: $path; needs manual review)" . 0 "[\"$path\"]"
done
verify='["appearance", "session-restore", "workspace-focus", "favorites-groups", "browser-pane-stuck", "browser-pane-locked", "group-rail", "pane-layout", "chat-view", "chat-messages-only", "chat-view-everywhere", "chat-focus", "browser-own-profile", "status-card", "palette-order", "remind-me"]'
verify_filter=".statusCheckRollup += (($verify | map({name: (\"verify (\" + . + \")\"), status: \"COMPLETED\", conclusion: \"SUCCESS\"})) + [{name: \"chat-sync-audit-changes\", status: \"COMPLETED\", conclusion: \"SUCCESS\"}, {name: \"chat-sync-audit\", status: \"COMPLETED\", conclusion: \"SKIPPED\"}])"
check visible-green merge "$verify_filter" 0 '["src/chat.zig"]'
check verify-failure 'skip (required checks not green: verify (appearance))' "$verify_filter | (.statusCheckRollup[] | select(.name == \"verify (appearance)\")).conclusion = \"FAILURE\"" 0 '["src/chat.zig"]'
check missing-verify 'skip (required checks not green: verify (appearance))' "$verify_filter | .statusCheckRollup |= map(select(.name != \"verify (appearance)\"))" 0 '["src/chat.zig"]'
check audit-required 'skip (required checks not green: chat-sync-audit)' "$verify_filter" 0 '["tools/chat-sync-audit.py"]'
check audit-green merge "$verify_filter | (.statusCheckRollup[] | select(.name == \"chat-sync-audit\")).conclusion = \"SUCCESS\"" 0 '["tools/chat-sync-audit.py"]'
if bash "$root/tools/automerge-admit.sh" > "$temp/usage" 2>&1; then exit 1; else [ "$?" -eq 2 ]; fi
printf 'ADMISSION VERIFIED\n'
