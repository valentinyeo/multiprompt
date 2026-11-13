const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = (name) => fs.readFileSync(path.join(root, 'src', name), 'utf8');
const session = read('chat_session.zig');
const send = read('chat_send.zig');
const echo = read('chat_echo.zig');

function find(source, name) {
  return new RegExp(`^( *)(?:pub )?fn ${name}\\(([^\\n]*)\\) [^\\n{]+\\{\\n`, 'm').exec(source);
}

function body(source, name) {
  const header = find(source, name);
  assert.ok(header, name);
  const start = header.index + header[0].length;
  const end = source.indexOf(`\n${header[1]}}`, start);
  assert.ok(end > start, name);
  return source.slice(start, end);
}

function toJs(code) {
  return code
    .replace(/return if \((.*?)\) (\S+) else (.*?);/g, 'return ($1) ? $2 : $3;')
    .replace(/\band\b/g, '&&').replace(/\bor\b/g, '||')
    .replace(/!= \.(\w+)/g, '!== "$1"').replace(/== \.(\w+)/g, '=== "$1"')
    .replace(/\(\.(\w+),/g, '("$1",')
    .replace(/chat_echo\./g, '');
}

function compile(source, name, scope = {}) {
  const header = find(source, name);
  if (!header) return null;
  const params = header[2].split(',').map((p) => p.trim().split(':')[0].trim()).filter(Boolean);
  const names = Object.keys(scope);
  return new Function(...names, `return function(${params.join(', ')}) {${toJs(body(source, name))}};`)(...names.map((n) => scope[n]));
}

const pendingExpired = compile(echo, 'pendingExpired');
const drivesPollingZig = compile(echo, 'drivesPolling', { pendingExpired });
const drivesPolling = drivesPollingZig || (() => true);

function nextDelayFn() {
  const poll = /fn chatFilePollInterval\(\) u64 \{\n\s*return (\d+);/.exec(session);
  assert.ok(poll, 'chatFilePollInterval');
  const backoff = compile(session, 'chatQuietBackoff');
  const source = body(session, 'chatHistoryNextDelay').replace(/\bchatFilePollInterval\(\)/g, poll[1]);
  const header = find(session, 'chatHistoryNextDelay');
  const params = header[2].split(',').map((p) => p.trim().split(':')[0].trim());
  const run = new Function('chatQuietBackoff', ...params, toJs(source));
  return (s) => run(backoff, ...params.map((p) => s[p] ?? (p === 'quiet' || p === 'before' ? 0 : false)));
}

function guard(code, pattern) {
  const match = pattern.exec(code);
  assert.ok(match, `${pattern}`);
  return match;
}

const SETTLE_REQUEST = /^\s*(?:if \((.*)\) )?@import\("chat_session\.zig"\)\.chatFileRequestForDelivery\(key, true\);$/m;

function settleFetches(entry, now) {
  const match = guard(body(send, 'chatTmuxSettle'), SETTLE_REQUEST);
  if (!match[1]) return true;
  return new Function('entry', 'now_ms', 'drivesPolling', `return ${toJs(match[1])};`)(entry, now, drivesPolling);
}

function timerOn(outbox, now, chatActive) {
  const arm = body(send, 'armChatOutboxTimerIfNeeded');
  const cond = guard(arm, /if \((app_state\.g_chat_active or [^\n]*)\) \{\n\s+if \(!app_state\.g_chat_outbox_timer_on\)/)[1]
    .replace('app_state.g_chat_active', 'chatActive')
    .replace('app_state.g_chat_pending_reset != null', 'false')
    .replace('app_state.g_chat_outbox.items.len > 0', 'outbox.length > 0')
    .replace('chatOutboxNeedsTick()', 'needsTick()')
    .replace(/app_state\.g_[a-z_]+ != null/g, 'false');
  const needsTick = () => outbox.some((e) => e.message_v1 || drivesPolling(e.state, e.channel_pending, e.transcript_queued, e.sent_tick_ms, now));
  return new Function('chatActive', 'outbox', 'needsTick', `return ${toJs(cond)};`)(chatActive, outbox, needsTick);
}

function deliveryFlag(outbox, now) {
  const ready = body(session, 'chatFileOnReady');
  const aware = /chatPollingPending\(entry\.key\.shell_id\)/.test(ready);
  return outbox.some((e) => e.channel_sent && e.state !== 'not_sent' && (!aware || drivesPolling(e.state, e.channel_pending, e.transcript_queued, e.sent_tick_ms, now)));
}

function hiddenFetches({ outbox, chatActive, minutes }) {
  const delay = nextDelayFn();
  const latency = 150;
  let now = 1_000_000;
  const end = now + minutes * 60_000;
  let next = 0;
  let quiet = 0;
  let fetches = 0;
  let nextWarm = now;
  while (now < end) {
    const settle = timerOn(outbox, now, chatActive) && outbox.some((e) => e.channel_sent && !e.message_v1 && !e.channel_pending && (e.state === 'delivered' || e.state === 'not_sent') && settleFetches(e, now));
    const warm = now >= nextWarm;
    if (warm) nextWarm = now + 750;
    if ((settle || warm) && now >= next) {
      fetches += 1;
      quiet += 1;
      const done = now + latency;
      next = done + delay({ delivery: deliveryFlag(outbox, done), unchanged: true, background: true, quiet: quiet - 1 });
    }
    now += 250;
  }
  return fetches;
}

const staleHeld = () => ({ state: 'delivered', channel_sent: true, channel_pending: false, transcript_queued: false, message_v1: false, host_held: true, sent_tick_ms: 100_000 });

test('SOFT-1973 a delivered message older than the delivery window stops driving transcript polling', () => {
  assert.ok(drivesPollingZig, 'drivesPolling exists');
  const now = 10_000_000;
  assert.equal(drivesPolling('delivered', false, false, now - 60_000, now), true);
  assert.equal(drivesPolling('delivered', false, false, now - 599_999, now), true);
  assert.equal(drivesPolling('delivered', false, false, now - 600_000, now), false);
  assert.equal(drivesPolling('not_sent', false, false, now - 3_600_000, now), false);
  assert.equal(drivesPolling('delivered', true, false, now - 3_600_000, now), true);
  assert.equal(drivesPolling('delivered', false, true, now - 3_600_000, now), true);
  assert.equal(drivesPolling('sending', false, false, now - 3_600_000, now), true);
});

test('SOFT-1973 an old held message loaded soon after Windows boot still stops driving polling', () => {
  assert.ok(drivesPollingZig, 'drivesPolling exists');
  const now = 300_000;
  const loaded = { ...staleHeld(), sent_tick_ms: now - 600_000 };
  assert.equal(drivesPolling(loaded.state, false, false, loaded.sent_tick_ms, now), false);
  assert.equal(timerOn([loaded], now, false), false);
  assert.equal(settleFetches(loaded, now), false);
  assert.equal(drivesPolling('delivered', false, false, 0, 2_000_000), false);
});

test('SOFT-1973 a quiet hidden chat with an old held message fetches almost nothing in ten minutes', () => {
  const fetches = hiddenFetches({ outbox: [staleHeld()], chatActive: false, minutes: 10 });
  assert.ok(fetches <= 25, `a quiet hidden chat was fetched ${fetches} times in ten minutes`);
});

test('SOFT-1973 the same chat stays quiet while another chat is open and the outbox timer runs', () => {
  const fetches = hiddenFetches({ outbox: [staleHeld()], chatActive: true, minutes: 10 });
  assert.ok(fetches <= 25, `a quiet hidden chat was fetched ${fetches} times in ten minutes`);
});

test('SOFT-1973 an old held message alone does not keep the outbox timer running', () => {
  assert.equal(timerOn([staleHeld()], 1_000_000, false), false);
  assert.equal(timerOn([{ ...staleHeld(), sent_tick_ms: 990_000 }], 1_000_000, false), true);
  assert.equal(timerOn([{ ...staleHeld(), state: 'queued', channel_sent: false }], 1_000_000, false), true);
});

test('SOFT-1973 a fresh delivered message is still polled quickly until it settles', () => {
  const fresh = { ...staleHeld(), sent_tick_ms: 990_000, host_held: false };
  const now = 1_000_000;
  assert.equal(timerOn([fresh], now, false), true);
  assert.equal(settleFetches(fresh, now), true);
  assert.equal(nextDelayFn()({ delivery: true, unchanged: false, background: true }), 250);
});

test('SOFT-1973 an empty poll of a hidden chat backs off and a live chat keeps its pace', () => {
  const delay = nextDelayFn();
  const hidden = (quiet) => delay({ unchanged: true, background: true, quiet });
  assert.equal(hidden(0), 4000);
  assert.ok(hidden(1) > hidden(0), 'second empty poll waits longer');
  assert.ok(hidden(2) > hidden(1), 'third empty poll waits longer');
  assert.ok(hidden(50) >= 30_000, 'a long quiet spell is read at most twice a minute');
  assert.equal(hidden(50) <= 60_000, true);
  assert.equal(delay({ unchanged: true, background: false, quiet: 50 }), 500);
  assert.equal(delay({ unchanged: false, background: true, quiet: 50 }), 500);
});

test('SOFT-1973 the other delay branches keep their timings', () => {
  const delay = nextDelayFn();
  assert.equal(delay({ disk: true, unchanged: true, background: true }), 0);
  assert.equal(delay({ prepended: true }), 0);
  assert.equal(delay({ before: 1 }), 0);
  assert.equal(delay({ more: true, delivery: true }), 1000);
  assert.equal(delay({ streaming: true, unchanged: true, background: true }), 0);
  assert.equal(delay({ delivery: true, unchanged: true, background: true }), 4000);
  assert.equal(delay({ delivery: true, unchanged: true, background: false }), 500);
});

test('SOFT-1973 the result handler repaints nothing for an empty poll and a chat that becomes live is read at once', () => {
  const ready = body(session, 'chatFileOnReady');
  assert.match(ready, /active_changed = active_changed or !entry\.unchanged or history\.revision != app_state\.g_chat_last_hash;/);
  assert.match(ready, /if \(preview_changed\) \{\n\s+@import\("window_layout\.zig"\)\.invalidateSidebar\(\);/);
  const request = body(session, 'chatFileRequestForDelivery');
  assert.match(request, /key\.shell_id == live_shell_id and entry\.quiet > 0\) \{\n\s+entry\.quiet = 0;\n\s+entry\.next = @min\(entry\.next, now\);/);
});
