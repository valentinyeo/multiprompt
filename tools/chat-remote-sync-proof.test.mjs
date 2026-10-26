import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { verifyRemoteSync } from './chat-remote-sync-proof.mjs';

test('remote proof rejects stale sessions, missing rendered turns and late delivery', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'remote-sync-'));
  const write = (file, value) => {
    const target = path.join(root, file);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, typeof value === 'string' || Buffer.isBuffer(value) ? value : JSON.stringify(value));
  };
  const turns = [1, 2, 3].map(turn => ({ turn, loadedMs: 100, session: turn < 3 ? 'first' : 'resumed', question: `Remote question ${turn}`, answer: `Remote answer ${turn}` }));
  const observation = { error: null, remoteHome: 'remote/home', clientHome: 'client/home', turns };
  try {
    write('remote-sync/observation.json', observation);
    write('remote-sync/seed-session.json', { tabs: [{ tmux_host: 2 }] });
    write('cleanup.json', { remaining_owned_processes: 0, scratch_removed: true, evidence_preserved: true });
    write('remote-sync/stand-in/frames.jsonl', turns.map(turn => JSON.stringify({ screen: `${turn.question}\n${turn.answer}` })).join('\n'));
    for (const turn of turns) {
      write(`remote-sync/turn-${turn.turn}-copied.txt`, `${turn.question}\n${turn.answer}`);
      for (const surface of ['chat', 'terminal']) write(`remote-turn-${turn.turn}-${surface}.png`, Buffer.from('89504e470d0a1a0a', 'hex'));
    }
    assert.equal(verifyRemoteSync(root).status, 'passed');
    turns[2].session = 'first';
    write('remote-sync/observation.json', observation);
    assert.throws(() => verifyRemoteSync(root), /resume changes session identity/);
    turns[2].session = 'resumed';
    turns[2].loadedMs = 2001;
    write('remote-sync/observation.json', observation);
    assert.throws(() => verifyRemoteSync(root), /two-second/);
    turns[2].loadedMs = 100;
    write('remote-sync/observation.json', observation);
    write('remote-sync/turn-3-copied.txt', 'Remote question 2\nRemote answer 2');
    assert.throws(() => verifyRemoteSync(root), /rendered question and answer/);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
