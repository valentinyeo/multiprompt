const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_send.zig'), 'utf8');
const state = fs.readFileSync(path.join(root, 'src/app_state.zig'), 'utf8');
const WALL_MS = 1792250528437;

function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, name);
  const end = source.indexOf('\n}', start);
  assert.notEqual(end, -1, name);
  return source.slice(start, end + 2);
}

function reducerFrom(zig) {
  let code = zig.slice(zig.indexOf('{') + 1, zig.lastIndexOf('}'));
  const messageLine = 'const message = if (wrapped == .null) value else wrapped;';
  assert.ok(code.includes(messageLine));
  code = code.replace(messageLine, 'const message = wrapped === null ? value : wrapped;');
  code = code.replace(/const (token|phase) = (.*) orelse return true;/g, 'const $1 = $2 ?? null; if ($1 === null) return true;');
  code = code
    .replace('const wall_ms = chat_echo.fileTimeToUnixMs(nowFileTime());', `const wall_ms = ${WALL_MS};`)
    .replace('entry.anchor.sent_ms = chatMessageSentMs(message, wall_ms);', 'entry.anchor.sent_ms = Number.isFinite(message.created) && message.created > 0 ? message.created * 1000 : wall_ms;')
    .replace('entry.sent_tick_ms = @as(i64, @intCast(GetTickCount64())) - std.math.clamp(wall_ms -| entry.anchor.sent_ms, 0, 600_000);', 'entry.sent_tick_ms = 1234 - Math.max(0, Math.min(600000, wall_ms - entry.anchor.sent_ms));')
    .replace('entry.expires_ms = entry.anchor.sent_ms +| 600_000;', 'entry.expires_ms = entry.anchor.sent_ms + 600000;')
    .replace('var key_buf: [CHAT_OUTBOX_KEY_CAP]u8 = undefined;', 'const key_buf = null;')
    .replace('chatOutboxKeyForShell(idx, &key_buf)', 'chatOutboxKeyForShell(idx, key_buf)')
    .replace('var found: ?usize = null;', 'let found = null;')
    .replace('var adopted = false;', 'let adopted = false;')
    .replace('chatOutboxRemoveAtIn(&app_state.g_chat_outbox, std.heap.page_allocator, found.?);', 'chatOutboxRemoveAtIn(app_state.g_chat_outbox, found);')
    .replaceAll('chat_echo.fileTimeToUnixMs(nowFileTime())', String(WALL_MS))
    .replace('for (app_state.g_chat_outbox.items, 0..) |entry, i| {', 'for (const [i, entry] of app_state.g_chat_outbox.items.entries()) {')
    .replace('for (app_state.g_chat_confirmed.items) |c| {', 'for (const c of app_state.g_chat_confirmed.items) {')
    .replaceAll('std.mem.eql(u8, entry.key[0..entry.key_len], key)', 'entry.key === key')
    .replaceAll('std.mem.eql(u8, c.key[0..c.key_len], key)', 'c.key === key')
    .replaceAll('std.mem.eql(u8, &entry.message_sid, &identity.sid)', 'entry.message_sid === identity.sid')
    .replaceAll('std.mem.eql(u8, &c.message_sid, &identity.sid)', 'c.message_sid === identity.sid')
    .replaceAll('std.mem.eql(u8, std.mem.sliceTo(&entry.message_wire_id, 0), token)', 'entry.message_wire_id === token')
    .replaceAll('std.mem.eql(u8, std.mem.sliceTo(&c.message_wire_id, 0), token)', 'c.message_wire_id === token')
    .replaceAll('std.mem.eql(u8, std.mem.sliceTo(&entry.message_phase, 0), "started")', 'entry.message_phase === "started"')
    .replace('const origin = json_reader.string(json_reader.field(message, "origin")) orelse "";', 'const origin = json_reader.string(json_reader.field(message, "origin")) ?? "";')
    .replace('if (std.mem.eql(u8, origin, "agent")) return true;', 'if (origin === "agent") return true;')
    .replaceAll('std.mem.eql(u8, phase, "', 'equal(phase, "')
    .replaceAll('app_state.shells[idx].ai_agent', '(idx.agent ?? 1)')
    .replaceAll('token.len', 'token.length')
    .replaceAll(' and ', ' && ')
    .replaceAll(' or ', ' || ')
    .replace('if (found) |i| chatOutboxRemoveAtIn(&app_state.g_chat_outbox, std.heap.page_allocator, i);', 'if (found !== null) chatOutboxRemoveAtIn(app_state.g_chat_outbox, found);')
    .replace('const text = json_reader.string(json_reader.field(message, "text")) orelse return false;', 'const text = json_reader.string(json_reader.field(message, "text")); if (text === null) return false;')
    .replace('const wide = std.unicode.utf8ToUtf16LeAlloc(std.heap.page_allocator, text) catch return false;', 'const wide = text;')
    .replace('defer std.heap.page_allocator.free(wide);', '')
    .replace('chatOutboxEnqueueInStateLimit(&app_state.g_chat_outbox, std.heap.page_allocator, key, wide, .queued, false)', 'chatOutboxEnqueueInStateLimit(app_state.g_chat_outbox, key, wide)')
    .replaceAll('app_state.g_chat_outbox.items.len', 'app_state.g_chat_outbox.items.length')
    .replaceAll('&app_state.g_chat_outbox.items[found.?]', 'app_state.g_chat_outbox.items[found]')
    .replace('_ = json_reader.copyString(message, "id", &entry.message_wire_id);', 'json_reader.copyString(message, "id", entry, "message_wire_id");')
    .replace('_ = json_reader.copyString(message, "state", &entry.message_phase);', 'json_reader.copyString(message, "state", entry, "message_phase");')
    .replace('entry.state = if (equal(phase, "failed")) .not_sent else if (equal(phase, "accepted") || equal(phase, "started")) .delivered else .queued;', 'entry.state = equal(phase, "failed") ? "not_sent" : equal(phase, "accepted") || equal(phase, "started") ? "delivered" : "queued";')
    .replace('entry.state = if (equal(phase, "failed")) .not_sent else .queued;', 'entry.state = equal(phase, "failed") ? "not_sent" : "queued";');
  return new Function('idx', 'value', 'app_state', 'json_reader', 'chatOutboxKeyForShell', 'chatFileIdentityForShell', 'chatOutboxRemoveAtIn', 'chatOutboxEnqueueInStateLimit', 'chatMessageFromAgent', 'equal', 'chat_echo', code);
}

