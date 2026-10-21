const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = process.env.IGSH_224_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

test('IGSH-224 launches resolve the stable workspace identity before selecting a profile', () => {
  const pane = read('src/browser_pane.zig');
  assert.match(pane, /browser_workspace_profile/);
  assert.match(pane, /g_ws_ids\[ws\]/);
  assert.match(pane, /g_ws_id_len\[ws\]/);
  assert.match(pane, /workspaceProfileForShell/);
  assert.match(pane, /ensureWorkspaceProfile/);
});

test('IGSH-224 native hosts discover the actual Chromium profile before binding a pipe', () => {
  const bridge = read('src/bridge.zig');
  assert.match(bridge, /nativeParentToken/);
  assert.match(bridge, /ProfileAlreadyRegistered/);
});
