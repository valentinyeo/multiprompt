const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('SOFT-3130 wires restart in place through mp-sessions, palette, mb and shortcuts', () => {
  assert.match(read('src/mp_sessions.py'), /restart_host\(send, provider, sid\)/);
  assert.match(read('src/mp_sessions.py'), /if target\.get\("running"\)/);
  assert.match(read('src/app_state.zig'), /pub const SEARCH_TABCTX_CHAT_RESTART_IN_PLACE: usize = 7179;/);
  assert.match(read('src/command_palette.zig'), /startRestartChatOnTab/);
  assert.match(read('src/main.zig'), /SEARCH_TABCTX_CHAT_RESTART_IN_PLACE/);
  assert.match(read('src/sidebar.zig'), /tab_context_chat_restart_in_place/);
  assert.match(read('tools/mb.mjs'), /^  restart <name>/m);
  assert.match(read('tools/palette-verbs.mjs'), /SEARCH_TABCTX_CHAT_RESTART_IN_PLACE.*restart/);
  assert.match(read('src/shortcuts.zig'), /Restart this chat in place/);
  assert.ok(fs.existsSync(path.join(root, 'tools/fixtures/SOFT-3130/listing.json')));
});