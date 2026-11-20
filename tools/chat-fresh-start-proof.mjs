import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HANDOVER = 'Finish the saved draft. Keep the same board login.';

export function verifyFreshStart(evidenceDir) {
  const read = name => JSON.parse(fs.readFileSync(path.join(evidenceDir, name), 'utf8').replace(/^\uFEFF/, ''));
  const before = read('fresh-start-before.json');
  const after = read('fresh-start-after.json');
  const result = fs.existsSync(path.join(evidenceDir, 'result.json'))
    ? read('result.json') : { checks: [] };
  const check = (result.checks || []).find(item => item.name === 'fresh-start');
  assert.ok(check, 'result.json missing fresh-start check');

  for (const key of ['sid', 'tmux', 'rowName', 'csid']) {
    assert.equal(before[key], after[key], key);
  }
  assert.notEqual(before.native_session, after.native_session, 'native_session must change');
  assert.equal(after.matchingSidebarRows, 1, 'exactly one matching sidebar row');
  assert.ok(after.handoverSeen, 'handover text not observed in boundary or debug evidence');

  const hostJsonl = path.join(evidenceDir, 'fresh-start-host.jsonl');
  if (fs.existsSync(hostJsonl)) {
    const stages = fs.readFileSync(hostJsonl, 'utf8').trim().split('\n').map(JSON.parse);
    assert.ok(stages.some(row => row.stage === 'completed'), 'hosted fresh start did not complete');
    assert.ok(stages.some(row => row.stage === 'fresh_start_requested'), 'fresh_start request missing');
  }
  const debug = path.join(evidenceDir, 'fresh-start-debug.log');
  if (fs.existsSync(debug)) {
    const text = fs.readFileSync(debug, 'utf8');
    assert.ok(text.includes(HANDOVER) || text.includes('Fresh start'), 'debug log missing handover or fresh start marker');
  }

  return {
    feature: 'fresh-start',
    status: 'passed',
    before: { sid: before.sid, tmux: before.tmux, native_session: before.native_session, rowName: before.rowName, csid: before.csid },
    after: { sid: after.sid, tmux: after.tmux, native_session: after.native_session, rowName: after.rowName, csid: after.csid },
    boundary: 'Synthetic SSH/tmux and scripted Claude host; production composer, palette, session save and agent-host state.',
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const result = verifyFreshStart(process.argv[2]);
    fs.writeFileSync(path.join(process.argv[2], 'fresh-start-proof.json'), JSON.stringify(result, null, 2) + '\n');
    console.log('FRESH_START_PROOF_OK');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}