import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function verifyRemoteSync(root) {
  const read = name => fs.readFileSync(path.join(root, name), 'utf8');
  const value = JSON.parse(read('remote-sync/observation.json'));
  assert.equal(value.error, null, value.error || 'driver error');
  assert.equal(read('remote-sync/theme-mode.txt').trim(), 'amoled', 'AMOLED theme saved by the app');
  assert.notEqual(value.remoteHome, value.clientHome, 'different remote user home');
  const seed = JSON.parse(read('remote-sync/seed-session.json'));
  assert.equal(seed.tabs[0].tmux_host, 2, 'second server tab');
  assert.deepEqual(value.turns.map(turn => turn.turn), [1, 2, 3]);
  assert.equal(value.turns[0].session, value.turns[1].session);
  assert.notEqual(value.turns[1].session, value.turns[2].session, 'resume changes session identity');
  const frames = read('remote-sync/stand-in/frames.jsonl').trim().split('\n').map(JSON.parse);
  for (const turn of value.turns) {
    assert.ok(turn.renderedMs >= 0 && turn.renderedMs <= 2000, 'two-second delivery budget');
    const copied = read(`remote-sync/turn-${turn.turn}-copied.txt`);
    assert.ok(copied.includes(turn.question) && copied.includes(turn.answer), 'rendered question and answer');
    if (turn.turn === 3) assert.ok(!copied.includes('Remote answer 2'), 'no stale conversation');
    assert.ok(frames.some(frame => frame.screen.includes(turn.question) && frame.screen.includes(turn.answer)), 'terminal truth');
    for (const surface of ['chat', 'terminal']) {
      const image = fs.readFileSync(path.join(root, `remote-turn-${turn.turn}-${surface}.png`));
      assert.equal(image.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    }
  }
  const cleanup = JSON.parse(read('cleanup.json'));
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  return { feature: 'chat-remote-sync', status: 'passed', turns: value.turns,
    agentBoundary: 'Synthetic second SSH host and alternate remote home; real desktop, embedded reader and rendered text. Cross-user permissions covered by reader regressions.' };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const result = verifyRemoteSync(process.argv[2]);
    fs.writeFileSync(path.join(process.argv[2], 'result.json'), JSON.stringify(result, null, 2) + '\n');
    console.log('REMOTE_SYNC_OK');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
