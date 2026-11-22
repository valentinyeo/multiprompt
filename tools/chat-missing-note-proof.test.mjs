import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { NOTE, verifyMissingNote } from './chat-missing-note-proof.mjs';

test('missing transcript proof rejects terminal text in Chat View and a missing note', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'missing-note-'));
  const write = (file, value) => {
    const target = path.join(root, file);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, typeof value === 'string' || Buffer.isBuffer(value) ? value : JSON.stringify(value));
  };
  const screen = 'Claude Code\n\nReady\n\n❯ Try asking about the next step\n';
  const observation = { error: null, noteShown: true, copied: '' };
  try {
    write('missing-transcript/stand-in/console.jsonl', JSON.stringify({ screen }));
    write('missing-transcript/debug.log', `[chat] note shown: ${NOTE}\n`);
    write('missing-transcript-note.png', Buffer.from('89504e470d0a1a0a', 'hex'));
    write('cleanup.json', { remaining_owned_processes: 0, scratch_removed: true, evidence_preserved: true });
    write('missing-transcript/observation.json', observation);
    assert.equal(verifyMissingNote(root).status, 'passed');

    write('missing-transcript/observation.json', { ...observation, copied: screen });
    assert.throws(() => verifyMissingNote(root), /Chat View shows terminal text: Claude Code/);

    write('missing-transcript/observation.json', { ...observation, noteShown: false });
    assert.throws(() => verifyMissingNote(root), /plain not-available note painted/);

    write('missing-transcript/observation.json', observation);
    write('missing-transcript/debug.log', '');
    assert.throws(() => verifyMissingNote(root), /note line in the app log/);

    write('missing-transcript/debug.log', `[chat] note shown: ${NOTE}\n`);
    write('missing-transcript/stand-in/console.jsonl', JSON.stringify({ screen: 'blank' }));
    assert.throws(() => verifyMissingNote(root), /terminal stand-in shows Claude Code/);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
