#!/usr/bin/env bash
set -euo pipefail

RELEASE_JOURNEY=relaunch-saved-sessions
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
    verify_runs=$(gh run list -R "$GITHUB_REPOSITORY" -w verify.yml -b master --commit "$sha" --limit 100 \
        --json databaseId,event,status,conclusion)
    verify_id=$(jq -r 'map(select(.event == "push")) | sort_by(.databaseId) | last | .databaseId // empty' <<< "$verify_runs")
    if [ -z "$verify_id" ]; then
        echo "$sha has no verify run; relaunch-saved-sessions is missing, not releasing" >&2
        continue
    fi
    verify_jobs=$(gh run view "$verify_id" -R "$GITHUB_REPOSITORY" --json jobs)
    if ! jq -e --arg job "verify ($RELEASE_JOURNEY)" '
        [.jobs[] | select(.name == $job)] | length == 1 and all(.conclusion == "success")' <<< "$verify_jobs" >/dev/null; then
        echo "$sha has no green $RELEASE_JOURNEY journey; not releasing" >&2
        continue
    fi
    release_tag=$(node tools/release-version.mjs --next "$last_tag")
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
