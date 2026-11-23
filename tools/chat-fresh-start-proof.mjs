import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HANDOVER = 'Finish the saved draft. Keep the same board login.';
const MARKER = 'Finish the saved draft.';
const REPEATED_HANDOVER_MIN = 4097;
const REPEATED_HANDOVER_MAX = 8192;

function listChecks(checks) {
  if (Array.isArray(checks)) return checks;
  if (checks && typeof checks === 'object' && checks.name) return [checks];
  return [];
}

function readRows(file) {
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, 'utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
}

function countOf(text, needle) {
  return text.split(needle).length - 1;
}

export function verifyFreshStart(evidenceDir) {
  const read = name => JSON.parse(fs.readFileSync(path.join(evidenceDir, name), 'utf8').replace(/^\uFEFF/, ''));
  const before = read('fresh-start-before.json');
  const after = read('fresh-start-after.json');
  const result = fs.existsSync(path.join(evidenceDir, 'result.json'))
    ? read('result.json') : { checks: [] };
  const check = listChecks(result.checks).find(item => item.name === 'fresh-start');
  assert.ok(check, 'result.json missing fresh-start check');

  for (const key of ['sid', 'tmux', 'rowName', 'csid']) {
    assert.equal(before[key], after[key], key);
  }
  assert.ok(after.native_session, 'native_session missing after fresh start');
  assert.notEqual(before.native_session || '', after.native_session, 'native_session must change');
  assert.equal(after.matchingSidebarRows, 1, 'exactly one matching sidebar row');
  assert.ok(after.handoverSeen, 'handover text not observed in boundary or debug evidence');
  assert.ok(after.repeatHandoverSeen, 'the agent did not send its handover twice');
  assert.ok(after.replySeen, 'the new chat did not answer a message after the fresh start');

  const stages = readRows(path.join(evidenceDir, 'fresh-start-host.jsonl'));
  const visible = stages.filter(row => row.stage === 'handover_visible');
  const saved = stages.filter(row => row.stage === 'handover_saved');
  assert.ok(visible.length >= 2, `expected two visible handover turns, saw ${visible.length}`);
  for (const row of visible) assert.ok(String(row.text || '').includes(HANDOVER), 'visible handover text changed');
  assert.equal(saved.length, 1, `expected exactly one saved handover, saw ${saved.length}`);
  const draft = String(saved[0].text || '');
  assert.equal(countOf(draft, MARKER), 1, 'saved handover repeated its own text');
  const bytes = Buffer.byteLength(draft, 'utf8');
  assert.ok(bytes >= REPEATED_HANDOVER_MIN && bytes <= REPEATED_HANDOVER_MAX,
            `saved handover is ${bytes} bytes, outside the repeated-handover window`);
  assert.ok(stages.some(row => row.stage === 'completed'), 'hosted fresh start did not complete');
  const replies = stages.filter(row => row.stage === 'replied');
  assert.ok(replies.length >= 3, `expected a reply after the fresh start, saw ${replies.length}`);

  const agent = readRows(path.join(evidenceDir, 'fresh-start-agent.jsonl'));
  if (agent.length) {
    const resumed = agent.filter(row => row.carried === true && row.resumed === true);
    assert.equal(resumed.length, 1, `expected one resumed turn carrying the handover, saw ${resumed.length}`);
    const carriedAt = agent.indexOf(resumed[0]);
    assert.ok(agent.slice(carriedAt + 1).some(row => row.event === 'user' && String(row.text || '').includes('fresh-start after')),
              'no message followed the fresh start');
  }

  const debug = path.join(evidenceDir, 'fresh-start-debug.log');
  if (fs.existsSync(debug) && !after.handoverSeen) {
    const text = fs.readFileSync(debug, 'utf8');
    assert.ok(text.includes(MARKER) || text.includes('Fresh start'), 'debug log missing handover or fresh start marker');
  }

  return {
    feature: 'fresh-start',
    status: 'passed',
    before: { sid: before.sid, tmux: before.tmux, native_session: before.native_session, rowName: before.rowName, csid: before.csid },
    after: { sid: after.sid, tmux: after.tmux, native_session: after.native_session, rowName: after.rowName, csid: after.csid },
    repeatedHandover: { visibleTurns: visible.length, savedFiles: saved.length, savedBytes: bytes, replies: replies.length },
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
