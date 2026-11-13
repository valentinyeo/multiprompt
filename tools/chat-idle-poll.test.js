const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const session = fs.readFileSync(path.join(root, 'src', 'chat_session.zig'), 'utf8');

function body(source, name) {
  const header = new RegExp(`^( *)(?:pub )?fn ${name}\\([^\\n]*\\) [^\\n{]+\\{\\n`, 'm').exec(source);
  assert.ok(header, name);
  const start = header.index + header[0].length;
  const end = source.indexOf(`\n${header[1]}}`, start);
  assert.ok(end > start, name);
  return source.slice(start, end);
}

function pollInterval() {
  const match = /fn chatFilePollInterval\(\) u64 \{\n\s*return (\d+);/.exec(session);
  assert.ok(match, 'chatFilePollInterval');
  return Number(match[1]);
}

function nextDelay() {
  const code = body(session, 'chatHistoryNextDelay')
    .replace(/\band\b/g, '&&').replace(/\bor\b/g, '||')
    .replace(/\bchatFilePollInterval\(\)/g, String(pollInterval()));
  const run = new Function('disk', 'prepended', 'before', 'more', 'delivery', 'streaming', 'unchanged', 'background', code);
  return (state) => run(state.disk ?? false, state.prepended ?? false, state.before ?? 0, state.more ?? false, state.delivery ?? false, state.streaming ?? false, state.unchanged ?? false, state.background ?? false);
}

function pollsInOneMinute(delay, latency) {
  let clock = 0;
  let polls = 0;
  while (clock < 60_000) {
    polls += 1;
    clock += latency + delay();
  }
  return polls;
}

test('SOFT-1973 a background chat with a message waiting still backs off when the poll finds nothing new', () => {
  const delay = nextDelay();
  const waiting = delay({ delivery: true, unchanged: true, background: true });
  assert.ok(waiting >= 4000, `an empty poll waits at least four seconds, got ${waiting} ms`);
  assert.ok(pollsInOneMinute(() => waiting, 150) <= 15, 'a quiet chat with a waiting message is read at most 15 times a minute');
});

test('SOFT-1973 two quiet chats with waiting messages do not poll many times a second', () => {
  const delay = nextDelay();
  const quiet = () => delay({ delivery: true, unchanged: true, background: true });
  const total = 2 * pollsInOneMinute(quiet, 150);
  assert.ok(total <= 30, `two quiet chats poll ${total} times in a minute`);
});

test('SOFT-1973 a waiting message still gets fast polls while the chat is changing', () => {
  const delay = nextDelay();
  assert.equal(delay({ delivery: true, unchanged: false, background: true }), 250);
  assert.equal(delay({ delivery: true, unchanged: false, background: false }), 250);
});

test('SOFT-1973 the other delay branches keep their timings', () => {
  const delay = nextDelay();
  assert.equal(delay({ disk: true, unchanged: true, background: true }), 0);
  assert.equal(delay({ prepended: true }), 0);
  assert.equal(delay({ before: 1 }), 0);
  assert.equal(delay({ more: true, delivery: true }), 1000);
  assert.equal(delay({ streaming: true, unchanged: true, background: true }), 0);
  assert.equal(delay({ unchanged: true, background: true }), 4000);
  assert.equal(delay({ unchanged: true, background: false }), 500);
  assert.equal(delay({ unchanged: false, background: true }), 500);
});

test('SOFT-1973 the result handler feeds the delay from the unchanged flag and repaints nothing for an empty poll', () => {
  const ready = body(session, 'chatFileOnReady');
  assert.match(ready, /chatHistoryNextDelay\(disk, entry\.prepended, entry\.before, history\.more, chatDeliveryPending\(entry\.key\.shell_id, false\), entry\.stream != null, entry\.unchanged,/);
  assert.match(ready, /active_changed = active_changed or !entry\.unchanged or history\.revision != app_state\.g_chat_last_hash;/);
  assert.match(ready, /if \(preview_changed\) \{\n\s+@import\("window_layout\.zig"\)\.invalidateSidebar\(\);/);
});
