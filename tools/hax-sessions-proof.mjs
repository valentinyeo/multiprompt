import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = process.argv[2];
const json = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8').replace(/^\uFEFF/, ''));
try {
  const reader = json('hax-reader/observation.json');
  const closed = json('hax-close/observation.json');
  const cleanup = json('cleanup.json');
  for (const observation of [reader, closed]) {
    assert.equal(observation.error, null, observation.error);
    assert.equal(observation.passed, true);
    assert.equal(observation.beforeIds.length, 4);
    assert.equal(new Set(observation.beforeIds).size, 4);
  }
  assert.deepEqual(reader.runners.map(runner => runner.index), [0, 1, 2]);
  for (const runner of reader.runners) {
    assert.ok(runner.copied.includes(`IGSH1043 runner ${runner.index} question`));
    assert.ok(runner.copied.includes(runner.wanted));
    const copy = fs.readFileSync(path.join(root, `hax-reader/runner-${runner.index}-copied.txt`), 'utf8');
    assert.equal(copy, runner.copied);
    const image = fs.readFileSync(path.join(root, `hax-runner-${runner.index}.png`));
    assert.equal(image.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
  }
  assert.equal(closed.savedBefore, 4);
  assert.equal(closed.savedAfter, 3);
  assert.equal(closed.hostRefresh, true);
  assert.equal(closed.restartClosed, true);
  assert.equal(closed.explicitReopen, true);
  assert.equal(closed.afterIds.length, 3);
  assert.ok(!closed.afterIds.includes(closed.closedId));
  assert.ok(closed.afterIds.every(id => closed.beforeIds.includes(id)));
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  const result = {feature: 'hax-sessions', status: 'passed', sessions: 3, savedBefore: 4, savedAfter: 3,
    agentBoundary: 'Synthetic native hax session files and process-owned descriptors; real Windows app, reader, public Copy and close/host-refresh controls. No AI provider called.'};
  fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify(result, null, 2) + '\n');
  console.log('HAX_SESSIONS_JOURNEY_OK');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
