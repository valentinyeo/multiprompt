const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const switcher = fs.readFileSync(path.join(root, 'src/workspace_switcher.zig'), 'utf8');
const registry = fs.readFileSync(path.join(root, 'src/workspaces.zig'), 'utf8');

function sliceBetween(source, start, end) {
  const at = source.indexOf(start);
  assert.ok(at >= 0, `missing ${start}`);
  const stop = source.indexOf(end, at + start.length);
  assert.ok(stop > at, `missing ${end}`);
  return source.slice(at, stop);
}

test('SOFT-2374 opening the workspace menu does not wait on the registry lock', () => {
  const click = sliceBetween(switcher, 'pub fn headerClick', 'fn step(');
  assert.match(click, /loadEntries\(\)/);
  assert.match(click, /refreshMenuEntries\(\)/);
  assert.doesNotMatch(click, /syncInProcessWorkspacesToRegistry/);
  assert.doesNotMatch(click, /mergeWorkspaceRegistryFromDisk/);
  const refresh = sliceBetween(registry, 'pub fn refreshMenuEntries', 'pub fn syncInProcessWorkspacesToRegistry');
  assert.match(refresh, /lockWorkspaceRegistryWithTimeout\(menu_registry_wait_ms\)/);
  assert.match(registry, /const menu_registry_wait_ms: u32 = 0;/);
  assert.match(refresh, /menuKeepsMemory\(/);
  assert.doesNotMatch(refresh, /publishIfChanged/);
  assert.match(registry, /test "SOFT-2374 the workspace menu keeps memory when the registry is unchanged and never waits"/);
});
