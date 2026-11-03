#!/usr/bin/env bash
set -uo pipefail
cd /home/valentin/projects/multiprompt-hyci-94 || exit 1
base=$(git merge-base origin/master HEAD) || exit 1
if [ -n "$(git diff --name-only "$base" HEAD -- src extension)" ]; then
  echo "app source changed without a product changelog fragment"
  exit 1
fi
kind=$(node tools/version-stamp.mjs check "$base" HEAD) || exit 1
[ "$kind" = CODE ] || { echo "unexpected version kind: $kind"; exit 1; }
echo "version rule accepted"
