#!/usr/bin/env bash
set -euo pipefail

dry_run=false
if (( $# == 1 )) && [ "$1" = --dry-run ]; then
    dry_run=true
elif (( $# != 0 )); then
    printf 'usage: %s [--dry-run]\n' "$0" >&2
    exit 2
fi

if ! last_tag=$(git describe --tags --match 'v*' --first-parent --abbrev=0 HEAD 2>/dev/null); then
    echo 'no release tag found; skipping' >&2
    exit 0
fi
commits=$(git rev-list --first-parent "$last_tag..HEAD")
for sha in $commits; do
    if [ -n "$(git tag --points-at "$sha")" ]; then
        continue
    fi
    if git log -1 --pretty=%B "$sha" | grep -Fq -e '[skip release]' -e '[release skip]'; then
        continue
    fi
    runs=$(gh run list -R "$GITHUB_REPOSITORY" -w test.yml -b master --commit "$sha" --limit 100 \
        --json databaseId,event,status,conclusion)
    if ! jq -e '
        map(select(.event == "push" or .event == "workflow_dispatch"))
        | sort_by(.databaseId) | last | .status == "completed" and .conclusion == "success"' <<< "$runs" >/dev/null; then
        continue
    fi
    release_tag=$(node tools/release-version.mjs --next "$(git describe --tags --abbrev=0 "$sha")")
    if git show-ref --verify --quiet "refs/tags/$release_tag"; then
        echo "$release_tag already exists; refusing to move it" >&2
        exit 1
    fi
    if [ "$dry_run" = false ]; then
        git tag "$release_tag" "$sha"
        git push origin "refs/tags/$release_tag" >&2
    fi
    printf 'tag=%s\nsha=%s\n' "$release_tag" "$sha"
    exit 0
done
