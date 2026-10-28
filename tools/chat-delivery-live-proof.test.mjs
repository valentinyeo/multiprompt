import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

async function fixture(t) {
  const file = new URL('./chat-delivery-live-proof.mjs', import.meta.url);
  assert.ok(fs.existsSync(file), 'The continuous native delivery oracle must ship');
  const { verifyLiveDelivery } = await import(file);
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'live-delivery-proof-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const write = (name, value) => {
    const file = path.join(root, name);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, typeof value === 'string' || Buffer.isBuffer(value) ? value : JSON.stringify(value));
  };
  const rounds = Array.from({ length: 10 }, (_, i) => ({ round: i + 1, messages: Array.from({ length: 3 }, (_, j) => `Live request ${i + 1} part ${j + 1}`), shownMs: 1000 + i * 10000 + 1500 }));
  const truth = rounds.map(row => ({ turn: row.round, ms: row.shownMs - 1500, accepted: row.messages, answer: `Live answer ${row.round}` }));
  const observed = { error: null, rounds, recordedFrames: Array(20).fill('native-frame') };
  write('live-delivery/observation.json', observed);
  write('live-delivery/stand-in/live-turns.jsonl', truth.map(JSON.stringify).join('\n'));
  write('live-delivery/stand-in/frames.jsonl', truth.map(row => JSON.stringify({ op: 'live-turn', screen: row.answer, queue: [] })).join('\n'));
  for (const row of rounds) {
    write(`live-delivery/round-${row.round}-copied.txt`, [...row.messages, `Live answer ${row.round}`].join('\n'));
    write(`live-delivery/round-${row.round}-outbox.json`, { queues: [] });
    for (const kind of ['queued', 'round']) write(`live-${kind}-${String(row.round).padStart(2, '0')}.png`, Buffer.from('89504e470d0a1a0a', 'hex'));
  }
  const actions = [{ input: 'Alt+C: open Chat View' }, ...Array.from({ length: 30 }, () => ({ input: 'Enter: send busy message' }))];
  write('actions.json', actions);
  write('cleanup.json', { remaining_owned_processes: 0, evidence_preserved: true, scratch_removed: true });
  write('live-delivery.gif', Buffer.concat([Buffer.from('GIF89a'), Buffer.alloc(1024)]));
  return { check: () => verifyLiveDelivery(root), write, rounds, truth, observed, actions };
}

test('ten fresh replies and thirty accepted busy messages pass', async t => {
  const f = await fixture(t);
  assert.equal(f.check().replies, 10);
  assert.equal(f.check().maxReplyMs, 1500);
});

test('slow replies, stale copies, unsent ghosts and view-refresh tricks fail', async t => {
  for (const broken of ['slow', 'copy', 'unsent', 'refresh', 'recording', 'missing-round']) {
    const f = await fixture(t);
    if (broken === 'slow') { f.rounds[0].shownMs = f.truth[0].ms + 2001; f.write('live-delivery/observation.json', f.observed); }
    if (broken === 'copy') f.write('live-delivery/round-1-copied.txt', 'stale reply');
    if (broken === 'unsent') f.write('live-delivery/round-1-outbox.json', { queues: [{ messages: [{ t: f.rounds[0].messages[0], s: 2 }] }] });
    if (broken === 'refresh') f.write('actions.json', [...f.actions, { input: 'Alt+C: refresh conversation' }]);
    if (broken === 'recording') f.write('live-delivery.gif', 'not a recording');
    if (broken === 'missing-round') { f.rounds.pop(); f.write('live-delivery/observation.json', f.observed); }
    assert.throws(f.check, assert.AssertionError, broken);
  }
});
