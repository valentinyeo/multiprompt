const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../src/chat_render.zig'), 'utf8');
const match = source.match(/fn chatWorkingDotsVisible\(\) bool \{([^]*?)\n\}/);
assert.ok(match, 'working dots visibility must be available');
const visible = new Function('layout', 'outbox', 'live', 'app_state', match[1]
  .replaceAll('@import("window_layout.zig")', 'layout')
  .replaceAll('@import("chat_send.zig")', 'outbox')
  .replaceAll('@import("chat_live.zig")', 'live'));

function dots(stop, reply, queued) {
  return visible(
    { chatStopVisible: () => stop },
    { chatOutboxWorkingForShell: () => queued > 0 },
    { replyPresent: () => reply },
    { active_shell: 0, shells: [{ shell_id: 1770 }] },
  );
}

test('IGSH-1770 a streaming reply cannot hide working dots while Stop remains visible', () => {
  assert.equal(dots(true, true, 0), true);
});

test('IGSH-1770 dots follow Stop with zero, one or two messages waiting', () => {
  for (const stop of [false, true]) for (const reply of [false, true]) {
    for (const queued of [0, 1, 2]) assert.equal(dots(stop, reply, queued), stop,
      `stop=${stop} reply=${reply} queued=${queued}`);
  }
});