function harness(zig = body('chatMessageReduce')) {
  const app = { g_chat_outbox: { items: [] }, g_chat_confirmed: { items: [] } };
  const reduce = reducerFrom(zig);
  return {
    app,
    send: (shell, value) => reduce(shell, value, app, {
      field: (object, field) => object && object[field] !== undefined ? object[field] : null,
      string: value => typeof value === 'string' ? value : null,
      copyString: (object, field, entry, target) => { entry[target] = object[field]; },
    }, shell => shell.key, shell => ({ sid: shell.sid }), (outbox, i) => outbox.items.splice(i, 1), (outbox, key, text) => { outbox.items.push({ key, text, anchor: {sent_ms: 0} }); return true; }, message => message.origin === 'agent', (a, b) => a === b, {
      snapshotRowFresh: (state, sent_ms, now_ms) => {
        if (state === 'delivered' || state === 'cancelled' || sent_ms <= 0) return false;
        if (now_ms < sent_ms) return true;
        return now_ms - sent_ms < 600000;
      },
    }),
  };
}

test('IGSH-1900 an agent message is never adopted as his own unsent message', () => {
  const h = harness();
  const shell = { key: 'tab-a', sid: 'session-a' };
  for (const state of ['queued', 'sent', 'failed']) {
    assert.equal(h.send(shell, { id: 'mp-ada6c782898f406ea2eafc77bd8648da', text: 'Fleet idle alarm', state, origin: 'agent' }), true);
    assert.equal(h.app.g_chat_outbox.items.length, 0, `an agent ${state} message became his draft`);
  }
  assert.equal(h.send(shell, { id: 'desktop-0123456789abcdef', text: 'mine', state: 'failed', origin: 'human' }), true);
  assert.equal(h.app.g_chat_outbox.items.length, 1);
  assert.equal(h.app.g_chat_outbox.items[0].state, 'not_sent');
  assert.equal(h.send(shell, { id: 'desktop-0123456789abcdef01', text: 'older sender', state: 'queued' }), true);
  assert.equal(h.app.g_chat_outbox.items.length, 2);
});

