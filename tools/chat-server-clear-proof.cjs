const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function verify(root) {
  const dir = path.join(root, 'server-clear');
  const read = name => fs.readFileSync(path.join(dir, name), 'utf8').replace(/^\uFEFF/, '');
  const json = name => JSON.parse(read(name));
  const lines = name => read(name).split(/\r?\n/).filter(line => line.trim()).map(JSON.parse);
  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  assert.equal(json('observation.json').error, null);
  const doctor = json('doctor.json');
  assert.ok(doctor.pid > 0 && doctor.hwnd > 0 && doctor.chat);
  assert.match(doctor.sha256, /^[a-f0-9]{64}$/i);
  const before = json('before-state.json');
  const after = json('after-state.json');
  assert.ok(before.agent_pid > 0 && after.agent_pid > 0);
  assert.notEqual(after.agent_pid, before.agent_pid, 'clear must replace the agent process');
  assert.ok(after.context_session);
  assert.notEqual(after.context_session, before.context_session || before.native_session, 'clear must replace the context');
  const agents = lines('agent-argv.jsonl');
  assert.ok(agents.some(row => row.pid === after.agent_pid && row.argv.some((arg, i) => arg === '--session-id' && row.argv[i + 1] === after.context_session)), 'new agent must start with the cleared context');
  assert.ok(lines('host-events.jsonl').some(row => row.event === 'clear'));
  for (const stage of ['before', 'after-clear', 'after-reply']) {
    const history = read(`${stage}-history.txt`);
    assert.ok(history.includes('The fake session is ready.'), stage);
    assert.doesNotMatch(history, /Not sent|\[mp:[0-9a-f]{16}\]/);
  }
  const reply = read('after-reply-history.txt');
  assert.ok(reply.includes('A new question after clearing.'));
  assert.ok(reply.includes('Synthetic fixture response.'));
  assert.doesNotMatch(read('outbox.json'), /\/clear/);
  const actions = JSON.parse(fs.readFileSync(path.join(root, 'actions.json'), 'utf8').replace(/^\uFEFF/, ''));
  assert.ok(actions.some(row => row.text === '/clear'));
  for (const input of ['Enter: clear the server chat', 'Enter: send after clearing']) {
    assert.ok(actions.some(row => row.input === input && row.keys.includes(13)), input);
  }
  for (const stage of ['clear-before', 'clear-after', 'clear-reply']) {
    const png = fs.readFileSync(path.join(root, `${stage}.png`));
    assert.equal(png.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.ok(png.length > 1000);
  }
  return { newContext: true, agentReplaced: true, historyRetained: true, followupReply: true, notSent: false, deliveryTag: false };
}

module.exports = { verify };
if (require.main === module) {
  const root = process.argv[2];
  try {
    const proof = verify(root);
    fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-server-clear', status: 'passed', agentBoundary: 'Real Windows input, embedded reader and production host; synthetic Claude process and SSH transport, no provider calls', cases: [{ name: 'server-clear', passed: true, detail: proof }] }, null, 2));
    console.log(JSON.stringify(proof));
  } catch (error) {
    console.error(error);
    process.exitCode = 1;
  }
}
