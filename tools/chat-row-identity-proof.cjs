const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function orderedOnce(text, prompts) {
  let previous = -1;
  for (let index = 1; index <= prompts; index++) {
    for (const row of [`Identity prompt ${index}`, `Identity answer ${index}`]) {
      assert.equal(text.split(row).length - 1, 1, `${row} must appear exactly once`);
      const position = text.indexOf(row);
      assert.ok(position > previous, `${row} must follow the preceding row`);
      previous = position;
    }
  }
}

function run(root) {
  const result = { feature: 'chat-delivery', status: 'failed', cases: [] };
  try {
    const read = name => fs.readFileSync(path.join(root, name), 'utf8');
    const observation = JSON.parse(read('recall-handed/observation.json'));
    assert.equal(observation.error, null);
    const events = read('recall-handed/stand-in/row-identity-agent.jsonl').trim().split('\n').map(JSON.parse);
    assert.deepEqual(events.filter(row => row.event === 'user').map(row => row.text), ['Identity prompt 1', 'Identity prompt 2']);
    const answers = events.filter(row => row.event === 'answer');
    assert.equal(answers.length, 2);
    assert.equal(answers[0].transcript_user.uuid, undefined);
    assert.equal(answers[1].transcript_user.uuid, events.find(row => row.event === 'user' && row.index === 2).uuid);
    for (let index = 1; index <= 2; index++) {
      const pending = read(`recall-handed/pending-${index}.txt`);
      assert.equal(pending.split(`Identity prompt ${index}`).length - 1, 1);
      for (const stage of ['reconciled', 'refreshed']) {
        orderedOnce(read(`recall-handed/${stage}-${index}.txt`), index);
        const image = fs.readFileSync(path.join(root, `identity-${stage}-${index}.png`));
        assert.equal(image.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
      }
    }
    const cleanup = JSON.parse(read('cleanup.json'));
    assert.equal(cleanup.remaining_owned_processes, 0);
    assert.equal(cleanup.scratch_removed, true);
    assert.equal(cleanup.evidence_preserved, true);
    result.status = 'passed';
    result.cases.push({ name: 'hosted-row-identity', passed: true, detail: 'Both prompt rows appear once above their replies before and after refresh.' });
  } catch (error) {
    result.cases.push({ name: 'hosted-row-identity', passed: false, detail: error.message });
  }
  return result;
}

if (require.main === module) {
  const result = run(process.argv[2]);
  fs.writeFileSync(path.join(process.argv[2], 'result.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result));
  process.exitCode = result.status === 'passed' ? 0 : 1;
}
module.exports = { orderedOnce, run };
