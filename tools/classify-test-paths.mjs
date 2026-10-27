import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const fullGroups = [1, 2, 3, 4, 5];

const docs = /^(?:docs\/|openwiki\/|docs-site\/|changelog\.d\/|[^/]+\.md$)/;
const unusedTools = new Set(['tools/ci-cost.mjs']);
const groupRules = [
  [5, /^(?:src\/(?:ssh_|bridge_)|tools\/version-stamp)/],
  [4, /^(?:src\/(?:sync_|console_font|launch_|chat_table|screenshot_|chat_draft|idle_)|tools\/chat-table)/],
  [2, /^(?:src\/(?:chat_view|chat_perf|chat_echo|chat_drop)|tools\/pane-spacing)/],
  [1, /^src\/(?:usage_|telemetry_|chat_cpu)/],
];

export function requiresTests(paths) {
  return !paths.length || paths.some(path => !docs.test(path) && !unusedTools.has(path));
}

export function groupForPaths(paths) {
  const found = [];
  for (const file of paths) {
    let group = 0;
    for (const [id, pattern] of groupRules) {
      if (pattern.test(file)) {
        group = id;
        break;
      }
    }
    if (!group && /^src\/.*\.zig$/.test(file)) group = 3;
    if (group && !found.includes(group)) found.push(group);
  }
  return found.length === 1 ? found[0] : 1;
}

export function plan(paths, merge) {
  const heavy = requiresTests(paths);
  return { heavy, full: !!merge, groups: merge ? fullGroups.slice() : [groupForPaths(paths)] };
}

function assertRouting() {
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
  assert.deepEqual(plan(['src/chat_view.zig'], false).groups, [2]);
  assert.deepEqual(plan(['src/main.zig', 'src/chat_view.zig'], false).groups, [1]);
  assert.deepEqual(plan(['tools/app-source.js'], false).groups, [1]);
  assert.deepEqual(plan(['src/ssh_reconnect.zig'], false).groups, [5]);
  assert.deepEqual(plan(['src/main.zig'], true).groups, fullGroups);
  assert.equal(plan(['README.md'], false).heavy, false);
  assert.equal(plan(['README.md'], true).full, true);
}

function main() {
  assertRouting();
  const raw = fs.readFileSync(process.env.CHANGED_PATHS_FILE, 'utf8').split('\0').filter(Boolean);
  const chosen = plan(raw, process.env.MERGE === 'true');
  const body = `heavy=${chosen.heavy}\nfull=${chosen.full}\ngroups=${JSON.stringify(chosen.groups)}\n`;
  if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, body);
  console.log('Path routing controls passed');
  console.log(JSON.stringify({ ...chosen, paths: raw }));
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) main();
