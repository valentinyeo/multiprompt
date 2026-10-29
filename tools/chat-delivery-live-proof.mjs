import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function verifyLiveDelivery(root) {
  const read = name => fs.readFileSync(path.join(root, name), 'utf8').replace(/^\uFEFF/, '');
  const json = name => JSON.parse(read(name));
  const observed = json('live-delivery/observation.json');
  assert.equal(observed.error, null);
  const crashes = path.join(root, 'live-delivery/crashes');
  assert.ok(!fs.existsSync(crashes) || !fs.readdirSync(crashes).some(name => name.startsWith('crash-')), 'native chat crashed during delivery');
  const sustained = observed.longDelivery && json('build.json').tag && !observed.crashStress;
  const count = observed.crashStress ? 30 : sustained ? 31 : 10;
  assert.deepEqual(observed.rounds.map(row => row.round), Array.from({ length: count }, (_, i) => i + 1));
  const truth = read('live-delivery/stand-in/live-turns.jsonl').trim().split(/\r?\n/).map(JSON.parse);
  const frames = read('live-delivery/stand-in/frames.jsonl').trim().split(/\r?\n/).map(JSON.parse);
  assert.equal(truth.length, count);
  const latencies = [];
  const received = [];
  for (const row of observed.rounds) {
    const source = truth.find(item => item.turn === row.round);
    const messages = Array.from({ length: 3 }, (_, i) => `Live request ${row.round} part ${i + 1}`);
    assert.deepEqual(row.messages, messages);
    assert.deepEqual(source.accepted, messages, 'all three busy messages reached the session');
    assert.equal(source.answer, `Live answer ${row.round}`);
    assert.ok(frames.some(frame => frame.op === 'live-turn' && frame.screen.includes(source.answer) && frame.queue.length === 0), 'reply exists in shell truth');
    const latency = row.shownMs - source.ms;
    assert.ok(Number.isSafeInteger(latency) && latency >= 0 && latency <= 2000, `reply ${row.round} exceeded two seconds: ${latency}`);
    latencies.push(latency);
    const copied = read(`live-delivery/round-${row.round}-copied.txt`);
    received.push(...messages, source.answer);
    const copiedLines = new Set(copied.split(/\r?\n/).map(line => line.trim()));
    for (const text of received) assert.ok(copiedLines.has(text), 'native rendered copy misses accepted text');
    const outbox = json(`live-delivery/round-${row.round}-outbox.json`);
    assert.ok(!outbox.queues.some(queue => queue.messages.some(item => messages.includes(item.t))), 'accepted message remains pending or unsent');
    for (const kind of ['queued', 'round']) {
      const image = fs.readFileSync(path.join(root, `live-${kind}-${String(row.round).padStart(2, '0')}.png`));
      assert.equal(image.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    }
  }
  const actions = json('actions.json');
  assert.equal(actions.filter(action => action.input === 'Enter: send busy message').length, 3 * count);
  const toggles = actions.filter(action => action.input.startsWith('Alt+C:'));
  assert.equal(toggles.length, observed.longDelivery ? 3 : 1, 'proof must not refresh by changing views');
  if (observed.longDelivery) {
    assert.equal(json('live-delivery/retained-header.json').start, 0, 'native history was not fully retained before refresh');
    const lastShown = observed.rounds.at(-1).shownMs;
    assert.ok(toggles.slice(1).every(action => action.ms > lastShown), 'view toggles happened before reply proof ended');
    const refreshes = read('live-delivery/stand-in/tail-refreshes.jsonl').trim().split(/\r?\n/).map(JSON.parse);
    assert.equal(refreshes.length, count - 1);
    assert.ok(refreshes.every(row => row.bytes > 18 * 1024 * 1024), 'long transcript workload missing');
    for (const phase of ['before', 'after']) {
      const image = fs.readFileSync(path.join(root, `live-side-by-side-${phase}.png`));
      assert.equal(image.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    }
  }
  if (sustained) {
    assert.ok(truth.at(-1).ms - truth[0].ms >= 1800000, 'reply workload did not span thirty minutes');
    for (let i = 1; i < truth.length; i++) {
      assert.ok(truth[i].ms - truth[i - 1].ms <= 65000, 'reply workload stopped during the thirty-minute proof');
    }
  }
  const recording = fs.readFileSync(path.join(root, 'live-delivery.gif'));
  assert.match(recording.subarray(0, 6).toString(), /^GIF8[79]a$/);
  assert.ok(recording.length > 1000, 'native recording is missing');
  assert.equal(observed.recordedFrames.length, 2 * count);
  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.evidence_preserved, true);
  assert.equal(cleanup.scratch_removed, true);
  return { feature: 'chat-live-delivery', status: 'passed', replies: count, busyMessages: 3 * count, sustainedMs: truth.at(-1).ms - truth[0].ms, maxReplyMs: Math.max(...latencies), latencies, recording: 'live-delivery.gif', agentBoundary: 'Synthetic busy agent and shell transport; real desktop, embedded reader, queued states and rendered conversation. Linux notification race covered separately by reader regression.' };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const result = verifyLiveDelivery(process.argv[2]);
    fs.writeFileSync(path.join(process.argv[2], 'result.json'), JSON.stringify(result, null, 2) + '\n');
    console.log('LIVE_DELIVERY_OK');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
