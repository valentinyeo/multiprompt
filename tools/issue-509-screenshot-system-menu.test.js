const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = name => fs.readFileSync(path.join(__dirname, '..', 'src', name + '.zig'), 'utf8');
const render = read('chat_render');
const start = render.indexOf('pub fn shotFocusTick() void {');
const end = render.indexOf('\npub fn paintChatAttachButton(', start);
assert.ok(start >= 0 && end > start, 'screenshot focus handoff must exist');
const handoff = render.slice(start, end);

function auditAltSequence(source) {
  const events = [...source.matchAll(/keybd_event\(([^)]*)\);/g)].map(match => match[1]);
  assert.deepEqual(events, [
    'VK_MENU, 0, 0, 0',
    '0xFF, 0, 0, 0',
    '0xFF, 0, KEYEVENTF_KEYUP, 0',
    'VK_MENU, 0, KEYEVENTF_KEYUP, 0',
  ]);
}

test('ISSUE-509 screenshot focus never releases a bare synthetic Alt tap', () => {
  auditAltSequence(handoff);
  for (const event of ['keybd_event(0xFF, 0, 0, 0);', 'keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);']) {
    assert.throws(() => auditAltSequence(handoff.replace(event, '')));
  }
});

function auditComposerHandoff(source) {
  assert.match(source, /keybd_event\(VK_MENU, 0, 0, 0\);\s*const foreground_ok = if \(chat\) SetForegroundWindow\(app_state\.g_main_hwnd\) else activateConsoleForeground\(target\);\s*keybd_event\(0xFF, 0, 0, 0\);\s*keybd_event\(0xFF, 0, KEYEVENTF_KEYUP, 0\);\s*keybd_event\(VK_MENU, 0, KEYEVENTF_KEYUP, 0\);\s*_ = SetFocus\(target\);/);
  assert.match(source, /if \(chat\) \{\s*const caret = app_state\.g_shot_focus\.caret\.\?;\s*_ = SendMessageW\(target, 0x00B1, caret, @intCast\(caret\)\);\s*_ = SendMessageW\(target, 0x00B7, 0, 0\);/);
  assert.match(source, /waiting for screenshot modifiers to release/);
  assert.match(source, /AttachThreadInput\(our_tid, target_tid, 1\)/);
  assert.match(source, /AttachThreadInput\(our_tid, fg_tid, 1\)/);
}

test('ISSUE-509 menu-safe activation preserves composer focus and the post-link caret', () => {
  auditComposerHandoff(handoff);
  assert.throws(() => auditComposerHandoff(handoff.replace('keybd_event(0xFF, 0, 0, 0);', '')));
  assert.throws(() => auditComposerHandoff(handoff.replace('_ = SetFocus(target);', '')));
  assert.throws(() => auditComposerHandoff(handoff.replace('0x00B1, caret, @intCast(caret)', '0x00B1, 0, 0')));
  const insert = render.slice(render.indexOf('pub fn chatComposerInsertAtCaret('), render.indexOf('pub fn requestShotFocus('));
  assert.match(insert, /chat_image_insert\.plan\(/);
  assert.match(insert, /0x00B1, insert\.caret, @intCast\(insert\.caret\)/);
  assert.match(read('chat_image_insert'), /out\[len - 1\] = ' ';/);
  assert.match(read('chat_image_insert'), /\.caret = start \+ len/);
  assert.match(read('clipboard'), /chatComposerInsertAtCaret\(text\[0\.\.local_len\]\)\) \|caret\|[^]*?if \(user_initiated\) requestShotFocus\(idx, caret\);/);
});
