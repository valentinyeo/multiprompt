const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

const repaintLoggers = {
  logChatCodeFont: 'logs when the code font is rebuilt',
  chatTableLayoutIn: 'logs only when a table layout is built',
  chatShellSyncBuild: 'logs only when the shell view changed',
  chatChoicesLog: 'logs only when the choice hash changed',
  chatPaintReadDivider: 'goes through the paint log rule in diagnostics',
  chatPaintTranscriptContent: 'logs the missing history note once',
};

const eventLoggers = new Set([
  'chatWheelScroll', 'chatLogScrollUi', 'requestShotFocus', 'shotFocusTick',
  'chatMessageMenu', 'chatReplyJump', 'chatReplyResolve', 'chatTranscriptWndProc',
]);

function debugLogFunctions(source) {
  const found = {};
  let current = '';
  for (const line of source.split('\n')) {
    const header = line.match(/^(?:pub )?fn (\w+)\(/);
    if (header) current = header[1];
    if (/\bdebugLog\(/.test(line) && !/^const /.test(line)) found[current] = (found[current] || 0) + 1;
  }
  return found;
}

test('IGSH-1973 chat rendering never logs from a paint pass unless the log is gated', () => {
  const render = read('src/chat_render.zig');
  assert.doesNotMatch(render, /CHAT_LIST/);
  for (const name of Object.keys(debugLogFunctions(render))) {
    assert.ok(name in repaintLoggers || eventLoggers.has(name), `${name} logs from chat_render.zig: gate it in diagnostics.zig or list it as event driven`);
  }
});

test('IGSH-1973 the list cache that only existed to log once per list is gone', () => {
  const markdown = read('src/chat_markdown.zig');
  const cache = markdown.slice(markdown.indexOf('pub const TableCache = struct'), markdown.indexOf('pub fn layout(self: *TableCache'));
  assert.doesNotMatch(cache, /lists/);
  assert.doesNotMatch(cache, /pub fn list\(/);
  assert.doesNotMatch(read('src/chat_render.zig'), /g_chat_tables\.list\(/);
});

test('IGSH-1973 every repeating diagnostic line is deduplicated with a heartbeat', () => {
  const diagnostics = read('src/diagnostics.zig');
  const rules = diagnostics.slice(diagnostics.indexOf('fn paintLogRule('), diagnostics.indexOf('fn paintLogAllowed('));
  for (const prefix of ['[chat] unread divider ', 'PERF[chat]: ', 'browser-freeze-state: now=', '[chat-live] page ', '[chat-live] draw ', '[focus-trace] event=blocked ', '[altq] composer_focus ', '[bt ']) {
    assert.ok(rules.includes(`"${prefix}"`), `paintLogRule must cover ${prefix}`);
  }
  assert.match(rules, /"receive to paint"\)\) return null/);
  assert.match(diagnostics, /if \(paintLogRule\(msg\)\) \|rule\| \{\s*if \(!paintLogAllowed\(rule\)\) return;/);
  assert.match(diagnostics, /\(heartbeat_ms == 0 or now -\| entry\.at < heartbeat_ms\)/);
});

test('IGSH-1973 the repeating lines are still emitted by their owners so the rules stay live', () => {
  assert.match(read('src/chat_render.zig'), /\[chat\] unread divider count=/);
  assert.match(read('src/chat_session.zig'), /"PERF\[chat\]: \{s\} ms=\{d\} size=\{d\}"/);
  assert.match(read('src/chat_session.zig'), /"\[chat-live\] \{s\} shell=\{d\} n=\{d\} f=\{d\}"/);
  assert.match(read('src/browser_pane.zig'), /"browser-freeze-state: now=\{d\} active=\{d\}/);
  assert.match(read('src/diagnostics.zig'), /"\[focus-trace\] event=\{s\} caller=/);
});

test('IGSH-1973 slow call lines need more than one clock tick', () => {
  const diagnostics = read('src/diagnostics.zig');
  const slow = diagnostics.slice(diagnostics.indexOf('pub fn logSlowMs('), diagnostics.indexOf('pub fn logPollShellEnter('));
  const floor = diagnostics.match(/const SLOW_CALL_LOG_MS: u64 = (\d+);/);
  assert.ok(floor && Number(floor[1]) >= 20, 'the slow call floor must sit above the 16 ms clock tick');
  assert.match(slow, /if \(elapsed < SLOW_CALL_LOG_MS\) return;/);
});
