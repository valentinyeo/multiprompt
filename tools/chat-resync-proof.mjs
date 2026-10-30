import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createHash } from 'node:crypto';
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

export function verifyRecovery(before, event, after, repeat, observation, writes, bootstraps, mapping, clients) {
  const texts = ['RECOVERY_HEAD_'.padEnd(200, 'h') + ' ', 'PENDING_ONE', 'PENDING_TWO', 'ACCEPTED_FOURTH'];
  const keys = ['desktop-101', 'desktop-102', 'desktop-103', 'desktop-104'];
  const logical = ['recovery-head', 'pending-one', 'pending-two', 'accepted-fourth'];
  assert.deepEqual(mapping, keys.map((server, i) => ({logical: logical[i], server, qid: 0x101 + i, text: texts[i]})), 'desktop identity mapping');
  const messages = client => {
    assert.equal(client.version, 2);
    const queues = client.queues.filter(queue => queue.key === 'tmux:0:verify-agent');
    assert.equal(queues.length, 1, 'desktop outbox binding missing');
    return queues[0].messages;
  };
  const initial = messages(clients.before);
  assert.deepEqual(initial.map(row => row.qid), mapping.map(row => row.qid), 'desktop initial identities');
  initial.forEach((row, i) => {
    assert.equal(row.t, texts[i]);
    assert.equal(row.s, 3); // Channel acknowledgment, not server consumption.
    assert.equal(row.x, 1);
    assert.equal(row.held, 1);
    assert.ok(row.w > 0 && row.d > row.w);
  });
  for (const client of [clients.after, clients.repeat]) {
    const pending = messages(client);
    assert.deepEqual(pending.map(row => row.qid), [0x102, 0x103], 'accepted echoes must clear; pending must survive');
    pending.forEach((row, i) => {
      assert.equal(row.t, texts[i + 1]);
      assert.equal(row.held, 1);
      assert.equal(row.x, 1);
      assert.ok(row.w > 0);
    });
  }
  assert.equal(observation.error, null);
  for (const value of [observation.renderedAfter, observation.renderedRepeat]) {
    for (const text of ['RECOVERY_HEAD_'.padEnd(200, 'h'), 'ACCEPTED_FOURTH']) {
      assert.equal(value.split(text).length - 1, 1, 'accepted message missing or duplicated in rendered chat');
    }
  }
  assert.equal(observation.headUnconfirmedBefore, true, 'pending desktop head not observed before recovery');
  assert.equal(typeof observation.renderedBefore, 'string', 'before copy missing');
  for (const text of ['PENDING_ONE', 'PENDING_TWO', 'ACCEPTED_FOURTH']) assert.ok(observation.queueBefore.includes('queued:' + text));
  for (const value of [observation.queueAfter, observation.queueRepeat]) {
    assert.ok(value.includes('queued:PENDING_ONE') && value.includes('queued:PENDING_TWO') && !value.includes('queued:ACCEPTED_FOURTH'), 'pending messages missing from chat');
  }
  for (const name of ['draftBefore', 'draftAfter', 'draftRepeat']) assert.equal(observation[name], 'draft stays here');
  assert.ok(observation.sendStart > 0 && observation.sendEnd >= observation.sendStart);
  assert.equal(writes.length, 0, 'terminal input during recovery');
  assert.ok(bootstraps.length > 0, 'actual reader bootstrap missing');
  for (const row of bootstraps) {
    assert.equal(row.full_sha256, '27e681fab0bbebf4620f0ff47c66d1fcc4442152fb1c7046eac376726a2672d0');
    assert.equal(row.inner_sha256, '458a0cb74a3500963f4a50e5ee01d25422f860b76ee4507a56f1aab13e0abaee');
    assert.equal(row.generation, 3);
  }
  assert.equal(event.legacy_rows.length, 4);
  assert.equal(event.appended_rows.length, 4);
  assert.ok(event.eof - event.origin > 512 * 1024);
  assert.equal(event.inode, before.inode);
  for (const [index, row] of event.legacy_rows.entries()) {
    assert.deepEqual(row.slice(0, 4), [keys[index], before.sid, texts[index], index ? 'queued' : 'submitted']);
    assert.equal(row[5], event.origin);
    assert.equal(row[6], event.inode);
    assert.equal(row[8], null);
    const appended = event.appended_rows[index];
    assert.equal(appended[4], event.eof);
    assert.equal(appended[5], event.origin);
    assert.equal(appended[8], null);
  }
  for (const snap of [before, after, repeat]) {
    assert.equal(snap.sid, before.sid);
    assert.equal(snap.inode, before.inode);
    assert.ok(snap.screen.includes('unsent terminal draft') && snap.screen.includes('esc to interrupt'));
    assert.deepEqual(snap.rows.map(row => row.key), keys);
    snap.rows.forEach((row, i) => {
      assert.equal(row.text, texts[i]);
      assert.equal(row.sid, before.sid);
      assert.equal(row.origin, event.origin);
      assert.equal(row.source_inode, event.inode);
    });
  }
  assert.deepEqual(before.rows.map(row => row.state), ['submitted', 'queued', 'queued', 'queued']);
  assert.deepEqual(before.claims, []);
  assert.deepEqual(after.rows.map(row => row.state), ['delivered', 'queued', 'queued', 'delivered']);
  assert.deepEqual(after.claims.map(row => row.key), ['desktop-101', 'desktop-104']);
  for (const claim of after.claims) {
    assert.equal(claim.sid, before.sid);
    assert.equal(claim.inode, before.inode);
    assert.ok(claim.offset >= event.origin && claim.offset < event.eof);
    assert.match(claim.digest, /^[a-f0-9]{64}$/);
  }
  assert.deepEqual(repeat, after, 'repeat changed durable state');
  return true;
}

