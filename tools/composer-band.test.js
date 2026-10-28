const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('IGSH-805 composer band buffered paint fills the full client background before native print', () => {
  const composer = read('src/chat_composer.zig');
  const buffered = composer.slice(composer.indexOf('fn chatComposerPaintBuffered('), composer.indexOf('fn chatComposerSubclassCore('));
  const backgroundFill = /    const background = CreateSolidBrush\(app_state\.g_chat_input_color\) orelse return false;\s*defer _ = DeleteObject\(background\);\s*if \(FillRect\(dc, &client, background\) == 0\) return false;\n/;
  const fullClientPaint = /GetClientRect\(hwnd, &client\)[\s\S]*?SelectObject\(dc, bitmap\);\s*defer _ = SelectObject\(dc, old_bitmap\);\s*const background = CreateSolidBrush\(app_state\.g_chat_input_color\) orelse return false;\s*defer _ = DeleteObject\(background\);\s*if \(FillRect\(dc, &client, background\) == 0\) return false;\s*_ = CallWindowProcW\(app_state\.g_chat_composer_orig_proc, hwnd, 0x0318, @intFromPtr\(dc\), 4\);/;
  assert.match(buffered, fullClientPaint);
  const broken = buffered.replace(backgroundFill, '');
  assert.notEqual(broken, buffered);
  assert.throws(() => assert.match(broken, fullClientPaint), assert.AssertionError);
});
