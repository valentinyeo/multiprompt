const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
assert.ok(fs.existsSync(path.join(__dirname, 'chat-server-clear-proof.cjs')), 'server clear requires its independent evidence checker');
const { verify } = require('./chat-server-clear-proof.cjs');

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'clear-proof-'));
  const dir = path.join(root, 'server-clear');
  fs.mkdirSync(dir, { recursive: true });
  const write = (name, value) => fs.writeFileSync(path.join(dir, name), typeof value === 'string' ? value : JSON.stringify(value));
  write('cleanup.json', { remaining_owned_processes: 0, scratch_removed: true, evidence_preserved: true });
  write('observation.json', { error: null });
  write('doctor.json', { pid: 1, hwnd: 1, chat: true, sha256: 'a'.repeat(64) });
  write('before-state.json', { agent_pid: 10, native_session: 'old-context' });
  write('after-state.json', { agent_pid: 20, context_session: 'new-context', native_session: 'new-context' });
  write('before-history.txt', 'start the fake session\nThe fake session is ready.');
  write('after-clear-history.txt', 'start the fake session\nThe fake session is ready.');
  write('after-reply-history.txt', 'start the fake session\nThe fake session is ready.\nA new question after clearing.\nSynthetic fixture response.');
  write('host-events.jsonl', JSON.stringify({ event: 'clear' }) + '\n');
  write('agent-argv.jsonl', [
    { pid: 10, argv: ['--session-id', 'old-context'] },
    { pid: 20, argv: ['--session-id', 'new-context'] },
  ].map(JSON.stringify).join('\n'));
  write('outbox.json', { queues: [] });
  write('arguments.json', { draft: '/clear extra', contextUnchanged: true, agentUnchanged: true, beforeArgs: 2, afterArgs: 2 });
  write('headers.json', { arguments: 'Verify agent Use /clear without arguments.', stopped: 'AI stopped. Click to restart', pending: 'Restarting the AI', refused: 'The AI is still running, so it was not restarted.', settled: 'Verify agent', requestedMs: 1, releasedMs: 2, settledMs: 3 });
  write('restart-reply.jsonl', JSON.stringify({ wire: '@mp\t1\trestart_ai\terror\tpane_busy\t0' }));
  fs.writeFileSync(path.join(root, 'actions.json'), JSON.stringify([
    { input: 'type composer', text: '/clear' },
    { input: 'Enter: clear the server chat', keys: [13] },
    { input: 'type composer', text: 'A new question after clearing.' },
    { input: 'Enter: send after clearing', keys: [13] },
  ]));
  for (const stage of ['clear-before', 'clear-after', 'clear-reply', 'clear-arguments', 'restart-stopped', 'restart-pending', 'restart-refused', 'restart-settled']) {
    const png = Buffer.alloc(1024);
    Buffer.from('89504e470d0a1a0a', 'hex').copy(png);
    fs.writeFileSync(path.join(root, `${stage}.png`), png);
  }
  return { root, write };
}

test('server clear requires a new agent context, visible retained history and a follow-up reply', t => {
  const { root } = fixture();
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  assert.equal(verify(root).newContext, true);
});

for (const [name, file, broken] of [
  ['unchanged agent', 'after-state.json', { agent_pid: 10, context_session: 'new-context' }],
  ['unchanged context', 'after-state.json', { agent_pid: 20, context_session: 'old-context' }],
  ['clear refused', 'host-events.jsonl', ''],
  ['Not sent row', 'after-clear-history.txt', 'The fake session is ready.\nNot sent'],
  ['delivery tag', 'after-reply-history.txt', 'A new question after clearing. [mp:0123456789abcdef]\nSynthetic fixture response.'],
  ['missing follow-up', 'after-reply-history.txt', 'The fake session is ready.'],
  ['arguments delivered', 'arguments.json', { draft: '', contextUnchanged: true, agentUnchanged: true, beforeArgs: 2, afterArgs: 3 }],
  ['stuck restart badge', 'headers.json', { arguments: 'Use /clear without arguments.', stopped: 'AI stopped', pending: 'Restarting the AI', refused: 'The AI is still running', settled: 'Restarting the AI', requestedMs: 1, releasedMs: 2, settledMs: 3 }],
  ['leaked process', 'cleanup.json', { remaining_owned_processes: 1, scratch_removed: true, evidence_preserved: true }],
]) {
  test(`server clear rejects ${name}`, t => {
    const { root, write } = fixture();
    t.after(() => fs.rmSync(root, { recursive: true, force: true }));
    write(file, broken);
    assert.throws(() => verify(root));
  });
}
