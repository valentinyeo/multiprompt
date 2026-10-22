base="$BASE"
if [ "$EVENT" = pull_request ]; then
  base="$(git merge-base "$BASE" "$HEAD")"
elif [ "$base" = 0000000000000000000000000000000000000000 ]; then
  base="$(git hash-object -t tree /dev/null)"
fi
git diff --name-only -z "$base" "$HEAD" > "$RUNNER_TEMP/changed-paths"
node --input-type=module <<'NODE'
import assert from 'node:assert/strict';
import fs from 'node:fs';
const paths = fs.readFileSync(`${process.env.RUNNER_TEMP}/changed-paths`, 'utf8').split('\0').filter(Boolean);
const docs = /^(?:docs\/|openwiki\/|docs-site\/|changelog\.d\/|[^/]+\.md$)/;
const unusedTools = new Set(['tools/ci-cost.mjs']);
const requiresTests = paths => !paths.length || paths.some(path => !docs.test(path) && !unusedTools.has(path));
for (const [paths, expected] of [
  [['README.md', 'openwiki/operations/build.md'], false],
  [['changelog.d/IGSH-519-checks.md', 'CHANGELOG.md'], false],
  [['docs/guide.md', 'docs-site/src/pages/index.astro'], false],
  [['tools/ci-cost.mjs'], false],
  [['tools/ci-cost.mjs', 'README.md'], false],
  [['tools/ci-cost.mjs', 'tools/release-version.mjs'], true],
  [['tools/app-source.js'], true],
  [['tools/font-probe-dwrite.cpp'], true],
  [['README.md', 'build.zig'], true],
  [['src/testdata/history.md'], true],
  [['.github/workflows/test.yml'], true],
  [[], true],
]) assert.equal(requiresTests(paths), expected);
console.log('Path routing controls passed');
const heavy = requiresTests(paths);
fs.appendFileSync(process.env.GITHUB_OUTPUT, `heavy=${heavy}\n`);
console.log(JSON.stringify({ heavy, paths }));
NODE
