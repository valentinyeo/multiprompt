base="$BASE"
if [ "$EVENT" = pull_request ] || [ "$EVENT" = pull_request_review ]; then
  base="$(git merge-base "$BASE" "$HEAD")"
elif [ "$EVENT" = workflow_dispatch ]; then
  base="$(git merge-base origin/master "$HEAD")"
elif [ "$EVENT" = merge_group ]; then
  base="$(git merge-base "$BASE" "$HEAD")"
elif [ "$base" = 0000000000000000000000000000000000000000 ]; then
  base="$(git hash-object -t tree /dev/null)"
fi
git diff --name-only -z "$base" "$HEAD" > "$RUNNER_TEMP/changed-paths"
merge=false
if [ "$EVENT" = push ] || [ "$EVENT" = workflow_dispatch ] || [ "$EVENT" = merge_group ]; then
  merge=true
fi
if [ "$EVENT" = pull_request_review ] && [ "$DRAFT" != true ]; then
  merge=true
fi
if [ "$EVENT" = pull_request ] && [ "$ACTION" = labeled ] && [ "$LABEL" = automerge ]; then
  merge=true
fi
if [ "$EVENT" = pull_request ] && [ "$merge" = false ] && [ -n "${PR:-}" ] && [ -n "${GH_TOKEN:-}" ]; then
  if GH_TOKEN="$GH_TOKEN" gh pr view "$PR" -R "$GITHUB_REPOSITORY" --json labels -q '.labels[].name' 2>/dev/null | grep -qx automerge; then
    merge=true
  fi
fi
export CHANGED_PATHS_FILE="$RUNNER_TEMP/changed-paths"
export MERGE="$merge"
node tools/classify-test-paths.mjs
