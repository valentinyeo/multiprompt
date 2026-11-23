const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const render = fs.readFileSync(path.join(root, 'src/chat_render.zig'), 'utf8');
const view = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/features/chat-view.md'), 'utf8');

test('SOFT-2464 hosted proof includes a session link switch test', () => {
  assert.match(render, /test "SOFT-2464 a clicked session link switches the active shell"/);
  assert.match(render, /openTmuxLink\(peer\)/);
  assert.match(view, /session-link-click/);
});