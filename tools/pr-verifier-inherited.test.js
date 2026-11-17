const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { summarize, finalize } = require('./pr-verifier.cjs');

const base = 'b'.repeat(40);
const cases = [
  { name: 'idle-suggestion', passed: false, detail: 'box keys reached fake tmux' },
  { name: 'queue-draft-sync', passed: false, detail: 'journey steps failed: shell-lists-both-in-order, queue-pulled-into-box' },
];

function verdict(t, headResult, baseResult) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pr-verifier-inherited-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  for (const [name, result] of [['verify-chat-delivery', headResult], [`verify-chat-delivery-${base}`, baseResult]]) {
    const artifact = path.join(dir, name);
    fs.mkdirSync(artifact);
    fs.writeFileSync(path.join(artifact, 'result.json'), JSON.stringify(result));
    fs.writeFileSync(path.join(artifact, 'after.png'), 'png');
  }
  return finalize({
    verdict: { verdict: 'PASS+NOTES', evidence: [] },
    headSha: 'a'.repeat(40),
    summary: summarize(dir, ['chat-delivery'], base),
    selection: { features: ['chat-delivery'], compareBase: true },
    runUrl: 'https://example.test/run/1',
  });
}

test('identical per-case failures preserve PASS+NOTES as inherited', t => {
  const result = verdict(t, { status: 'failed', cases }, { status: 'failed', cases });
  assert.equal(result.final, 'PASS+NOTES');
  assert.match(result.body, /chat-delivery: head failed, base failed \(inherited\)/);
});

test('per-case failure sets ignore order, duplicates and passed cases', t => {
  const result = verdict(t,
    { status: 'failed', error: '', cases: [...cases].reverse().concat(cases[0], { name: 'busy-send', passed: true, detail: 'ok' }) },
    { status: 'failed', cases });
  assert.equal(result.final, 'PASS+NOTES');
  assert.match(result.body, /\(inherited\)/);
});

test('a new head-only case failure is not inherited', t => {
  const result = verdict(t,
    { status: 'failed', cases: [...cases, { name: 'busy-send', passed: false, detail: 'no send keys' }] },
    { status: 'failed', cases });
  assert.equal(result.final, 'FAIL');
  assert.doesNotMatch(result.body, /\(inherited\)/);
});

test('different failure detail for the same case is not inherited', t => {
  const result = verdict(t,
    { status: 'failed', cases: [{ ...cases[0], detail: 'different failure' }, cases[1]] },
    { status: 'failed', cases });
  assert.equal(result.final, 'FAIL');
  assert.doesNotMatch(result.body, /\(inherited\)/);
});

test('different case names with identical details are not inherited', t => {
  const result = verdict(t,
    { status: 'failed', cases: [{ ...cases[0], name: 'wrapped-leftover' }, cases[1]] },
    { status: 'failed', cases });
  assert.equal(result.final, 'FAIL');
});

test('empty per-case failure sets do not establish inheritance', t => {
  const result = verdict(t, { status: 'failed', cases: [] }, { status: 'failed' });
  assert.equal(result.final, 'FAIL');
});

test('matching per-case failures do not hide a different root error', t => {
  const result = verdict(t, { status: 'failed', cases }, { status: 'failed', error: 'another failure', cases });
  assert.equal(result.final, 'FAIL');
});

test('matching root errors remain inherited', t => {
  const result = verdict(t,
    { status: 'failed', error: 'no ring' },
    { status: 'failed', error: 'no ring' });
  assert.equal(result.final, 'PASS+NOTES');
  assert.match(result.body, /\(inherited\)/);
});

test('different root errors remain failures', t => {
  const result = verdict(t,
    { status: 'failed', error: 'no ring' },
    { status: 'failed', error: 'wrong ring' });
  assert.equal(result.final, 'FAIL');
});
