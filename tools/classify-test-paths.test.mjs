import assert from 'node:assert/strict';
import test from 'node:test';
import { fullGroups, groupForPaths, plan, requiresTests } from './classify-test-paths.mjs';

test('docs and the unused cost helper do not start Windows tests', () => {
  assert.equal(requiresTests(['README.md', 'changelog.d/IGSH-519-checks.md']), false);
  assert.equal(requiresTests(['tools/ci-cost.mjs']), false);
  assert.equal(requiresTests([]), true);
  assert.equal(requiresTests(['src/main.zig']), true);
});

test('a pull request runs one mapped group, or the smoke group when the mapping is unclear', () => {
  assert.equal(groupForPaths(['src/chat_view.zig']), 2);
  assert.equal(groupForPaths(['src/ssh_reconnect.zig', 'tools/version-stamp.mjs']), 5);
  assert.equal(groupForPaths(['src/launch_cache.zig']), 4);
  assert.equal(groupForPaths(['src/usage_telemetry.zig']), 1);
  assert.equal(groupForPaths(['src/main.zig']), 3);
  assert.equal(groupForPaths(['src/main.zig', 'src/chat_view.zig']), 1);
  assert.equal(groupForPaths(['tools/app-source.js', '.github/workflows/test.yml']), 1);
  assert.deepEqual(plan(['src/chat_view.zig'], false), { heavy: true, full: false, groups: [2] });
  assert.deepEqual(plan(['src/main.zig', 'src/chat_table.zig'], false).groups, [1]);
  assert.equal(plan(['src/main.zig', 'src/chat_table.zig'], false).groups.length, 1);
});

test('merge and master run the full five groups', () => {
  assert.deepEqual(plan(['src/chat_view.zig'], true), { heavy: true, full: true, groups: fullGroups });
  assert.deepEqual(fullGroups, [1, 2, 3, 4, 5]);
  assert.equal(plan(['README.md'], true).heavy, false);
  assert.equal(plan(['README.md'], true).full, true);
});
