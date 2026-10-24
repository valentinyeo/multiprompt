const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, 'src', name), 'utf8');
const session = read('chat_session.zig');
const composer = read('chat_composer.zig');
const sync = read('chat_shell_sync.zig');
const send = read('chat_send.zig');

function body(source, name) {
  const header = new RegExp(`^( *)(?:pub )?fn ${name}\\([^\\n]*\\) [^\\n{]+\\{\\n`, 'm').exec(source);
  assert.ok(header, name);
  const start = header.index + header[0].length;
  const end = source.indexOf(`\n${header[1]}}`, start);
  assert.ok(end > start, name);
  return source.slice(start, end);
}

function logic(source) {
  return source.replaceAll('self.', 'this.')
    .replace(/\band\b/g, '&&').replace(/\bor\b/g, '||')
    .replace(/\.(none|apply|not_sent)\b/g, '"$1"');
}

function deliveryPending(source) {
  const code = logic(body(source, 'chatDeliveryPending'))
    .replace('for (app_state.g_chat_outbox.items) |entry| {', 'for (const entry of outbox) {')
    .replace('@import("chat_send.zig").chatOutboxShellForKey(entry.key[0..entry.key_len]) orelse continue', 'resolve(entry.key); if (idx == null) continue')
    .replaceAll('app_state.shells', 'shells');
  return new Function('outbox', 'shells', 'resolve', 'shell_id', code);
}

function draftModel() {
  const constants = Object.fromEntries(['PUSH_QUIET_MS', 'FRESH_EDIT_MS', 'SEND_QUIET_MS'].map(name => {
    const value = sync.match(new RegExp(`const ${name}: u64 = (\\d+);`));
    assert.ok(value, name);
    return [name, Number(value[1])];
  }));
  const pull = logic(body(sync, 'onShell'))
    .replaceAll('&.{}', '""')
    .replace('if (composer_blank) draftHash("") else composer_hash', 'composer_blank ? draftHash("") : composer_hash')
    .replace('return if (composer_blank && !isBlankDraft(shell)) "apply" else "none";', 'return composer_blank && !isBlankDraft(shell) ? "apply" : "none";');
  const draft = { shell_id: 0, known: false, shell_hash: 0, synced_hash: 0, edit_ms: 0, push_ms: 0, quiet_until_ms: 0, edit_pending: false };
  const hash = text => text.trim().replaceAll('\r', '');
  const blank = text => !text.trim();
  const names = Object.keys(constants);
  const values = Object.values(constants);
  draft.onShell = new Function('draftHash', 'isBlankDraft', ...names, `return function(shell_id, shell, composer, focused, now) {${pull}}`)(hash, blank, ...values);
  draft.onSend = new Function(...names, `return function(now) {${logic(body(sync, 'onSend'))}}`)(...values);
  draft.applied = new Function('draftHash', `return function(text) {${logic(body(sync, 'applied'))}}`)(hash);
  return draft;
}

function journey(next, pending = deliveryPending(session)) {
  const outbox = [];
  const shells = [{ shell_id: 1 }, { shell_id: 2 }];
  const resolve = key => key === 'one' ? 0 : key === 'two' ? 1 : null;
  const draft = draftModel();
  let box = '';
  const a = 'message A';
  draft.onShell(1, '', box, true, 1000);
  const pull = (text, now, focused) => {
    if (pending(outbox, shells, resolve, 1)) return;
    if (draft.onShell(1, text, box, focused, now) !== 'apply') return;
    box = text;
    draft.applied(text);
  };
  const sendBox = now => {
    draft.onSend(now);
    outbox.push({ key: 'one', text: box, state: 'delivered', write_started: true, channel_sent: true });
    box = '';
  };
  box = a;
  sendBox(2000);
  pull(a, 3000, false);
  assert.equal(box, '', 'written delivery owns A before confirmation');
  outbox[0].state = 'not_sent';
  outbox[0].retryable = true;
  pull(a, 30000, false);
  const afterUnconfirmed = box;
  box += next;
  pull(a, 31000, true);
  const beforeSend = box;
  sendBox(32000);
  return { afterUnconfirmed, beforeSend, sent: outbox.map(entry => entry.text), box };
}

