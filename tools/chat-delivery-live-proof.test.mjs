import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

async function fixture(t, sustained = false, crashStress = false) {
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
  const count = crashStress ? 30 : sustained ? 31 : 10;
  const interval = sustained && !crashStress ? 60000 : 10000;
  const rounds = Array.from({ length: count }, (_, i) => ({ round: i + 1, messages: Array.from({ length: 3 }, (_, j) => `Live request ${i + 1} part ${j + 1}`), shownMs: 1000 + i * interval + 1500 }));
  const truth = rounds.map(row => ({ turn: row.round, ms: row.shownMs - 1500, accepted: row.messages, answer: `Live answer ${row.round}` }));
  const observed = { error: null, rounds, recordedFrames: Array(2 * count).fill('native-frame'), longDelivery: sustained, crashStress };
  write('live-delivery/observation.json', observed);
  write('live-delivery/stand-in/live-turns.jsonl', truth.map(JSON.stringify).join('\n'));
  write('live-delivery/stand-in/frames.jsonl', truth.map(row => JSON.stringify({ op: 'live-turn', screen: row.answer, queue: [] })).join('\n'));
  for (const row of rounds) {
    write(`live-delivery/round-${row.round}-copied.txt`, [...row.messages, `Live answer ${row.round}`].join('\n'));
    write(`live-delivery/round-${row.round}-outbox.json`, { queues: [] });
    for (const kind of ['queued', 'round']) write(`live-${kind}-${String(row.round).padStart(2, '0')}.png`, Buffer.from('89504e470d0a1a0a', 'hex'));
  }
  const actions = [{ input: 'Alt+C: open Chat View' }, ...Array.from({ length: 3 * count }, () => ({ input: 'Enter: send busy message' }))];
  if (sustained) {
    write('build.json', { tag: 'v1.2.3' });
    write('live-delivery/retained-header.json', { start: 0 });
    write('live-delivery/stand-in/tail-refreshes.jsonl', Array.from({ length: count - 1 }, () => JSON.stringify({ bytes: 20 * 1024 * 1024 })).join('\n'));
    actions.push({ input: 'Alt+C: capture completed shell', ms: rounds.at(-1).shownMs + 1 }, { input: 'Alt+C: return after completed proof', ms: rounds.at(-1).shownMs + 2 });
    for (const phase of ['before', 'after']) write(`live-side-by-side-${phase}.png`, Buffer.from('89504e470d0a1a0a', 'hex'));
  }
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

test('IGSH-1152 crash stress requires thirty rounds and cannot claim thirty minutes', async t => {
  const f = await fixture(t, true, true);
  assert.equal(f.check().replies, 30);
  assert.ok(f.check().sustainedMs < 1800000);
  f.observed.crashStress = false;
  f.write('live-delivery/observation.json', f.observed);
  assert.throws(f.check, assert.AssertionError);
});

test('IGSH-1152 a crash report fails even with complete reply receipts', async t => {
  const f = await fixture(t);
  f.write('live-delivery/crashes/crash-recorded.txt', 'ACCESS_VIOLATION');
  assert.throws(f.check, /native chat crashed/);
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


test('thirty-minute replies require continuous workload and retained-history refreshes', async t => {
  const f = await fixture(t, true);
  assert.equal(f.check().replies, 31);
  assert.equal(f.check().sustainedMs, 1800000);
  f.write('live-delivery/retained-header.json', { start: 1 });
  assert.throws(f.check, /not fully retained/);
});

test('short runs, long idle gaps and mid-proof view toggles cannot prove thirty minutes', async t => {
  for (const broken of ['short', 'gap', 'toggle', 'no-refresh']) {
    const f = await fixture(t, true);
    if (broken === 'short') {
      f.truth.at(-1).ms -= 1000;
      f.rounds.at(-1).shownMs -= 1000;
      f.write('live-delivery/observation.json', f.observed);
      f.write('live-delivery/stand-in/live-turns.jsonl', f.truth.map(JSON.stringify).join('\n'));
    }
    if (broken === 'gap') {
      f.truth[1].ms += 5001;
      f.rounds[1].shownMs += 5001;
      f.write('live-delivery/stand-in/live-turns.jsonl', f.truth.map(JSON.stringify).join('\n'));
      f.write('live-delivery/observation.json', f.observed);
    }
    if (broken === 'toggle') {
      f.actions.at(-1).ms = f.rounds.at(-1).shownMs;
      f.write('actions.json', f.actions);
    }
    if (broken === 'no-refresh') f.write('live-delivery/stand-in/tail-refreshes.jsonl', JSON.stringify({ bytes: 1 }));
    assert.throws(f.check, assert.AssertionError, broken);
  }
});


test('released workload keeps minute deadlines despite busy-send preparation', () => {
  const drive = fs.readFileSync(new URL('./verify-chat-delivery/live-delivery.ps1', import.meta.url), 'utf8');
  const loop = drive.slice(drive.indexOf('foreach ($round in 1..$roundCount)'), drive.indexOf('    $answer ='));
  assert.match(loop, /\$due = \$firstReplyMs \+ \(\$round - 1\) \* 60000/);
  assert.match(loop, /\$messages = @\(1\.\.3/);
  const operations = [...loop.matchAll(/\$due =|Shell-Run @\('refresh-live-tail'\)|Shell-Input 'busy'|Type-Composer \$message|Shot \$queuedFrame|Shell-Run @\('live-turn',/g)].map(match => match[0]);
  assert.equal(operations.length, 6);
  for (const preparationMs of [5500, 13000]) {
    let now = 0;
    let firstReplyMs = 0;
    const turns = [];
    for (let round = 1; round <= 31; round++) {
      for (const operation of operations) {
        if (operation === '$due =' && round > 1) {
          const due = firstReplyMs + (round - 1) * 60000;
          while (now < due) now += 500;
        } else if (operation.includes('refresh-live-tail') && round > 1) now += 1000;
        else if (operation === "Shell-Input 'busy'") now += 500;
        else if (operation === 'Type-Composer $message') now += preparationMs;
        else if (operation === 'Shot $queuedFrame') now += 250;
        else if (operation.includes("'live-turn'")) {
          turns.push(now);
          now += 100;
          if (firstReplyMs === 0) firstReplyMs = now;
        }
      }
      now += 1500;
    }
    assert.equal(turns.length, 31);
    assert.ok(turns.at(-1) - turns[0] >= 1800000, 'workload spans thirty minutes');
    for (let i = 1; i < turns.length; i++) {
      assert.ok(turns[i] - turns[i - 1] <= 65000, `busy preparation delayed turn ${i + 1}: ${turns[i] - turns[i - 1]} ms`);
    }
  }
});

test('long delivery proof can be dispatched on the exact branch', () => {
  const workflow = fs.readFileSync(new URL('../.github/workflows/verify.yml', import.meta.url), 'utf8');
  const dispatch = workflow.split('  workflow_dispatch:')[1].split('  workflow_call:')[0];
  assert.match(dispatch, /      long_chat_proof:\n(?:[^\n]*\n)*?        type: boolean/);
});
