const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const replies = [
  '^[[?61;1;6;7;21;22;23;24;28;32;42;52c^[[>0;10;1c',
  '\x1b[?61;1;6c\x1b[>0;10;1c',
  '^[[12;40R',
  '\x1b]10;rgb:1/1/1\x07',
  '^[]10;rgb:1/1/1^G',
];

function verify(root) {
  const dir = path.join(root, 'terminal-replies');
  const json = name => JSON.parse(fs.readFileSync(path.join(dir, name), 'utf8'));
  const lines = name => fs.readFileSync(path.join(dir, name), 'utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
  const observation = json('observation.json');
  assert.equal(observation.error, null);
  assert.deepEqual(observation.replies, replies);
  assert.deepEqual(observation.samples, replies.map(reply => ({ reply, composer: '' })));
  const drafts = lines('stand-in/terminal-drafts.jsonl');
  for (const reply of replies) {
    assert.ok(drafts.some(row => row.screen.includes(reply) && row.draft === ''), 'production reader removed the complete reply');
  }
  assert.ok(drafts.some(row => row.screen.includes('❯ []') && row.draft === '[]'), 'production reader preserved literal brackets');
  assert.equal(observation.typed, '[]');
  const actions = JSON.parse(fs.readFileSync(path.join(root, 'actions.json'), 'utf8'));
  assert.ok(actions.some(row => row.case === 'terminal-replies' && row.input === 'type composer text' && row.text === '[]'));
  assert.ok(actions.some(row => row.case === 'terminal-replies' && row.input === 'shell input' && row.kind === 'text' && row.value === '[]'));
  const doctor = json('doctor.json');
  const build = JSON.parse(fs.readFileSync(path.join(root, 'build.json'), 'utf8'));
  assert.equal(doctor.sha256.toLowerCase(), build.sha256.toLowerCase());
  assert.equal(doctor.version, build.version);
  assert.ok(doctor.pid > 0 && doctor.hwnd > 0 && doctor.composer > 0 && doctor.chat && doctor.tmux);
  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  assert.equal(json('process-tree.json').ActiveProcesses, 0);
  for (const name of ['terminal-replies-empty', 'terminal-replies-typed']) {
    const png = fs.readFileSync(path.join(root, `${name}.png`));
    assert.equal(png.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.ok(png.length > 1000);
  }
  return { replies: replies.length, typed: observation.typed };
}

module.exports = { verify, replies };
if (require.main === module) {
  const root = process.argv[2];
  let result;
  try {
    result = { feature: 'chat-terminal-replies', status: 'passed', cases: [{ name: 'terminal-replies', passed: true, detail: verify(root) }] };
  } catch (error) {
    result = { feature: 'chat-terminal-replies', status: 'failed', cases: [{ name: 'terminal-replies', passed: false, detail: error.message }] };
    process.exitCode = 1;
  }
  fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result));
}
