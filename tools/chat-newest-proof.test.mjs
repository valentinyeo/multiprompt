import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

const moduleUrl = new URL('./chat-newest-proof.mjs', import.meta.url);
assert.ok(fs.existsSync(moduleUrl), 'The newest-message journey needs its evidence checker');
const { verify } = await import(moduleUrl.href);

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-newest-proof-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.mkdirSync(path.join(root, 'full-history'));
  const json = (name, value) => fs.writeFileSync(path.join(root, name), JSON.stringify(value));
  const up = '[chat] scroll ui thumb=1,20 button=1\n';
  const bottom = '[chat] scroll ui thumb=1,20 button=0\n';
  const palette = '[palette] ready chars=22 count=1 target=6465\n';
  const observed = { scrollStart: 0, logStart: up.length, paletteLogStart: up.length + bottom.length, paletteJumpStart: up.length + bottom.length + palette.length, existingDraft: 'draftGG', plainDraft: 'gg', slowDraft: 'GG', jumpDraft: '', finalDraft: '', scrolledBefore: true };
  json('full-history/newest.json', observed);
  json('full-history/observation.json', { error: null });
  fs.writeFileSync(path.join(root, 'full-history/debug.log'), up + bottom + palette + bottom);
  json('actions.json', [...['draftGG', 'gg', 'GG'].map(text => ({ input: 'type composer text', text })), { input: 'type composer text', text: 'G', ms: 100 }, { input: 'type composer text', text: 'G', ms: 800 }, { input: 'Enter: jump to newest message' }]);
  for (const name of ['before', 'after', 'draft', 'palette']) {
    const image = Buffer.alloc(10001);
    Buffer.from('89504e470d0a1a0a', 'hex').copy(image);
    fs.writeFileSync(path.join(root, `chat-newest-${name}.png`), image);
  }
  json('build.json', { sha256: 'abc', version: '1.0.0' });
  json('full-history/doctor.json', { sha256: 'abc', version: '1.0.0', chat: true, tmux: true, pid: 1, hwnd: 20, composer: 21, focus: [20, 21] });
  json('full-history/process-tree.json', { ActiveProcesses: 0 });
  json('cleanup.json', { remaining_owned_processes: 0, scratch_removed: true, evidence_preserved: true });
  return { root, json, observed, up, bottom, palette };
}

test('native jump, ordinary typing, palette execution and cleanup are explicit verifier checks', t => {
  const { root } = fixture(t);
  const result = verify(root);
  assert.equal(result.status, 'passed');
  assert.equal(result.checks.length, 4);
  assert.ok(result.checks.every(check => check.passed));
});

for (const [name, value] of [['jumpDraft', 'GG'], ['existingDraft', 'draft'], ['plainDraft', ''], ['slowDraft', ''], ['finalDraft', 'G']]) {
  test(`reject incorrect native composer observation ${name}`, t => {
    const { root, json, observed } = fixture(t);
    json('full-history/newest.json', { ...observed, [name]: value });
    assert.throws(() => verify(root));
  });
}

test('a later palette jump cannot masquerade as a successful GG jump', t => {
  const { root, up, palette, bottom } = fixture(t);
  fs.writeFileSync(path.join(root, 'full-history/debug.log'), up + up + palette + bottom);
  assert.throws(() => verify(root));
});

test('failed cleanup cannot produce a passing jump verdict', t => {
  const { root, json } = fixture(t);
  json('cleanup.json', { remaining_owned_processes: 1, scratch_removed: true, evidence_preserved: true });
  assert.throws(() => verify(root));
});
