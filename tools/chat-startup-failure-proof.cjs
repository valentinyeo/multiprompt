const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const MESSAGE = 'Could not start chat: working folder unavailable.';
const SID = 'a1b2c3d4-1593-4000-8000-000000001593';

function verify(root) {
  const read = name => fs.readFileSync(path.join(root, name), 'utf8');
  const observation = JSON.parse(read('startup-failure/observation.json'));
  assert.equal(observation.error, null, observation.error || 'driver failed');
  assert.equal(observation.noTranscript, true, 'provider transcript must be absent');
  assert.equal(observation.copied.split(MESSAGE).length - 1, 1, 'failure appears exactly once');
  assert.ok(!observation.copied.includes('Claude Code'), 'terminal contents leaked into chat');
  const rows = read('startup-failure/stand-in/startup-failure.jsonl').trim().split('\n').map(JSON.parse);
  assert.deepEqual(rows.map(row => row.stage), ['subscribed', 'host-stopped']);
  assert.equal(rows[0].sid, SID);
  assert.equal(rows[0].provider, 'claude');
  assert.equal(rows[1].sid, SID);
  assert.equal(rows[1].standin, 'thread');
  const events = rows[1].events.map(row => row.event);
  assert.deepEqual(events.map(event => event.kind), ['turn.started', 'text.done', 'turn.ended']);
  assert.equal(events[1].payload.text, MESSAGE);
  assert.equal(events[2].payload.status, 'failed');
  assert.equal(fs.readFileSync(path.join(root, 'startup-failure-visible.png')).subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
  const cleanup = JSON.parse(read('cleanup.json'));
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  return { feature: 'chat-startup-failure', status: 'passed', boundary: 'Simulated host startup failure; production embedded reader, event persistence, subscription and native desktop.' };
}

if (require.main === module) {
  try {
    fs.writeFileSync(path.join(process.argv[2], 'result.json'), JSON.stringify(verify(process.argv[2]), null, 2) + '\n');
    console.log('STARTUP_FAILURE_OK');
  } catch (error) {
    console.error(error.stack);
    process.exitCode = 1;
  }
}
module.exports = { verify, MESSAGE, SID };
