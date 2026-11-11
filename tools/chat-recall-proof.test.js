const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

function fixture(mutate) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'recall-proof-'));
  const dir = path.join(root, 'recall-handed');
  fs.mkdirSync(dir);
  const rows = [
    { event: 'init', sid: 'sid' },
    { event: 'user', uuid: 'a', text: 'recall keep one' },
    { event: 'user', uuid: 'b', text: 'recall menu two' },
    { event: 'user', uuid: 'c', text: 'recall key three' },
    { event: 'cancel', uuid: 'b', text: 'recall menu two', cancelled: true, subtype: 'cancel_async_message' },
    { event: 'cancel', uuid: 'c', text: 'recall key three', cancelled: true, subtype: 'cancel_async_message' },
    { event: 'answer', uuid: 'a', text: 'recall keep one', answer: 'Received recall keep one' },
  ];
  fs.writeFileSync(path.join(dir, 'recall-agent.jsonl'), rows.map(row => JSON.stringify(row)).join('\n') + '\n');
  fs.writeFileSync(path.join(dir, 'observation.json'), JSON.stringify({ error: null }));
  fs.writeFileSync(path.join(root, 'cleanup.json'), JSON.stringify({ remaining_owned_processes: 0, scratch_removed: true }));
  for (const name of ['waiting', 'menu', 'cancelled', 'delivered', 'kept']) {
    const image = Buffer.alloc(16);
    Buffer.from('89504e470d0a1a0a', 'hex').copy(image);
    fs.writeFileSync(path.join(root, `recall-handed-${name}.png`), image);
  }
  if (mutate) mutate(root, dir, rows);
  return root;
}

test('IGSH-1828 recall proof accepts a kept answer and two targeted recalls', () => {
  const adapter = fs.readFileSync(path.join(__dirname, 'verify-chat-delivery/sitecustomize.py'), 'utf8');
  assert.match(adapter, /os\.name == "nt" and \(os\.environ\.get\("CHAT_MODEL_PROOF"\) == "1" or os\.environ\.get\("CHAT_RECALL_PROOF"\) == "1"\)/);
  const { run } = require('./chat-recall-proof.cjs');
  const passed = run(fixture());
  assert.equal(passed.status, 'passed');
  const answered = fixture((root, dir, rows) => {
    rows.push({ event: 'answer', uuid: 'b', text: 'recall menu two', answer: 'Received recall menu two' });
    fs.writeFileSync(path.join(dir, 'recall-agent.jsonl'), rows.map(row => JSON.stringify(row)).join('\n') + '\n');
  });
  assert.equal(run(answered).status, 'failed');
  const refused = fixture((root, dir, rows) => {
    rows[4].cancelled = false;
    fs.writeFileSync(path.join(dir, 'recall-agent.jsonl'), rows.map(row => JSON.stringify(row)).join('\n') + '\n');
  });
  assert.equal(run(refused).status, 'failed');
});
