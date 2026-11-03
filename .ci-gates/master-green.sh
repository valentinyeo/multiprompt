#!/usr/bin/env bash
set -uo pipefail
repo=valentinyeo/multiprompt
id=$(gh run list --repo "$repo" --workflow=Tests --branch=master --limit 1 --json databaseId,headSha --jq '.[0].databaseId') || exit 1
[ -n "$id" ] && [ "$id" != null ] || { echo "no Tests run on master"; exit 1; }
gh run view "$id" --repo "$repo" --json conclusion,jobs,headSha --jq 'if .conclusion == "success" and ((.jobs | length) > 0) and all(.jobs[]; .conclusion == "success") then "master tests green" else "master tests not green: \(.conclusion) " + ([.jobs[] | select(.conclusion != "success") | .name] | join(", ")) end'
