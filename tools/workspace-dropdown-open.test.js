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

test('SOFT-2374 opening the workspace menu never touches the registry on the window thread', () => {
  const click = body(switcher, 'headerClick');
  assert.match(click, /prepareMenuEntries\(\)/);
  assert.match(click, /refreshMenuRegistry\(hwnd\)/);
  assert.match(click, /loadEntries\(\)/);
  assert.doesNotMatch(click, /syncInProcessWorkspacesToRegistry|mergeWorkspaceRegistryFromDisk/);
  const prepare = body(registry, 'prepareMenuEntries');
  assert.doesNotMatch(prepare, /lockWorkspaceRegistry|readWorkspaceRegistryBytes|writeWorkspaceRegistryFile|getWorkspaceRegistryPath|mergeWorkspaceRegistryFromDisk/);
  const refresh = body(registry, 'refreshMenuRegistry');
  assert.doesNotMatch(refresh, /lockWorkspaceRegistry|readWorkspaceRegistryBytes|getWorkspaceRegistryPath|mergeWorkspaceRegistryFromDisk/);
  assert.match(refresh, /std\.Thread\.spawn/);
  const worker = body(registry, 'readMenuRegistry');
  assert.match(worker, /lockWorkspaceRegistryWithTimeout\(5000\)/);
  assert.match(worker, /readWorkspaceRegistryBytes/);
  assert.match(worker, /menu_snapshot_ready\.store\(true, \.release\)/);
  assert.doesNotMatch(worker, /app_state\.|parseWorkspaceRegistryJson|writeWorkspaceRegistryFile/);
  assert.match(body(switcher, 'wndProc'), /takeMenuRegistrySnapshot\(\)/);
});

test('SOFT-2374 a finished read cannot overwrite a newer local registry save', () => {
  assert.match(body(registry, 'writeWorkspaceRegistryFile'), /registry_revision \+%= 1/);
  assert.match(body(registry, 'menuSnapshotUsable'), /read_revision == registry_revision/);
  assert.match(body(registry, 'takeMenuRegistrySnapshot'), /menuSnapshotUsable\(/);
});

test('SOFT-2374 the held-lock regression test ships in the desktop test binary', () => {
  assert.match(registry, /test "SOFT-2374 the workspace menu opens while another window holds the registry"/);
  assert.match(body(registry, 'prepareMenuEntries'), /syncCurrentWorkspaceToRegistry\(\)/);
  assert.match(body(registry, 'prepareMenuEntries'), /upsertMySlotEntries\(\)/);
});
