import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function verifyObserved(value, writes, rewrite, log) {
  assert.equal(value.error, null, value.error || 'driver error');
  assert.equal(value.draftBefore, 'draft stays here');
  assert.equal(value.draftAfter, value.draftBefore, 'draft preserved');
  assert.ok(value.waitingBefore.includes('queued:stale waiting message'), 'broken waiting label observed');
  assert.ok(!value.waitingAfter.includes('queued:stale waiting message'), 'waiting label repaired');
  assert.ok(value.copied.includes('After  resync') && !value.copied.includes('Before resync'), 'corrected source rendered');
  assert.ok(rewrite.before.includes('Before resync') && rewrite.after.includes('After  resync'));
  assert.equal(Buffer.byteLength(rewrite.before), rewrite.bytes);
  assert.equal(Buffer.byteLength(rewrite.after), rewrite.bytes);
  assert.ok(log.includes('[chat] resync requested') && log.includes('[chat] resync completed'), 'source reload completed');
  assert.ok(value.sendStart > 0 && value.sendEnd >= value.sendStart);
  assert.equal(writes.filter(row => row.ms >= value.sendStart && row.ms <= value.sendEnd &&
    (row.submitted || row.argv?.includes('Enter'))).length, 0, 'no message transport during repair');
  return true;
}

export function verifyResync(root) {
  const read = name => fs.readFileSync(path.join(root, name), 'utf8');
  const json = name => JSON.parse(read(name));
  const lines = name => read(name).trim().split('\n').filter(Boolean).map(JSON.parse);
  verifyObserved(json('resync/observation.json'), lines('resync/stand-in/agent-buffer.jsonl'),
    lines('resync/stand-in/resync-rewrite.jsonl')[0], read('resync/debug.log'));
  const actions = json('actions.json').filter(row => row.case === 'resync');
  assert.ok(actions.some(row => row.input === 'Enter: open More Menu'));
  assert.equal(actions.filter(row => row.input === 'Down: choose Resync chat').length, 6);
  assert.ok(actions.some(row => row.input === 'Enter: Resync chat'));
  const doctor = json('resync/doctor.json');
  assert.ok(doctor);
  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  for (const name of ['resync-before', 'resync-menu', 'resync-after']) {
    const image = fs.readFileSync(path.join(root, `${name}.png`));
    assert.equal(image.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.ok(image.length > 1000);
  }
  return { feature: 'chat-resync', status: 'passed',
    agentBoundary: 'Real Windows app, composer and menu; production reader over scripted SSH/tmux source. No provider calls.' };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const result = verifyResync(process.argv[2]);
    fs.writeFileSync(path.join(process.argv[2], 'result.json'), JSON.stringify(result, null, 2) + '\n');
    console.log('RESYNC_REPAIR_OK');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