test('merge-base reducer parses and retains its original terminal behavior', () => {
  const original = fs.readFileSync(path.join(root, 'tools/fixtures/IGSH-1692/base-reducer.zig'), 'utf8');
  const h = harness(original);
  const shell = { key: 'tab-a', sid: 'session-a' };
  const message = { id: 'base', text: 'waiting', state: 'queued' };
  assert.equal(h.send(shell, message), true);
  assert.equal(h.send(shell, { ...message, state: 'accepted' }), true);
  assert.equal(h.app.g_chat_outbox.items.length, 0);
});

test('confirmation stores identity at every transcript claim', () => {
  const add = body('chatConfirmedAdd');
  const confirmedStruct = state.slice(state.indexOf('pub const ChatConfirmedEcho = struct {'), state.indexOf('\n};', state.indexOf('pub const ChatConfirmedEcho = struct {')));
  for (const field of ['message_sid', 'message_wire_id']) {
    assert.match(confirmedStruct, new RegExp(`\\b${field}:`));
    assert.match(add, new RegExp(`c\\.${field} = e\\.${field};`));
  }
  assert.match(body('chatEchoConfirmWithBlock'), /chatConfirmedAdd\(key_copy\[0\.\.klen\], e\.text, block, e\);/);
  assert.match(body('chatEchoMatchActive'), /chatConfirmedAdd\(key_copy\[0\.\.e\.key_len\], e\.text, app_state\.g_chat_blocks\[mi\], e\);/);
  assert.match(source, /chatConfirmedAdd\(entry\.key\[0\.\.entry\.key_len\], entry\.text, block, entry\.\*\);/);
  assert.equal((source.match(/chatConfirmedAdd\(/g) || []).length, 4);
});

test('production reducer without replay guard recreates confirmed messages', () => {
  const original = body('chatMessageReduce');
  const withoutGuard = original.replace(/        for \(app_state\.g_chat_confirmed\.items\) \|c\| \{\n            if .* return true;\n        \}\n/, '');
  const h = harness(withoutGuard);
  const shell = { key: 'tab-a', sid: 'session-a' };
  const message = { id: 'wire-0', text: 'same text', state: 'queued' };
  assert.equal(h.send(shell, message), true);
  h.app.g_chat_confirmed.items.push(h.app.g_chat_outbox.items.shift());
  assert.equal(h.send(shell, message), true);
  assert.equal(h.app.g_chat_outbox.items.length, 1);
});

test('busy accepted message remains visible until taken', () => {
  const h = harness();
  const shell = { key: 'tab-a', sid: 'session-a' };
  const message = { id: 'wire-waiting', text: 'waiting message', state: 'queued' };
  assert.equal(h.send(shell, message), true);
  assert.equal(h.send(shell, { ...message, state: 'accepted' }), true);
  assert.equal(h.app.g_chat_outbox.items.length, 1);
  assert.equal(h.app.g_chat_outbox.items[0].message_phase, 'accepted');
  assert.equal(h.app.g_chat_outbox.items[0].state, 'delivered');
  assert.equal(h.send(shell, { ...message, state: 'accepted' }), true);
  assert.equal(h.app.g_chat_outbox.items.length, 1);
  assert.equal(h.send(shell, { ...message, state: 'started' }), true);
  assert.equal(h.app.g_chat_outbox.items.length, 1);
  assert.equal(h.app.g_chat_outbox.items[0].message_phase, 'started');
  assert.equal(h.send(shell, { ...message, state: 'accepted' }), true);
  assert.equal(h.app.g_chat_outbox.items[0].message_phase, 'started');
  h.app.g_chat_outbox.items.shift();
  assert.equal(h.send(shell, { ...message, state: 'started' }), true);
  assert.equal(h.send(shell, { ...message, state: 'accepted' }), true);
  assert.equal(h.app.g_chat_outbox.items.length, 0);
});

test('terminal snapshots never create Claude echoes', () => {
  const h = harness();
  const shell = { key: 'tab-a', sid: 'session-a' };
  for (const state of ['accepted', 'started']) {
    assert.equal(h.send(shell, { id: 'old', text: 'same text', state }), true);
    assert.equal(h.app.g_chat_outbox.items.length, 0);
  }
});

test('non-Claude terminal states retain original removal behavior', () => {
  for (const agent of [2, 3]) for (const phase of ['accepted', 'started']) {
    const h = harness();
    const shell = { key: 'tab-a', sid: 'session-a', agent };
    const message = { id: 'wire-1', text: 'message', state: 'queued' };
    assert.equal(h.send(shell, message), true);
    assert.equal(h.send(shell, { ...message, state: phase }), true);
    assert.equal(h.app.g_chat_outbox.items.length, 0);
  }
});

test('production reducer ignores confirmed replays but accepts distinct messages', () => {
  const h = harness();
  const shell = { key: 'tab-a', sid: 'session-a' };
  const messages = Array.from({ length: 5 }, (_, i) => ({ id: `wire-${i}`, text: 'same text', state: 'queued' }));
  for (const message of messages) {
    assert.equal(h.send(shell, { message }), true);
    assert.equal(h.app.g_chat_outbox.items.length, 1);
    h.app.g_chat_confirmed.items.push(h.app.g_chat_outbox.items.shift());
  }
  for (const phase of ['queued', 'sent', 'failed']) {
    for (let repeat = 0; repeat < 2; repeat++) {
      for (const message of messages) assert.equal(h.send(shell, { ...message, state: phase }), true);
      assert.equal(h.app.g_chat_outbox.items.length, 0, `stale ${phase} snapshot recreated messages`);
    }
  }
  for (const [target, message] of [
    [shell, { ...messages[0], id: 'new-id' }],
    [{ ...shell, sid: 'session-b' }, messages[0]],
    [{ ...shell, key: 'tab-b' }, messages[0]],
    [shell, { ...messages[0], id: 'new-message', text: 'new text' }],
  ]) assert.equal(h.send(target, message), true);
  assert.equal(h.app.g_chat_outbox.items.length, 4);
  assert.equal(h.send(shell, { id: 'new-id', state: 'failed' }), true);
  assert.equal(h.app.g_chat_outbox.items[0].state, 'not_sent');
  assert.equal(h.send(shell, { id: 'new-id', state: 'accepted' }), true);
  assert.equal(h.app.g_chat_outbox.items.length, 4);
  assert.equal(h.app.g_chat_outbox.items[0].message_phase, 'accepted');
  assert.equal(h.send(shell, { id: 'unknown', state: 'unexpected' }), false);
});


test('receipt timestamps are initialized once rather than renewed on every replay', () => {
  const h = harness();
  const shell = {key: 'tab-a', sid: 'session-a'};
  const message = {id: 'wire-stamp', text: 'message', state: 'queued'};
  assert.equal(h.send(shell, message), true);
  assert.ok(h.app.g_chat_outbox.items[0].anchor.sent_ms > 0);
  const sent = h.app.g_chat_outbox.items[0].anchor.sent_ms;
  assert.equal(h.send(shell, {...message, state: 'accepted'}), true);
  assert.equal(h.app.g_chat_outbox.items[0].anchor.sent_ms, sent);
});


test('missing send timestamp uses the original server creation rather than snapshot time', () => {
  const h = harness();
  const shell = {key: 'tab-a', sid: 'session-a'};
  const created = Math.floor((WALL_MS - 60_000) / 1000);
  assert.equal(h.send(shell, {id: 'old-wire', text: 'older request', state: 'queued', created}), true);
  assert.equal(h.app.g_chat_outbox.items[0].anchor.sent_ms, created * 1000);
});

test('SOFT-2350 an old message the host still lists never comes back as a new unsent row', () => {
  const h = harness();
  const shell = { key: 'tab-a', sid: 'session-a' };
  const wallSeconds = Math.floor(WALL_MS / 1000);
  const staleCreated = wallSeconds - 11 * 60;
  const waitingCreated = wallSeconds - 60;
  for (const state of ['queued', 'sent', 'failed']) {
    assert.equal(h.send(shell, { id: `old-${state}`, text: 'older request', state, created: staleCreated }), true);
    assert.equal(h.app.g_chat_outbox.items.length, 0, `an old ${state} message came back as a new row`);
  }
  assert.equal(h.send(shell, { id: 'waiting', text: 'still waiting', state: 'queued', created: waitingCreated }), true);
  assert.equal(h.app.g_chat_outbox.items.length, 1);
  assert.equal(h.app.g_chat_outbox.items[0].message_phase, 'queued');
});
