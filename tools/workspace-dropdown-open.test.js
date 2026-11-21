const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const switcher = read('src/workspace_switcher.zig');
const registry = read('src/workspaces.zig');

function body(source, name) {
  const at = source.indexOf(`fn ${name}(`);
  assert.ok(at >= 0, `missing ${name}`);
  const stop = source.indexOf('\n}', at);
  assert.ok(stop > at, `missing end of ${name}`);
  return source.slice(at, stop + 2);
}

test('SOFT-2374 opening the workspace menu never performs registry IO on the window thread', () => {
  const click = body(switcher, 'headerClick');
  assert.match(click, /loadEntries\(\)/);
  assert.match(click, /refreshMenuEntries\(\)/);
  assert.doesNotMatch(click, /syncInProcessWorkspacesToRegistry|mergeWorkspaceRegistryFromDisk/);
  const refresh = body(registry, 'refreshMenuEntries');
  assert.doesNotMatch(refresh, /lockWorkspaceRegistry|readWorkspaceRegistryBytes|writeWorkspaceRegistryFile|getWorkspaceRegistryPath/);
  assert.match(refresh, /std\.Thread\.spawn/);
  assert.match(refresh, /\.load\(\.acquire\)/);
  assert.match(refresh, /upsertMySlotEntries\(\)/);
  const worker = body(registry, 'readMenuRegistry');
  assert.match(worker, /lockWorkspaceRegistryWithTimeout\(5000\)/);
  assert.match(worker, /readWorkspaceRegistryBytes/);
  assert.match(worker, /\.store\(true, \.release\)/);
  assert.doesNotMatch(worker, /app_state\.|parseWorkspaceRegistryJson|writeWorkspaceRegistryFile/);
});

test('SOFT-2374 a completed read cannot overwrite a newer local registry save', () => {
  assert.match(body(registry, 'writeWorkspaceRegistryFile'), /registry_revision \+%= 1/);
  assert.match(body(registry, 'refreshMenuEntries'), /menu_registry_revision == registry_revision/);
});
