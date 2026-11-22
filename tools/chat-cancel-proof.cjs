const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function evaluate(read) {
  const observation = read('cancel-held/observation.json');
  assert.equal(observation.error, null);
  assert.deepEqual(observation.steps.map(step => step.name), [
    'transcript-loaded', 'three-messages-held', 'middle-message-offers-cancel', 'middle-message-cancelled',
    'other-messages-still-held', 'survivors-received-in-order', 'survivor-echoes-settled', 'delivered-message-has-no-cancel',
  ]);
  assert.ok(observation.steps.every(step => step.ok === true));
  const messages = file => read(file).queues.flatMap(queue => queue.messages);
  const texts = ['cancel keep one', 'cancel target two', 'cancel keep three'];
  assert.deepEqual(messages('cancel-held/outbox-held.json').map(row => row.t), texts);
  const cancelled = messages('cancel-held/outbox-cancelled.json');
  assert.deepEqual(cancelled.filter(row => row.s === 4).map(row => row.t), [texts[1]]);
  assert.deepEqual(cancelled.filter(row => row.s !== 4).map(row => row.t), [texts[0], texts[2]]);
  assert.deepEqual(messages('cancel-held/outbox-final.json').map(row => [row.t, row.s]), [[texts[1], 4]]);
  const transcript = read('cancel-held/transcript.jsonl');
  const received = transcript.filter(row => row.type === 'user' && typeof row.message?.content === 'string')
    .map(row => row.message.content).filter(text => texts.includes(text));
  assert.deepEqual(received, [texts[0], texts[2]]);
  const keys = read('cancel-held/stand-in/agent-buffer.jsonl');
  const typed = keys.filter(row => row.argv?.includes('-l')).map(row => row.argv.at(-1)).filter(text => texts.includes(text));
  assert.deepEqual(typed, [texts[0], texts[2]]);
  assert.ok(!keys.some(row => row.argv?.at(-1) === 'Up'));
  const cleanup = read('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  return { cancelled: texts[1], received };
}

if (require.main === module) {
  const root = process.argv[2];
  const read = file => {
    const text = fs.readFileSync(path.join(root, file), 'utf8');
    return file.endsWith('.jsonl') ? text.trim().split('\n').filter(Boolean).map(line => JSON.parse(line)) : JSON.parse(text);
  };
  const result = { feature: 'chat-delivery', status: 'failed', cases: [] };
  try {
    const detail = evaluate(read);
    for (const name of ['waiting', 'menu', 'cancelled', 'delivered', 'taken-menu']) {
      const image = fs.readFileSync(path.join(root, `cancel-held-${name}.png`));
      assert.equal(image.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    }
    result.status = 'passed';
    result.cases.push({ name: 'cancel-held', passed: true, detail });
  } catch (error) {
    result.cases.push({ name: 'cancel-held', passed: false, detail: error.message });
  }
  fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result));
  process.exitCode = result.status === 'passed' ? 0 : 1;
}

module.exports = { evaluate };