export function verifyRecoveryPlan(plan) {
  assert.equal(typeof plan.recovery_required, 'boolean');
  assert.ok(Array.isArray(plan.cases) && plan.cases.includes('resync'));
  assert.equal(plan.cases.includes('resync-recovery'), plan.recovery_required, 'recovery plan case mismatch');
  assert.ok(plan.app?.version && plan.app?.sha256 && plan.harness?.source, 'plan metadata missing');
  assert.equal(plan.recovery_required, plan.app.version === '0.28.1042', 'recovery plan selection mismatch');
  return plan.recovery_required;
}

export function verifyResync(root) {
  const read = name => fs.readFileSync(path.join(root, name), 'utf8');
  const json = name => JSON.parse(read(name));
  const lines = name => read(name).trim().split('\n').filter(Boolean).map(JSON.parse);
  verifyObserved(json('resync/observation.json'), lines('resync/stand-in/agent-buffer.jsonl'),
    lines('resync/stand-in/resync-rewrite.jsonl')[0], read('resync/debug.log'));
  const actions = json('actions.json').filter(row => row.case === 'resync');
  assert.ok(actions.some(row => row.input === 'Enter: open More Menu'));
  assert.ok(actions.some(row => row.input === 'real mouse click Resync chat' && Number.isFinite(row.x) && Number.isFinite(row.y)));
  const recoveryRequired = verifyRecoveryPlan(json('resync-plan.json'));
  if (recoveryRequired) {
  const recovery = 'resync-recovery/';
  const event = lines(recovery + 'stand-in/recovery-event.jsonl')[0];
  assert.notEqual(read(recovery + 'outbox-before.json'), read(recovery + 'outbox-seed.json'), 'app did not rewrite seeded outbox');
  const sourceBefore = fs.readFileSync(path.join(root, recovery + 'stand-in/recovery-source-before.jsonl'));
  const sourceAfter = fs.readFileSync(path.join(root, recovery + 'stand-in/recovery-source-appended.jsonl'));
  assert.ok(!sourceBefore.toString('utf8').includes('RECOVERY_HEAD_'), 'head already in source before recovery');
  assert.equal(sourceBefore.length, event.origin);
  assert.equal(sourceAfter.length, event.eof);
  assert.ok(sourceAfter.subarray(0, event.origin).equals(sourceBefore));
  const appendedRows = sourceAfter.subarray(event.origin).toString('utf8').trim().split('\n').map(JSON.parse);
  assert.equal(appendedRows[0].message.content, 'RECOVERY_HEAD_'.padEnd(200, 'h'));
  assert.equal(appendedRows.at(-1).message.content, 'ACCEPTED_FOURTH');
  assert.ok(appendedRows.slice(1, -1).every(row => row.type === 'system'));
  for (const claim of json(recovery + 'after.json').claims) {
    const end = sourceAfter.indexOf(10, claim.offset);
    assert.ok(end >= claim.offset);
    assert.equal(createHash('sha256').update(sourceAfter.subarray(claim.offset, end + 1)).digest('hex'), claim.digest);
  }
  verifyRecovery(json(recovery + 'before.json'), event,
    json(recovery + 'after.json'), json(recovery + 'repeat.json'), json(recovery + 'observation.json'),
    lines(recovery + 'stand-in/agent-buffer.jsonl'), lines(recovery + 'stand-in/recovery-bootstrap.jsonl'),
    json(recovery + 'mapping.json'), {before: json(recovery + 'outbox-before.json'),
      after: json(recovery + 'outbox-after.json'), repeat: json(recovery + 'outbox-repeat.json')});
  assert.equal(json(recovery + 'provenance.json').application_source, '9ee03f97b05f50238aaac77154ebf11be3cc30b7');
  assert.equal(json('build.json').sha256.toLowerCase(), '22cd593c3c4146860d140606b2104e86459de990b7447abfa7d891beeffb07b1');
  assert.equal(json('actions.json').filter(row => row.case === 'resync-recovery' && row.input === 'real mouse click Resync chat').length, 2);
  for (const name of ['recovery-before', 'recovery-after', 'recovery-repeat', 'recovery-menu-after', 'recovery-menu-repeat']) {
    const image = fs.readFileSync(path.join(root, `${name}.png`));
    assert.equal(image.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.ok(image.length > 1000);
  }
  }
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
  return { feature: 'chat-resync', status: 'passed', recovery_required: recoveryRequired,
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
