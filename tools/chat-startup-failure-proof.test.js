const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { verify, MESSAGE, SID } = require('./chat-startup-failure-proof.cjs');

test('startup failure proof rejects duplicates, transcripts and missing events', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'startup-proof-'));
  const put = (name, value) => {
    const file = path.join(root, name);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, typeof value === 'string' || Buffer.isBuffer(value) ? value : JSON.stringify(value));
  };
  try {
    const observation = { error: null, noTranscript: true, copied: MESSAGE };
    const rows = [
      { stage: 'subscribed', sid: SID, provider: 'claude' },
      { stage: 'host-stopped', sid: SID, standin: 'thread', events: [
        { event: { kind: 'turn.started' } },
        { event: { kind: 'text.done', payload: { text: MESSAGE } } },
        { event: { kind: 'turn.ended', payload: { status: 'failed' } } },
      ] },
    ];
    put('startup-failure/observation.json', observation);
    put('startup-failure/stand-in/startup-failure.jsonl', rows.map(JSON.stringify).join('\n'));
    put('startup-failure-visible.png', Buffer.from('89504e470d0a1a0a', 'hex'));
    put('cleanup.json', { remaining_owned_processes: 0, scratch_removed: true, evidence_preserved: true });
    assert.equal(verify(root).status, 'passed');
    put('startup-failure/observation.json', { ...observation, copied: MESSAGE + MESSAGE });
    assert.throws(() => verify(root), /exactly once/);
    put('startup-failure/observation.json', { ...observation, noTranscript: false });
    assert.throws(() => verify(root), /transcript/);
    put('startup-failure/observation.json', observation);
    rows[1].events.pop();
    put('startup-failure/stand-in/startup-failure.jsonl', rows.map(JSON.stringify).join('\n'));
    assert.throws(() => verify(root));
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
