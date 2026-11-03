#!/usr/bin/env bash
# One head-pinned read: the Tests run for this commit must exist and have every job green.
set -uo pipefail
cd /home/valentin/projects/multiprompt-hyci-94 || exit 1
repo=valentinyeo/multiprompt
sha=$(git rev-parse HEAD) || exit 1
row=$(gh run list --repo "$repo" --workflow=Tests --limit 30 --json databaseId,headSha,status,conclusion --jq "[.[] | select(.headSha == \"$sha\")][0] | \"\(.databaseId) \(.status) \(.conclusion)\"") || exit 1
[ -n "$row" ] && [ "$row" != " " ] || { echo "no Tests run for $sha yet"; exit 1; }
read -r id status conclusion <<<"$row"
[ -n "${id:-}" ] && [ "$id" != null ] || { echo "no Tests run for $sha yet"; exit 1; }
[ "$status" = completed ] || { echo "run $id still $status"; exit 1; }
gh run view "$id" --repo "$repo" --json conclusion,jobs --jq 'if .conclusion == "success" and ((.jobs | length) > 0) and all(.jobs[]; .conclusion == "success") then "all checks passed" else "red: " + ([.jobs[] | select(.conclusion != "success") | "\(.name) (\(.conclusion))"] | join(", ")) end'
