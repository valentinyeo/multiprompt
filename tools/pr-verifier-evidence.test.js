const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const verifier = require('./pr-verifier.cjs');

function scratch(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-evidence-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  fs.mkdirSync(path.join(dir, 'evidence'));
  return dir;
}

function put(dir, file, value) {
  const target = path.join(dir, file);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, (file.startsWith('evidence/') ? '\uFEFF' : '') + JSON.stringify(value, null, 4));
}

function documents(material) {
  return new Map(material.split(/^### /m).filter(Boolean).map(section => {
    const newline = section.indexOf('\n');
    return [section.slice(0, newline), section.slice(newline + 1).trim()];
  }));
}

test('a full journey matrix retains every head/base result, Doctor and final assertion', t => {
  const dir = scratch(t);
  const features = [...Array.from({ length: 78 }, (_, i) => `feature-${i}`), 'generated-sidebar-cycle', 'generated-theme-mid'];
  const base = 'b'.repeat(40);
  const expected = new Map();
  put(dir, 'selection.json', { features, compareBase: true });
  fs.writeFileSync(path.join(dir, 'pr.md'), 'PR context '.repeat(650) + '\nDone when: planted shortcut failure is independently observed.');
  fs.writeFileSync(path.join(dir, 'evidence.md'), 'Journey summary and screenshot paths.\n'.repeat(2800) + 'Final journey: generated-theme-mid');
  for (const feature of features) {
    for (const suffix of ['', `-${base}`]) {
      const artifact = `verify-${feature}${suffix}`;
      const result = { status: 'passed', cleanup: 'owned processes stopped', checks: Array.from({ length: 60 }, (_, i) => ({ name: `${feature}-${i}`, saved: { sidebar_collapsed: false }, observed: `native geometry ${i}` })) };
      const doctor = { pid: 123, class: 'ZigShell', sha256: 'c'.repeat(64), title: 'Multi Bot' };
      for (const [name, value] of [['result.json', result], ['doctor.json', doctor]]) {
        const file = `evidence/${artifact}/${name}`;
        put(dir, file, value);
        expected.set(file, value);
      }
    }
  }
  const material = verifier.judgeInputs(dir, path.join(dir, 'evidence'));
  const actual = documents(material);
  assert.match(actual.get('pr.md'), /Done when: planted shortcut failure is independently observed\.$/);
  assert.match(actual.get('evidence.md'), /Final journey: generated-theme-mid$/);
  assert.deepEqual(JSON.parse(actual.get('selection.json')), { features, compareBase: true });
  for (const [file, value] of expected) {
    assert.ok(actual.has(file), `${file} must reach the independent judge`);
    assert.deepEqual(JSON.parse(actual.get(file)), value, `${file} must retain every check`);
  }
  assert.doesNotMatch(material, /\[truncated\]/);
});

test('shortcut-break proof and its nested negative result both reach the judge with their context', t => {
  const dir = scratch(t);
  put(dir, 'selection.json', { features: ['generated-sidebar-cycle'] });
  const root = 'evidence/verify-generated-sidebar-cycle/';
  const files = {
    'result.json': { status: 'passed', checks: [{ name: 'shortcut:view/ctrl-shift-b', collapsed: true }] },
    'shortcut-break-proof.json': { status: 'passed', clean: 'passed', planted: 'failed', row: 'shortcut:view/ctrl-shift-b', error: 'collapsed sidebar saved', sha256: 'c'.repeat(64) },
    'shortcut-break-mutation.json': { row: 'shortcut:view/ctrl-shift-b', mutation: 'consume the shortcut without posting its action' },
    'shortcut-break/result.json': { status: 'failed', error: 'collapsed sidebar saved', scratchRemoved: true },
    'shortcut-break/doctor.json': { class: 'ZigShell', pid: 456 },
    'shortcut-break/process-tree.json': { activeAfterStop: 0, totalOwned: 2 },
  };
  for (const [name, value] of Object.entries(files)) put(dir, root + name, value);
  const actual = documents(verifier.judgeInputs(dir, path.join(dir, 'evidence')));
  for (const [name, value] of Object.entries(files)) {
    assert.ok(actual.has(root + name), `${name} must reach the independent judge`);
    assert.deepEqual(JSON.parse(actual.get(root + name)), value);
  }
  assert.match(verifier.judgeMessages('evidence')[0].content, /shortcut-break-proof\.json/);
  assert.match(verifier.judgeMessages('evidence')[0].content, /negative control/);
  assert.match(verifier.judgeMessages('evidence')[0].content, /nested result\/Doctor\/cleanup/);
});

test('oversized material fails closed instead of silently dropping required evidence', t => {
  const dir = scratch(t);
  fs.writeFileSync(path.join(dir, 'pr.md'), 'x'.repeat(2_000_001));
  assert.throws(() => verifier.judgeInputs(dir, path.join(dir, 'evidence')), /Judge evidence exceeds.*no evidence was truncated/);
});

test('malformed journey evidence is rejected instead of presenting a JSON prefix', t => {
  const dir = scratch(t);
  fs.mkdirSync(path.join(dir, 'evidence/verify-appearance'));
  fs.writeFileSync(path.join(dir, 'evidence/verify-appearance/result.json'), '{"status":"passed",');
  assert.throws(() => verifier.judgeInputs(dir, path.join(dir, 'evidence')), /JSON/);
});

test('CI-only review retains the end of the patch and current-head check snapshot', t => {
  const dir = scratch(t);
  const head = 'a'.repeat(40);
  put(dir, 'pr.json', { headRefOid: head });
  put(dir, 'selection.json', { features: [] });
  const checks = Array.from({ length: 160 }, (_, i) => ({ name: `check-${i}`, head_sha: head, conclusion: 'success' }));
  put(dir, 'ci.json', { checks });
  const patch = '+ source change\n'.repeat(3000) + '+ final security-sensitive change\n';
  fs.writeFileSync(path.join(dir, 'diff.patch'), patch);
  const actual = documents(verifier.judgeInputs(dir, path.join(dir, 'evidence')));
  assert.ok(actual.get('ci.json').includes('check-159'), 'the last current-head check must reach the judge');
  assert.deepEqual(JSON.parse(actual.get('ci.json')), { checks });
  assert.equal(actual.get('diff.patch'), patch.trim());
});

test('compaction preserves exact native integers and whitespace inside evidence strings', t => {
  const dir = scratch(t);
  const file = 'evidence/verify-appearance/result.json';
  fs.mkdirSync(path.dirname(path.join(dir, file)), { recursive: true });
  const text = '{\n  "timestamp": 134394473561627019,\n  "detail": " native\\ttext \\"quote\\" \\\\ end "\n}';
  fs.writeFileSync(path.join(dir, file), '\uFEFF' + text);
  const actual = documents(verifier.judgeInputs(dir, path.join(dir, 'evidence'))).get(file);
  assert.equal(actual, '{"timestamp":134394473561627019,"detail":" native\\ttext \\"quote\\" \\\\ end "}');
  assert.deepEqual(JSON.parse(actual), JSON.parse(text));
});
