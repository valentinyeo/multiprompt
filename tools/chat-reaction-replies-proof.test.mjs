import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const expected = '👍 to: Same first words for this example for this example for this example for this…';
function evidence() {
  const deliveries = [1, 2].map(id => ({ wire_id: `desktop-${id}`, text: expected, phase: 'accepted', draft: 'draft stays here' }));
  return {
    observation: { error: null, composerText: 'draft stays here', deliveries },
    outboxes: deliveries.map(delivery => ({ queues: [{ messages: [{ wire_id: delivery.wire_id, t: expected, phase: 'accepted', s: 3 }] }] })),
    events: deliveries.flatMap(() => [{ type: 'queue-operation', operation: 'enqueue', content: expected }, { type: 'attachment', attachment: { prompt: expected } }]),
    cleanup: { remaining_owned_processes: 0, scratch_removed: true, evidence_preserved: true },
    copied: `Original reply\nSame first words\n${expected}\n${expected}`,
  };
}

for (const [name, change, passes] of [
  ['two independently accepted code-free replies', () => {}, true],
  ['reused delivery identity', value => { value.observation.deliveries[1].wire_id = 'desktop-1'; }, false],
  ['private code sent to the AI', value => { value.events[3].attachment.prompt += ' [mp:0123456789abcdef]'; }, false],
  ['private code copied from the screen', value => { value.copied += ' [mp:0123456789abcdef]'; }, false],
  ['second attempt left Not sent', value => { value.outboxes[1].queues[0].messages[0].s = 2; }, false],
  ['only one consumed reply', value => { value.events.pop(); }, false],
  ['missing cleanup', value => { value.cleanup.remaining_owned_processes = 1; }, false],
]) {
  test(name, () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'reaction-replies-'));
    try {
      const value = evidence();
      change(value);
      fs.mkdirSync(path.join(root, 'reactions'));
      const write = (name, data) => fs.writeFileSync(path.join(root, name), JSON.stringify(data));
      write('reactions/observation.json', value.observation);
      write('cleanup.json', value.cleanup);
      value.outboxes.forEach((outbox, index) => write(`reactions/outbox-accepted-${index + 1}.json`, outbox));
      fs.writeFileSync(path.join(root, 'reactions/transcript.jsonl'), value.events.map(event => JSON.stringify(event)).join('\n'));
      fs.writeFileSync(path.join(root, 'reactions/copied.txt'), value.copied);
      for (const attempt of [1, 2]) for (const stage of ['menu', 'accepted', 'consumed']) fs.writeFileSync(path.join(root, `reactions-${stage}-${attempt}.png`), Buffer.alloc(1001));
      const result = spawnSync(process.execPath, [new URL('./chat-reaction-replies-proof.mjs', import.meta.url).pathname, root], { encoding: 'utf8' });
      assert.equal(result.status === 0, passes, result.stderr);
      assert.equal(JSON.parse(fs.readFileSync(path.join(root, 'result.json'), 'utf8')).status, passes ? 'passed' : 'failed');
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });
}
