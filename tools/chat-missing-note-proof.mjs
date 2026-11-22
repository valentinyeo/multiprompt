import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const NOTE = 'Chat not available for this session, use the shell view';
export const SCREEN_TOKENS = ['Claude Code', 'Ready', 'Try asking about the next step', '❯'];

export function verifyMissingNote(root) {
  const read = name => fs.readFileSync(path.join(root, name), 'utf8');
  const value = JSON.parse(read('missing-transcript/observation.json'));
  assert.equal(value.error, null, value.error || 'driver error');
  const rows = read('missing-transcript/stand-in/console.jsonl').trim().split('\n').map(JSON.parse);
  for (const token of SCREEN_TOKENS) {
    assert.ok(rows.some(row => row.screen.includes(token)), `terminal stand-in shows ${token}`);
  }
  assert.equal(value.noteShown, true, 'plain not-available note painted');
  assert.equal(typeof value.copied, 'string', 'copied transcript text recorded');
  for (const token of SCREEN_TOKENS) {
    assert.ok(!value.copied.includes(token), `Chat View shows terminal text: ${token}`);
  }
  const debug = read('missing-transcript/debug.log');
  assert.ok(debug.includes(`[chat] note shown: ${NOTE}`), 'note line in the app log');
  const image = fs.readFileSync(path.join(root, 'missing-transcript-note.png'));
  assert.equal(image.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
  const cleanup = JSON.parse(read('cleanup.json'));
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  return { feature: 'chat-missing-note', status: 'passed', note: NOTE,
    agentBoundary: 'Stand-in remote shell and fake tmux with a Claude-like screen and no transcript file; real desktop, embedded reader and painted Chat View.' };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const result = verifyMissingNote(process.argv[2]);
    fs.writeFileSync(path.join(process.argv[2], 'result.json'), JSON.stringify(result, null, 2) + '\n');
    console.log('MISSING_NOTE_OK');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
