import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const message = 'message sent during the reload';

function verify(root) {
  const read = name => fs.readFileSync(path.join(root, name), 'utf8');
  const json = name => JSON.parse(read(name).replace(/^\uFEFF/, ''));
  const text = name => read(name);
  const manifest = name => fs.existsSync(path.join(root, name));
  const journal = text('fresh-start-live/stand-in/working-host.jsonl')
    .split('\n')
    .filter(line => line.trim())
    .map(line => JSON.parse(line));
  const stage = name => journal.filter(row => row.stage === name);
  const observation = json('fresh-start-live/observation.json');

  assert.ok(!observation.error, `fresh start case failed: ${observation.error}`);
  assert.equal(observation.sent, message, 'the driven message is not the one under test');
  assert.ok(observation.dots, 'no captured frame matched the reloading dots');
  assert.equal(observation.liveReply, true, 'the reloading reply was not required live');
  assert.equal(observation.held, true, 'the waiting message was not required to stay queued');
  assert.equal(observation.deliveredOnce, true, 'exactly one delivery was not required');
  assert.ok(stage('fresh-start-requested').length >= 1, 'the real palette never requested a fresh start');
  assert.ok(stage('fresh-start-pending').length >= 1, 'the reload was never pending');
  assert.ok(stage('fresh-resume-delta').length >= 1, 'the reloading reply never streamed live');
  assert.ok(manifest('fresh-start-live/fresh-busy-00.bmp'), 'no captured frame for the reloading dots');
  assert.ok(stage('deliver-held').some(row => row.text === message), 'the message was never held by a busy chat');
  assert.ok(stage('deliver').filter(row => row.text === message).length === 1, 'the message must reach the chat exactly once');

  const live = text('fresh-start-live/fresh-live-copied.txt');
  const final = text('fresh-start-live/fresh-final-copied.txt');
  assert.ok(live.includes('The handover is reloaded'), 'the reloading reply was not painted while the reload was pending');
  assert.equal(final.split(message).length - 1, 1, 'the message sent during the reload must appear exactly once');
  assert.ok(final.includes('The handover is reloaded'), 'the reloading reply left the conversation');

  const outbox = json('fresh-start-live/outbox-held.json');
  const held = (outbox.queues || []).flatMap(queue => queue.messages || []).filter(row => row.t === message);
  assert.equal(held.length, 1, 'the waiting message is missing from the outbox');
  assert.equal(held[0].v1, 1, 'the waiting message is not on the shared message protocol');
  assert.notEqual(held[0].s, 2, 'the waiting message was painted as Not sent');
  assert.notEqual(held[0].phase, 'failed', 'the waiting message was marked failed during the reload');

  const finished = stage('fresh-start-finished');
  assert.equal(finished.length, 1, 'the reload must finish once');
  const delivered = stage('deliver').filter(row => row.text === message)[0];
  assert.ok(delivered.ms >= finished[0].ms, 'the message must arrive after the reload finishes');
  assert.equal(stage('dispatch-error').length, 0, 'the message store reported a dispatch error');
  assert.ok(manifest('fresh-start-pending.png'), 'no screenshot of the pending reload');
  assert.ok(manifest('fresh-message-waiting.png'), 'no screenshot of the waiting message');
  assert.ok(manifest('fresh-message-arrived.png'), 'no screenshot of the arrived message');
  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0, 'the run left owned processes behind');
  assert.equal(cleanup.scratch_removed, true, 'the run left its scratch profile behind');
  return {
    feature: 'chat-fresh-start',
    status: 'passed',
    boundary: 'Hosted stand-in remote shell, fake tmux and a scripted agent screen; production reader, message store and native desktop.',
    cleanup: `The owned Windows job stopped the app and its children (${cleanup.remaining_owned_processes} left running); the isolated profile, its process table and socket temp folder were removed (scratchRemoved=${cleanup.scratch_removed}); the evidence copy was kept (evidencePreserved=${cleanup.evidence_preserved}).`,
  };
}

const evidence = process.argv[2];
if (!evidence) throw new Error('Usage: node chat-fresh-start-live-proof.mjs <evidence>');
try {
  fs.writeFileSync(path.join(evidence, 'result.json'), JSON.stringify(verify(evidence), null, 2) + '\n');
  console.log('FRESH_START_LIVE_PASS');
} catch (error) {
  console.error(error.stack);
  process.exitCode = 1;
}
