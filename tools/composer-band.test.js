const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('IGSH-805 composer band buffered native print requests PRF_CLIENT and PRF_ERASEBKGND', () => {
  const composer = read('src/chat_composer.zig');
  const backgroundPrint = /CallWindowProcW\(app_state\.g_chat_composer_orig_proc, hwnd, 0x0318, @intFromPtr\(dc\), 4 \| 8\);\s*var probe:/;
  assert.match(composer, backgroundPrint);
  const broken = composer.replace('0x0318, @intFromPtr(dc), 4 | 8);', '0x0318, @intFromPtr(dc), 4);');
  assert.notEqual(broken, composer);
  assert.throws(() => assert.match(broken, backgroundPrint), assert.AssertionError);
});
