const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const read = name => (fs.existsSync(path.join(root, name)) ? fs.readFileSync(path.join(root, name), 'utf8') : '');
const sources = fs.readdirSync(path.join(root, 'src')).filter(name => name.endsWith('.zig'));
const fnBody = (text, signature) => {
  const start = text.indexOf(signature);
  assert.ok(start >= 0, `${signature} missing`);
  const end = text.indexOf('\n}\n', start);
  return text.slice(start, end);
};

test('only one place posts the chat file ready message', () => {
  const posts = [];
  for (const name of sources) {
    const text = read(`src/${name}`);
    for (const match of text.matchAll(/PostMessageW\([^;]*WM_APP_CHAT_FILE_READY/g)) posts.push(`${name}: ${match[0]}`);
  }
  assert.equal(posts.length, 1, posts.join('\n'));
  assert.match(posts[0], /^win32\.zig:/);
});

test('producers ask the gate and only the first request posts', () => {
  const win32 = read('src/win32.zig');
  assert.match(fnBody(win32, 'pub fn postChatFileReady('), /if \(g_chat_file_ready\.request\(\)\) postChatFileReadyNow\(hwnd\);/);
  assert.match(fnBody(win32, 'fn postChatFileReadyNow('), /PostMessageW\(hwnd, WM_APP_CHAT_FILE_READY, 0, 0\) == 0\) g_chat_file_ready\.failed\(\)/);
  for (const name of ['chat_session.zig', 'native_session.zig']) {
    const text = read(`src/${name}`);
    assert.match(text, /postChatFileReady\(/, name);
    assert.doesNotMatch(text, /PostMessageW\([^;]*WM_APP_CHAT_FILE_READY/, name);
  }
});

test('work that arrives while the handler runs waits on a timer so paint and input run first', () => {
  const win32 = read('src/win32.zig');
  const finish = fnBody(win32, 'pub fn chatFileReadyFinish(');
  assert.match(finish, /if \(!g_chat_file_ready\.finish\(\)\) return;/);
  assert.match(finish, /SetTimer\(hwnd, TIMER_CHAT_FILE_READY, CHAT_FILE_READY_GAP_MS, null\)/);
  assert.doesNotMatch(finish, /PostMessageW/);
  const timer = fnBody(win32, 'pub fn chatFileReadyTimer(');
  assert.match(timer, /KillTimer\(hwnd, TIMER_CHAT_FILE_READY\)/);
  assert.match(timer, /postChatFileReadyNow\(hwnd\)/);
  assert.match(win32, /const CHAT_FILE_READY_GAP_MS: UINT = \d+;/);
  const ids = [...win32.matchAll(/pub const TIMER_\w+: usize = (\d+);/g)].map(m => m[1]);
  const mine = win32.match(/pub const TIMER_CHAT_FILE_READY: usize = (\d+);/)[1];
  assert.equal(ids.filter(id => id === mine).length, 1, 'timer id must be unique');
});

test('the gate holds the post until the handler finishes', () => {
  const gate = read('src/coalesced_post.zig');
  assert.match(fnBody(gate, 'pub fn request('), /dirty\.store\(true, \.release\);\s*return !self\.outstanding\.swap\(true, \.acq_rel\);/);
  assert.match(fnBody(gate, 'pub fn begin('), /dirty\.store\(false, \.release\)/);
  const finish = fnBody(gate, 'pub fn finish(');
  assert.ok(finish.indexOf('outstanding.store(false') < finish.indexOf('dirty.load'));
  assert.match(finish, /return !self\.outstanding\.swap\(true, \.acq_rel\)/);
});

test('the window procedure begins and finishes before any early return', () => {
  const main = read('src/main.zig');
  const start = main.indexOf('fn wndProc(');
  const locked = main.indexOf('g_account_locked', start);
  const timer = main.indexOf('chatFileReadyTimer(hwnd)', start);
  const begin = main.indexOf('chatFileReadyBegin()', start);
  const finish = main.indexOf('chatFileReadyFinish(hwnd)', start);
  const handler = main.indexOf('WM_APP_CHAT_FILE_READY =>', start);
  assert.ok(start > 0 && timer > start && begin > start && finish > start, 'wndProc wiring missing');
  assert.ok(locked < 0 || (timer < locked && begin < locked && finish < locked), 'gate calls must precede the account lock check');
  assert.ok(handler < 0 || (begin < handler && finish < handler), 'gate calls must precede the handler');
  assert.match(main.slice(finish - 120, finish), /defer if \(msg == WM_APP_CHAT_FILE_READY\)/);
  assert.match(main, /_ = @import\("coalesced_post\.zig"\);/);
});