function expectJourney(next, pending) {
  assert.deepEqual(journey(next, pending), {
    afterUnconfirmed: '', beforeSend: next, sent: ['message A', next], box: '',
  });
}

test('IGSH-720 send A, delivery unconfirmed, type B and send never restores A or duplicates B', () => {
  expectJourney('message B');
  expectJourney('message A');
  console.log('unconfirmed duplicate regression passed');
});

test('IGSH-720 production send, unconfirmed transition and draft pull use the modeled ownership path', () => {
  const prompt = body(send, 'sendChatPrompt');
  assert.match(prompt, /GetWindowTextW\(app_state\.g_chat_composer_hwnd, &text_buf,/);
  assert.match(prompt, /var send_text: \[\]const u16 = text_buf\[0\.\.text_len\];/);
  assert.match(prompt, /chatEchoEnqueueForShell\(app_state\.active_shell, send_text, \.queued\)/);
  assert.match(prompt, /SetWindowTextW\(app_state\.g_chat_composer_hwnd, L\(""\)\)[\s\S]*chatDraftFlush\(\)/);
  assert.match(body(send, 'chatTmuxSendFinish'), /entry\.channel_sent = \(job\.written and !job\.rejected\) or job\.retry;/);
  assert.match(body(send, 'chatTmuxSettle'), /\.unconfirmed => \{\s*if \(entry\.state != \.not_sent\) \{\s*entry\.state = \.not_sent;\s*entry\.retryable = true;/);
  const pull = body(composer, 'chatShellDraftPull');
  assert.ok(pull.indexOf('chatDeliveryPending(shell_id)') < pull.indexOf('shell_draft.onShell('));
  assert.match(pull, /if \(@import\("chat_session.zig"\)\.chatDeliveryPending\(shell_id\)\) return;/);
  assert.match(pull, /shell_draft\.onShell\([^\n]*\) != \.apply\) return;/);
  assert.match(pull, /SetWindowTextW\(app_state\.g_chat_composer_hwnd, @ptrCast\(&out\)\)/);
  assert.match(pull, /chatDraftNoteEdit\(\)/);
});

test('IGSH-720 delivery ownership stays shell-specific and releases on settlement or removal', () => {
  const pending = deliveryPending(session);
  const shells = [{ shell_id: 1 }, { shell_id: 2 }];
  const resolve = key => key === 'one' ? 0 : null;
  const written = { key: 'one', channel_sent: true, state: 'not_sent', write_started: true };
  assert.equal(pending([written], shells, resolve, 1), true);
  assert.equal(pending([written], shells, resolve, 2), false);
  assert.equal(pending([{ ...written, key: 'removed-shell' }], shells, resolve, 1), false);
  assert.equal(pending([{ ...written, channel_sent: false, write_started: false }], shells, resolve, 1), false);
  assert.equal(pending([], shells, resolve, 1), false);
  const draft = draftModel();
  draft.onShell(1, '', '', false, 1000);
  assert.equal(draft.onShell(1, 'new shell draft', '', false, 30000), 'apply');
  assert.equal(draft.onShell(1, 'shell edit', 'typing B', true, 31000), 'none');
});

test('IGSH-720 ownership oracle rejects the old unconfirmed exclusion', () => {
  const old = session.replace('if (!entry.channel_sent) continue;', 'if (!entry.channel_sent or entry.state == .not_sent) continue;');
  const pending = deliveryPending(old);
  assert.throws(() => expectJourney('message B', pending), assert.AssertionError);
  assert.deepEqual(journey('message A', pending).sent, ['message A', 'message Amessage A']);
});
