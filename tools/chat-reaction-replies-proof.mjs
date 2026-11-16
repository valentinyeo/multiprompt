import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = process.argv[2];
const json = name => JSON.parse(fs.readFileSync(path.join(root, name), 'utf8').replace(/^\uFEFF/, ''));
try {
  const observation = json('reactions/observation.json');
  assert.equal(observation.error, null);
  const expected = '👍 to: Same first words for this example for this example for this example for this…';
  assert.equal(observation.deliveries.length, 2);
  const ids = new Set();
  for (const [index, delivery] of observation.deliveries.entries()) {
    assert.equal(delivery.text, expected, 'whole-word quote, ellipsis and no private code');
    assert.equal(delivery.phase, 'accepted', 'each attempt is independently accepted');
    assert.equal(delivery.draft, 'draft stays here');
    assert.match(delivery.wire_id, /^desktop-[0-9a-f]+$/);
    ids.add(delivery.wire_id);
    const saved = json(`reactions/outbox-accepted-${index + 1}.json`);
    const message = saved.queues.flatMap(queue => queue.messages).find(message => message.wire_id === delivery.wire_id);
    assert.equal(message.t, expected);
    assert.equal(message.phase, 'accepted');
    assert.equal(message.s, 3, 'accepted reaction is delivered, not Not sent');
    for (const stage of ['menu', 'accepted', 'consumed']) assert.ok(fs.statSync(path.join(root, `reactions-${stage}-${index + 1}.png`)).size > 1000);
  }
  assert.equal(ids.size, 2, 'repeated thumbs ups have different delivery identities');
  const events = fs.readFileSync(path.join(root, 'reactions/transcript.jsonl'), 'utf8').trim().split(/\r?\n/).map(JSON.parse);
  assert.deepEqual(events.filter(event => event.type === 'queue-operation' && event.operation === 'enqueue').map(event => event.content), [expected, expected]);
  assert.deepEqual(events.filter(event => event.type === 'attachment').map(event => event.attachment.prompt), [expected, expected], 'AI received both code-free replies');
  const copied = fs.readFileSync(path.join(root, 'reactions/copied.txt'), 'utf8');
  assert.ok(copied.includes('Same first words'));
  assert.ok(!copied.includes('[mp:'), 'no private code in copied visible text');
  assert.equal(observation.composerText, 'draft stays here');
  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-reaction-replies', status: 'passed', deliveries: observation.deliveries, cleanup }, null, 2));
} catch (error) {
  fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-reaction-replies', status: 'failed', error: error.message }, null, 2));
  throw error;
}
