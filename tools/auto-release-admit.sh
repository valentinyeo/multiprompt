#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
    printf 'usage: %s <tested-sha> <event-name>\n' "$0" >&2
    exit 2
fi
sha=$1
event=$2

if ! git merge-base --is-ancestor "$sha" origin/master; then
    echo 'tested commit is not an ancestor of origin/master; skipping' >&2
    exit 0
fi
if git log -1 --pretty=%B "$sha" | grep -Fq -e '[skip release]' -e '[release skip]'; then
    echo 'commit asks for no release; skipping' >&2
    exit 0
fi
if [ -n "$(git tag --points-at "$sha")" ]; then
    echo 'commit is already tagged; skipping' >&2
    exit 0
fi
if [ -n "$(git tag --contains "$sha" --list 'v*')" ]; then
    echo 'commit is already included in a release; skipping' >&2
    exit 0
fi
if [ "$event" = workflow_dispatch ]; then
    if ! gh run list -R "$GITHUB_REPOSITORY" -w test.yml -b master --commit "$sha" --limit 100 \
        --json databaseId,event,status,conclusion | jq -e '
          map(select(.event == "push" or .event == "workflow_dispatch"))
          | sort_by(.databaseId) | last | .status == "completed" and .conclusion == "success"' >/dev/null; then
        echo 'Tests are not green for the tested commit; skipping' >&2
        exit 0
    fi
fi
release_tag=$(node tools/release-version.mjs --next "$(git describe --tags --abbrev=0 "$sha")")
if git show-ref --verify --quiet "refs/tags/$release_tag"; then
    echo "$release_tag already exists; refusing to move it" >&2
    exit 1
fi
printf 'ready=true\ntag=%s\n' "$release_tag"
