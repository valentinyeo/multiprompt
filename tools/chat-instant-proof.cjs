const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function verify(root) {
  const dir = path.join(root, 'instant-chat');
  const read = name => fs.readFileSync(path.join(dir, name), 'utf8');
  const json = name => JSON.parse(read(name));
  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  assert.equal(json('observation.json').error, null);
  const timing = json('startup-timing.json');
  assert.ok(timing.firstPaintMs >= 0 && timing.firstPaintMs < 1000);
  const frames = json('startup-frames.json');
  assert.ok(frames.length >= 2);
  assert.ok(frames[0].ms <= timing.startedMs);
  assert.ok(frames.at(-1).ms >= timing.startedMs);
  assert.match(fs.readFileSync(path.join(root, 'instant-startup.gif')).subarray(0, 6).toString(), /^GIF8[79]a$/);
  const snapshot = json('saved-launch.json');
  assert.equal(snapshot.chat, true);
  assert.ok(snapshot.blocks.length > 0);
  assert.ok(read('offline-copied.txt').includes('The fake session is ready.'));
  const log = read('debug.log');
  assert.match(log, /launch cached-chat rows=\d+ active=\d+ blocks=[1-9]\d*/);
  assert.doesNotMatch(log, /Chat sync interrupted/);
  const pending = json('offline-outbox.json').queues.flatMap(queue => queue.messages)
    .filter(message => message.t.startsWith('preconnect '));
  const expected = ['preconnect first', 'preconnect second'];
  assert.deepEqual(pending.map(message => message.t), expected);
  assert.equal(new Set(pending.map(message => message.wire_id)).size, 2);
  for (const message of pending) assert.match(message.wire_id, /^desktop-[a-f0-9]{32}$/);
  assert.deepEqual(json('store-before.json').filter(row => expected.includes(row.text)), []);
  const received = json('store-after.json').filter(row => expected.includes(row.text));
  assert.deepEqual(received.map(row => row.text), expected);
  assert.deepEqual(received.map(row => row.id), pending.map(message => message.wire_id));
  assert.ok(received[0].position < received[1].position);
  const delivery = json('delivery-timing.json');
  assert.ok(delivery.releasedMs < delivery.receivedMs);
  const waits = read('stand-in/connection-waits.jsonl').trim().split('\n').map(JSON.parse);
  assert.ok(waits.some(row => row.ms < delivery.releasedMs));
  for (const frame of ['instant-first-paint', 'instant-buffered', 'instant-delivered']) {
    const png = fs.readFileSync(path.join(root, `${frame}.png`));
    assert.equal(png.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.ok(png.length > 1000);
  }
  return { firstPaintMs: timing.firstPaintMs, messages: received.length };
}

module.exports = { verify };
if (require.main === module) {
  const root = process.argv[2];
  try {
    const proof = verify(root);
    fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-delivery', status: 'passed', agentBoundary: 'real Windows app, delayed SSH stand-in, production host store; not a live SSH server or AI agent', cases: [{ name: 'instant-chat', passed: true, detail: proof }] }, null, 2));
    console.log(JSON.stringify(proof));
  } catch (error) {
    console.error(error);
    process.exitCode = 1;
  }
}
