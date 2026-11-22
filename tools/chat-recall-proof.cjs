const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const KEEP = 'recall keep one';
const MENU = 'recall menu two';
const KEY = 'recall key three';

function run(root) {
  const result = { feature: 'chat-delivery', status: 'failed', cases: [] };
  try {
    const observation = JSON.parse(fs.readFileSync(path.join(root, 'recall-handed/observation.json'), 'utf8'));
    assert.equal(observation.error, null);
    const logPath = fs.existsSync(path.join(root, 'recall-handed/recall-agent.jsonl'))
      ? path.join(root, 'recall-handed/recall-agent.jsonl')
      : path.join(root, 'recall-handed/stand-in/recall-agent.jsonl');
    const rows = fs.readFileSync(logPath, 'utf8').trim().split('\n').filter(Boolean).map(line => JSON.parse(line));
    const users = rows.filter(row => row.event === 'user').map(row => row.text);
    assert.deepEqual(users, [KEEP, MENU, KEY]);
    const cancelled = rows.filter(row => row.event === 'cancel' && row.cancelled === true && row.subtype === 'cancel_async_message').map(row => row.text);
    assert.deepEqual(cancelled, [MENU, KEY]);
    const answers = rows.filter(row => row.event === 'answer');
    assert.deepEqual(answers.map(row => row.text), [KEEP]);
    assert.equal(answers[0].answer, 'Received ' + KEEP);
    assert.ok(!rows.some(row => row.event === 'answer' && (row.text === MENU || row.text === KEY)));
    for (const name of ['waiting', 'menu', 'cancelled', 'delivered', 'kept']) {
      const image = fs.readFileSync(path.join(root, `recall-handed-${name}.png`));
      assert.equal(image.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    }
    const cleanup = JSON.parse(fs.readFileSync(path.join(root, 'cleanup.json'), 'utf8'));
    assert.equal(cleanup.remaining_owned_processes, 0);
    assert.equal(cleanup.scratch_removed, true);
    result.status = 'passed';
    result.cases.push({ name: 'recall-handed', passed: true, detail: { cancelled, answered: KEEP } });
  } catch (error) {
    result.cases.push({ name: 'recall-handed', passed: false, detail: error.message });
  }
  return result;
}

if (require.main === module) {
  const result = run(process.argv[2]);
  fs.writeFileSync(path.join(process.argv[2], 'result.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result));
  process.exitCode = result.status === 'passed' ? 0 : 1;
}

module.exports = { run };
