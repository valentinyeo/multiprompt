import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const LIMITS = {pages: 1, draws: 1};

export function liveCounts(log, shell) {
  const lines = log.split(/\r?\n/);
  const stage = name => lines.filter(line => line.startsWith(`[chat-live] ${name} shell=${shell} n=`));
  const cursors = stage('start').map(line => Number(line.match(/ n=(\d+)/)[1]));
  return {starts: cursors, pages: stage('page').length, draws: stage('draw').length};
}

export function checkReplay({lastSeq, counts, subscribed, pushed}) {
  assert.ok(counts.starts.length >= 1, 'Chat A stream did not restart after switching back');
  const cursor = counts.starts[counts.starts.length - 1];
  const failures = [];
  if (cursor !== lastSeq) failures.push(`switching back restarted the live stream at cursor ${cursor}, expected the last seen event ${lastSeq}`);
  if (counts.pages > LIMITS.pages) failures.push(`${counts.pages} history pages were replayed after switching back, at most ${LIMITS.pages} allowed`);
  if (counts.draws > LIMITS.draws) failures.push(`${counts.draws} transcript redraws came from replayed turns after switching back, at most ${LIMITS.draws} allowed`);
  if (subscribed.length < 1) failures.push('the reader never saw a subscription for chat A after switching back');
  else if (subscribed.some(row => row.after !== lastSeq)) failures.push(`the reader subscribed from cursor ${subscribed.map(row => row.after).join(',')}, expected ${lastSeq}`);
  if (pushed.length > 0) failures.push(`the reader pushed ${pushed.length} replay pages for chat A after switching back`);
  assert.equal(failures.length, 0, `Switch-back replay: ${failures.join('; ')}`);
  return {start_cursor: cursor, last_seq: lastSeq, pages: counts.pages, draws: counts.draws, reader_subscribe_after: subscribed.map(row => row.after), reader_replay_pushes: pushed.length};
}

function verify(root) {
  const dir = path.join(root, 'switch-replay');
  const text = name => fs.readFileSync(path.join(dir, name), 'utf8').replace(/^﻿/, '');
  const json = name => JSON.parse(text(name));
  const observation = json('observation.json');
  assert.equal(observation.error, null, observation.error || 'driver failed');
  for (const key of ['shellA', 'shellB', 'lastA', 'returnMs', 'initialPagesA']) assert.ok(observation[key] !== undefined, `Observation is missing ${key}`);
  assert.ok(observation.lastA >= 1000, 'Seeded history is too short to prove replay');
  assert.ok(observation.initialPagesA >= 2, 'Chat A never received its history through the live stream before the switch');
  assert.notEqual(observation.shellA, observation.shellB, 'Both chats resolved to the same shell');
  const rows = text(path.join('stand-in', 'switch-host.jsonl')).trim().split('\n').filter(Boolean).map(line => JSON.parse(line));
  const after = rows.filter(row => row.chat === 'a' && row.ms >= observation.returnMs);
  const subscribed = after.filter(row => row.stage === 'subscribed');
  const pushed = after.filter(row => row.stage === 'pushed');
  assert.ok(rows.some(row => row.stage === 'subscribed' && row.chat === 'b'), 'Chat B never opened its live subscription');
  const counts = liveCounts(text('switch-return-chat-live.log'), observation.shellA);
  const measured = checkReplay({lastSeq: observation.lastA, counts, subscribed, pushed});
  const cleanup = JSON.parse(fs.readFileSync(path.join(root, 'cleanup.json'), 'utf8').replace(/^﻿/, ''));
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  return {
    feature: 'chat-switch-replay',
    status: 'passed',
    measured: {...measured, initial_pages: observation.initialPagesA, transcript_states: observation.transcriptStates, transcript_transitions: observation.transcriptTransitions, samples: observation.samples},
    boundary: 'Simulated SSH and agent host; production Chat View, live stream, reader subscriptions and event store.'
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = process.argv[2];
  try {
    fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify(verify(root), null, 2) + '\n');
    console.log('SWITCH_REPLAY_OK');
  } catch (error) {
    console.error(error.stack);
    try {
      const observation = JSON.parse(fs.readFileSync(path.join(root, 'switch-replay', 'observation.json'), 'utf8').replace(/^﻿/, ''));
      fs.writeFileSync(path.join(root, 'switch-replay-numbers.json'), JSON.stringify({
        last_seq: observation.lastA, initial_pages: observation.initialPagesA, return_pages: observation.returnPagesA, return_draws: observation.returnDrawsA,
        return_starts: observation.returnStarts, transcript_states: observation.transcriptStates, transcript_transitions: observation.transcriptTransitions, error: String(error.message)
      }, null, 2) + '\n');
    } catch {}
    process.exitCode = 1;
  }
}
