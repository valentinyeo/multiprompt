const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const sources = fs.readdirSync(path.join(root, 'src')).filter(name => name.endsWith('.zig'));

test('only one place posts the chat file ready message', () => {
  const posts = [];
  for (const name of sources) {
    const text = read(`src/${name}`);
    for (const match of text.matchAll(/PostMessageW\([^;]*WM_APP_CHAT_FILE_READY/g)) posts.push(`${name}: ${match[0]}`);
  }
  assert.equal(posts.length, 1, posts.join('\n'));
  assert.match(posts[0], /^win32\.zig:/);
});

test('the helper posts once until the main thread takes the message', () => {
  const win32 = read('src/win32.zig');
  const start = win32.indexOf('pub fn postChatFileReady(');
  const end = win32.indexOf('pub fn chatFileReadyDelivered(');
  assert.ok(start > 0 && end > start);
  const post = win32.slice(start, end);
  assert.match(post, /if \(g_chat_file_ready_pending\.swap\(true, \.acq_rel\)\) return;/);
  assert.match(post, /PostMessageW\(hwnd, WM_APP_CHAT_FILE_READY, 0, 0\) == 0\) g_chat_file_ready_pending\.store\(false, \.release\)/);
  assert.match(win32, /pub fn chatFileReadyDelivered\(\) void \{\s*g_chat_file_ready_pending\.store\(false, \.release\);/);
});

test('every producer goes through the helper', () => {
  const chat = read('src/chat_session.zig');
  const calls = chat.match(/win32\.zig"\)\.postChatFileReady\(app_state\.g_main_hwnd\)/g) || [];
  assert.equal(calls.length, 5);
  assert.match(read('src/native_session.zig'), /w\.postChatFileReady\(main\)/);
});

test('the window procedure clears the flag before any early return', () => {
  const main = read('src/main.zig');
  const start = main.indexOf('fn wndProc(');
  const clear = main.indexOf('chatFileReadyDelivered()', start);
  const locked = main.indexOf('g_account_locked', start);
  const handler = main.indexOf('WM_APP_CHAT_FILE_READY =>', start);
  assert.ok(start > 0 && clear > start, 'clear call missing');
  assert.ok(locked < 0 || clear < locked, 'clear must precede the account lock check');
  assert.ok(handler < 0 || clear < handler, 'clear must precede the handler');
});
