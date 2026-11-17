import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function verify(root) {
  const json = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8').replace(/^\uFEFF/, ''));
  assert.equal(json('full-history/observation.json').error, null);
  const observed = json('full-history/newest.json');
  assert.equal(observed.existingDraft, 'draftGG');
  assert.equal(observed.plainDraft, 'gg');
  assert.equal(observed.slowDraft, 'GG');
  assert.equal(observed.jumpDraft, '');
  assert.equal(observed.finalDraft, '');
  assert.equal(observed.scrolledBefore, true);
  const offsets = [observed.scrollStart, observed.logStart, observed.paletteLogStart, observed.paletteJumpStart];
  for (const [i, offset] of offsets.entries()) assert.ok(Number.isInteger(offset) && offset >= 0 && (!i || offset > offsets[i - 1]));
  const log = fs.readFileSync(path.join(root, 'full-history/debug.log'), 'utf8').replace(/^\uFEFF/, '');
  assert.ok(log.length > observed.paletteJumpStart);
  const scroll = /\[chat\] scroll ui thumb=-?\d+,-?\d+ button=/;
  assert.match(log.slice(observed.scrollStart, observed.logStart), new RegExp(scroll.source + '1'));
  assert.match(log.slice(observed.logStart, observed.paletteLogStart), new RegExp(scroll.source + '0'));
  assert.match(log.slice(observed.paletteLogStart, observed.paletteJumpStart), /\[palette\] ready chars=22 count=1 target=6465(?:\s|$)/);
  assert.match(log.slice(observed.paletteJumpStart), new RegExp(scroll.source + '0'));
  const actions = json('actions.json');
  for (const text of ['draftGG', 'gg', 'GG']) assert.ok(actions.some(action => action.input === 'type composer text' && action.text === text));
  const slow = actions.filter(action => action.input === 'type composer text' && action.text === 'G');
  assert.equal(slow.length, 2);
  assert.ok(slow[1].ms - slow[0].ms > 600);
  assert.ok(actions.some(action => action.input === 'Enter: jump to newest message'));
  for (const name of ['before', 'after', 'draft', 'palette']) {
    const image = fs.readFileSync(path.join(root, `chat-newest-${name}.png`));
    assert.equal(image.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.ok(image.length > 10000);
  }
  const doctor = json('full-history/doctor.json');
  const build = json('build.json');
  assert.equal(doctor.sha256.toLowerCase(), build.sha256.toLowerCase());
  assert.equal(doctor.version, build.version);
  assert.ok(doctor.chat && doctor.tmux && doctor.pid > 0);
  assert.deepEqual(doctor.focus, [doctor.hwnd, doctor.composer]);
  assert.equal(json('full-history/process-tree.json').ActiveProcesses, 0);
  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  return { feature: 'chat-newest', status: 'passed', checks: [
    { name: 'SOFT-2489 Shift+G twice jumps from older messages to newest', passed: true, composer: observed.jumpDraft },
    { name: 'SOFT-2489 ordinary typing preserves drafts without jumping', passed: true, existingDraft: observed.existingDraft, lowercase: observed.plainDraft, slow: observed.slowDraft },
    { name: 'SOFT-2489 renamed palette row executes the newest-message action', passed: true, query: 'jump to newest message', target: 6465, composer: observed.finalDraft },
    { name: 'owned desktop identity and cleanup', passed: true },
  ] };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const root = process.argv[2];
  let result;
  try { result = verify(root); }
  catch (error) { result = { feature: 'chat-newest', status: 'failed', error: error.message, checks: [] }; }
  fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify(result));
  process.exitCode = result.status === 'passed' ? 0 : 1;
}
