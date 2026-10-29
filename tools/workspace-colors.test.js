const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('ordered palette is portable metadata, not a workspace name mapping', () => {
  assert.match(read('src/session_layout.zig'), /color: \?u8 = null/);
  const palette = read('src/bot_avatar.zig').match(/pub const colors = \[_\]u32\{([^}]+)\}/);
  assert.ok(palette);
  const colors = palette[1].match(/0x[0-9A-F]+/g).map(Number);
  assert.equal(colors.length, 7);
  assert.equal(new Set(colors).size, 7);
  for (const value of colors) assert.notEqual(value >> 16 & 255, value & 255);
  for (const file of ['session_layout.zig', 'account_layout.zig', 'launch_snapshot.zig']) {
    const result = spawnSync(process.env.ZIG_EXE || 'zig', ['test', `src/${file}`, '--test-filter', 'IGSH-1172'], {cwd: root, encoding: 'utf8', timeout: 120000});
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All [1-9]\d* tests passed/);
  }
});

test('settings persist overrides, account sync advertises them and startup caches retain them', () => {
  assert.match(read('src/account_client.zig'), /hosts,host_removal,workspace_color/);
  const settings = read('src/settings_panel.zig');
  assert.match(settings, /for \(@import\("bot_avatar.zig"\).colors, 0\.\.\)/);
  assert.match(settings, /state.g_ws_colors\[workspace\] = color;[\s\S]*?saveSession\(\)/);
  assert.match(read('src/account_desktop.zig'), /\.color = app_state.g_ws_colors\[ws\]/);
  assert.match(read('src/launch_cache.zig'), /\.workspace_colors = state.g_ws_colors/);
  assert.match(read('src/workspaces.zig'), /std.mem.swap\(\?u8, &app_state.g_ws_colors\[a\], &app_state.g_ws_colors\[b\]\)/);
});
