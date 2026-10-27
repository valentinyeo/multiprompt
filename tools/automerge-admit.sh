#!/usr/bin/env bash
set -uo pipefail

if (( $# != 4 )); then
    printf 'usage: %s <pr-info.json> <files.json> <behind_by> <owner>\n' "$0" >&2
    exit 2
fi
info_file=$1
files_file=$2
behind_by=$3
owner=$4

required='["test","no-comments","extension-version","secret-scan","ledger-guard"]'
info=$(cat -- "$info_file" 2>/dev/null) || info=""
files=$(cat -- "$files_file" 2>/dev/null) || files=""

if ! jq -e 'type == "object" and (.headRefOid | type == "string" and test("^[0-9a-f]{40}$"))' <<< "$info" >/dev/null 2>&1; then
    echo 'skip (invalid PR head)'
    exit 0
fi
if ! jq -e 'type == "array" and length > 0 and all(.[]; type == "string")' <<< "$files" >/dev/null 2>&1; then
    echo 'skip (could not list PR files)'
    exit 0
fi
reason=$(jq -r --arg owner "$owner" '
  if .isCrossRepository != false or (.author.login != $owner and .author.login != "app/software-factory-runners") then "not a same-repo PR by the owner"
  elif .baseRefName != "master" then "base is not master"
  elif .isDraft != false then "draft"
  elif (.labels | type) != "array" then "could not read labels"
  elif any(.labels[]; .name == "hold") then "hold label"
  elif .mergeable != "MERGEABLE" then "not mergeable (\(.mergeable))"
  else "" end' <<< "$info") || reason='could not evaluate PR state'
if [ -n "$reason" ]; then echo "skip ($reason)"; exit 0; fi
protected=$(jq -r '[.[] | select(test("^(\\.github/workflows/|tools/(automerge-admit[^/]*|version-stamp[^/]*|release-[^/]*|sign-release[^/]*)|src/(changelog\\.zig|release_signing_public_key\\.txt)|build\\.zig(\\.zon)?$)"))] | first // empty' <<< "$files") || protected='could not evaluate protected paths'
if [ -n "$protected" ]; then
    echo "skip (edits release or admission machinery: $protected; needs manual review)"
    exit 0
fi
if ! [[ "$behind_by" =~ ^[0-9]+$ ]]; then echo 'skip (could not compare with master)'; exit 0; fi
blocked=$(jq -r --argjson required "$required" --argjson files "$files" '
  def blocks_required:
    if .__typename == "StatusContext" then .state != "SUCCESS"
    else .status != "COMPLETED" or .conclusion != "SUCCESS" end;
  def blocks_optional:
    if .__typename == "StatusContext" then .state != "SUCCESS"
    else .status != "COMPLETED" or (.conclusion != "SUCCESS" and .conclusion != "SKIPPED") end;
  if (.statusCheckRollup | type) != "array" or (.statusCheckRollup | length) == 0 then "no checks reported"
  else
    (any($files[]; test("^(src/|\\.claude/skills/verify-multiprompt/|tools/(verify-multiprompt\\.test\\.js|chat-sync-audit(\\.test)?\\.py|chat-focus\\.test\\.js|chat-view-everywhere(-policy)?\\.test\\.js|verify-chat-delivery(\\.test\\.js|/)|chat-local-agent\\.c|chat-messages-only-proof(\\.test)?\\.mjs|chat-code-font-proof\\.(mjs|test\\.js)|chat-composer-text-proof\\.(mjs|test\\.js)|start-maximized\\.test\\.js|verify-scratch\\.test\\.ps1|favorites-groups\\.test\\.js|check-browser-pane-stuck\\.mjs|check-browser-pane-locked\\.test\\.js|check-workspace-focus\\.mjs|pane-spacing\\.test\\.js|browser-switch-speed\\.test\\.js|frozen-wake\\.test\\.js|browser-own-profile\\.test\\.js))"))) as $verify
    | (any($files[]; . == "tools/chat-sync-audit.py" or . == "tools/chat-sync-audit.test.py")) as $audit
    | ($required + if $verify then ["chat-sync-audit-changes", "verify (appearance)"] else [] end + if $audit then ["chat-sync-audit"] else [] end) as $req
    | [.statusCheckRollup[] | select((.name == "chat-sync-audit" and .status == "COMPLETED" and .conclusion == "SKIPPED" and ($audit | not)) | not)] as $roll
    | ($req + [$roll[] | .name // .context] | unique) as $names
    | [$names[] as $name
       | [$roll[] | select((.name // .context) == $name)] as $checks
       | select(if ($req | index($name)) != null then
           ($checks | length) == 0 or any($checks[]; blocks_required)
         else
           any($checks[]; blocks_optional)
         end)
       | $name] | join(",")
  end' <<< "$info") || blocked='could not evaluate head checks'
if [ -n "$blocked" ]; then echo "skip (required checks not green: $blocked)"; exit 0; fi
if [[ "$behind_by" =~ [1-9] ]]; then echo update; exit 0; fi
echo merge
