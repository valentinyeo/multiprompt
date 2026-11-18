const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { judgeInputs } = require('./pr-verifier.cjs');

test('large desktop batches retain every result and the fixture and cleanup evidence within the judge budget', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-evidence-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const out = path.join(root, 'out');
  const evidence = path.join(root, 'evidence');
  fs.mkdirSync(out);
  fs.mkdirSync(evidence);
  fs.writeFileSync(path.join(out, 'pr.md'), 'Default seeded profile and streamed reply must be verified.');
  fs.writeFileSync(path.join(out, 'evidence.md'), 'Large journey summaries.\n'.repeat(1000));
  const artifacts = Array.from({ length: 70 }, (_, i) => `verify-case-${String(i).padStart(2, '0')}`);
  artifacts.push(...artifacts.slice(0, 40).map(name => `${name}-${'b'.repeat(40)}`));
  artifacts.push('verify-chat-real-size', `verify-chat-still-${'b'.repeat(40)}`);
  for (const artifact of artifacts) {
    const dir = path.join(evidence, artifact);
    fs.mkdirSync(dir);
    fs.writeFileSync(path.join(dir, 'result.json'), JSON.stringify({
      checks: Array.from({ length: 200 }, () => ({ name: 'large-paint-observation', passed: true, detail: 'x'.repeat(100) })),
      status: 'failed', error: `failure-${artifact}`, cleanup: 'owned processes stopped',
    }));
    fs.writeFileSync(path.join(dir, 'doctor.json'), JSON.stringify({ version: '1.0', sha256: 'a'.repeat(64), log: 'x'.repeat(10000) }));
    const phase = path.join(dir, 'working-live');
    fs.mkdirSync(phase);
    fs.writeFileSync(path.join(phase, 'doctor.json'), '{"version":"1.0"}');
    fs.writeFileSync(path.join(phase, 'cleanup.json'), '{"remaining_owned_processes":0}');
    fs.writeFileSync(path.join(phase, 'fixture-manifest.json'), '{"sessions":64,"messages":19872}');
    const archive = path.join(dir, 'data', 'roaming', 'ZigShell');
    fs.mkdirSync(archive, { recursive: true });
    fs.writeFileSync(path.join(archive, 'fixture-manifest.json'), '{"archived":"ARCHIVE_DUPLICATE"}');
  }
  const chat = path.join(evidence, 'verify-chat-real-size');
  fs.writeFileSync(path.join(chat, 'result.json'), JSON.stringify({ status: 'passed', checks: [
    { name: 'long-server-chat-loaded', messages: 2400 },
    { name: 'real-send-stream-and-complete', deltas: 8 },
  ] }));
  fs.writeFileSync(path.join(chat, 'fixture-manifest.json'), JSON.stringify({ files: Array(1000).fill('synthetic-history.jsonl'), sessions: 64, workspaces: 8, messages: 19872 }));
  fs.writeFileSync(path.join(chat, 'cleanup.json'), JSON.stringify({ scratch_removed: true, remaining_owned_processes: 0, evidence_preserved: true }));
  fs.writeFileSync(path.join(chat, 'journey.json'), JSON.stringify({ journey: 'chat-real-size', status: 'passed', seed: 'real-size-v1' }));
  const material = judgeInputs(out, evidence);
  assert.ok(material.length <= 120000, 'use no more context than the existing journey picker');
  assert.ok(!material.includes('ARCHIVE_DUPLICATE'), 'preserved profile copies must not crowd out authoritative evidence');
  for (const artifact of artifacts) {
    const section = material.split(`### evidence/${artifact}/result.json\n`)[1]?.split('\n\n### ')[0];
    assert.ok(section, `missing result for ${artifact}`);
    assert.match(section, /"status":"(?:passed|failed)"/);
    if (artifact !== 'verify-chat-real-size') assert.ok(section.includes(`failure-${artifact}`), 'root failures after large check arrays remain visible');
    assert.ok(material.includes(`### evidence/${artifact}/doctor.json\n`));
  }
  for (const value of ['"messages":2400', '"deltas":8', '"sessions":64', '"messages":19872', '"remaining_owned_processes":0', '"scratch_removed":true', '"seed":"real-size-v1"']) {
    assert.ok(material.includes(value), value);
  }
  assert.match(material, /\[truncated\]/, 'shortened detail is explicit rather than silently lost');
});

test('unreadable evidence remains visible instead of being converted into a passing result', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-unreadable-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const dir = path.join(root, 'verify-chat');
  fs.mkdirSync(dir);
  fs.writeFileSync(path.join(dir, 'result.json'), '{ broken result');
  const material = judgeInputs(root, root);
  assert.ok(material.includes('### evidence/verify-chat/result.json\n{ broken result'));
});

test('an evidence inventory that cannot fit is blocked explicitly rather than dropping journeys', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-overflow-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  for (let i = 0; i < 600; i++) {
    const dir = path.join(root, `verify-${String(i).padStart(3, '0')}-${'x'.repeat(180)}`);
    fs.mkdirSync(dir);
    fs.writeFileSync(path.join(dir, 'result.json'), '{"status":"failed"}');
  }
  assert.throws(() => judgeInputs(root, root), /Too many evidence files for the judge input budget/);
});
