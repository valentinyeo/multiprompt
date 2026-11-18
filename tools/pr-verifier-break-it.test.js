const assert = require('node:assert/strict');
const { test } = require('node:test');
const verifier = require('./pr-verifier.cjs');

function finish(breakIt) {
  const selection = verifier.validateSelection({ features: ['appearance'] }, ['appearance'], {
    title: 'fix: preserve appearance', body: 'Repro journey: `appearance`',
  });
  const run = { status: 'passed', artifact: 'verify-appearance', screenshots: ['after.png'], breakIt };
  return verifier.finalize({ verdict: { verdict: 'PASS' }, selection,
    summary: { head: { appearance: [run] }, base: { appearance: [{ ...run, status: 'failed', error: 'wrong theme' }] } } });
}

const passed = () => ({ feature: 'appearance', status: 'passed', variations: ['resize', 'maximize', 'fast-switch', 'long-chat'].map(name => ({
  name, status: 'passed', screenshots: ['after.png'], video: 'journey.mp4', videoVerified: true, actions: 1, cleanup: 'complete',
})) });

test('a passing repro and model cannot approve a repair without break-it evidence', () => {
  assert.equal(finish(undefined).final, 'BLOCKED');
});

test('every applicable variation needs input, screenshots, video and cleanup', () => {
  assert.equal(finish(passed()).final, 'PASS');
  for (const field of ['video', 'videoVerified', 'actions', 'cleanup']) {
    const proof = passed();
    delete proof.variations[0][field];
    assert.equal(finish(proof).final, 'BLOCKED', field);
  }
  const proof = passed();
  proof.variations.pop();
  assert.equal(finish(proof).final, 'BLOCKED');
});

test('a variation that revives the bug fails even with passing normal head and failing master', () => {
  const proof = passed();
  proof.status = 'failed';
  proof.variations[0].status = 'failed';
  proof.variations[0].error = 'original bug returned after resize';
  const result = finish(proof);
  assert.equal(result.final, 'FAIL');
  assert.match(result.body, /resize.*journey\.mp4/);
});

test('a runner failure is blocked, not a product failure', () => {
  const proof = passed();
  proof.variations[0].status = 'failed';
  proof.variations[0].failureKind = 'infrastructure';
  proof.variations[0].error = 'Recorder failed';
  assert.equal(finish(proof).final, 'BLOCKED');
});

test('the historical experiment cannot turn a feature PR into a claimed repair', () => {
  const selection = verifier.validateSelection({ features: [] }, ['chat-working-live'], {
    title: 'Challenge repair journeys', files: [{ path: '.claude/skills/verify-multiprompt/break-it.ps1' }],
  });
  assert.deepEqual(selection.features, ['chat-working-live']);
  assert.deepEqual(selection.breakItFeatures, []);
  assert.equal(selection.breakItHistory, '5ce536b45569e8cb4394e8e967067f19bf3d49d0');
  const run = { feature: 'chat-working-live', status: 'passed', screenshots: ['after.png'], breakIt: {
    feature: 'chat-working-live', variations: [{ ...passed().variations[0], status: 'failed', error: 'Reply disappeared after resizing' }],
  } };
  const finishHistory = history => verifier.finalize({ verdict: { verdict: 'PASS' }, selection,
    summary: { head: { 'chat-working-live': [{ status: 'passed', screenshots: ['after.png'] }] }, base: {}, history }, jobs: { history: { result: 'success' } } });
  assert.equal(finishHistory([]).final, 'FAIL');
  assert.equal(finishHistory([run]).final, 'PASS');
  run.breakIt.variations[0].videoVerified = false;
  assert.equal(finishHistory([run]).final, 'FAIL');
});

test('window variations keep the Doctor-guarded input path on both entry points', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  for (const file of ['.claude/skills/verify-multiprompt/control.ps1', 'tools/verify-chat-delivery/drive.ps1']) {
    const source = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
    assert.match(source, /Invoke-BreakItWindow[^\n]+\{ param\(\$keys\) Press \$keys /, file);
  }
});

test('chat journeys require streaming, busy-send and reconnect variations too', () => {
  assert.equal(typeof verifier.breakItVariations, 'function');
  assert.deepEqual(verifier.breakItVariations('chat-delivery'), ['resize', 'maximize', 'fast-switch', 'long-chat', 'stream-scroll', 'busy-send', 'reconnect']);
});

test('batched builds replay only the named repair and isolate the historical experiment', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const { runInNewContext } = require('node:vm');
  const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/verify.yml'), 'utf8');
  const parent = fs.readFileSync(path.join(__dirname, '../.github/workflows/pr-verifier.yml'), 'utf8');
  assert.match(workflow, /      - name: Try to bring the repaired bug back\n/);
  const condition = workflow.split('      - name: Try to bring the repaired bug back\n')[1].split('\n')[0].trim().slice(4);
  for (const feature of ['appearance', 'chat-still', 'chat-working-live']) {
    const actual = runInNewContext(condition, {
      success: () => true, fromJSON: JSON.parse, contains: (items, item) => items.includes(item),
      inputs: { break_it_features: '["chat-working-live"]' }, matrix: { feature },
    });
    assert.equal(actual, feature === 'chat-working-live');
  }
  const head = parent.split('  head:\n')[1].split('  history:\n')[0];
  assert.match(head, /break_it_features: \$\{\{ needs\.select\.outputs\.break_it_features \}\}/);
  assert.doesNotMatch(head, /matrix\./);
  assert.match(parent, /break_it_features: '\["chat-working-live"\]'/);
});

test('large journey sets keep every outcome and historical variation in the judge input', t => {
  const fs = require('node:fs');
  const path = require('node:path');
  const directory = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'judge-break-it-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const evidence = path.join(directory, 'evidence');
  const history = '5ce536b45569e8cb4394e8e967067f19bf3d49d0';
  const features = ['chat-working-live', ...Array.from({ length: 80 }, (_, i) => `journey-${String(i).padStart(2, '0')}`)];
  const write = (name, data) => {
    const file = path.join(evidence, name);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, data);
  };
  for (const name of [...features.map(feature => `verify-${feature}`), `verify-chat-working-live-${history}`]) {
    write(`${name}/result.json`, JSON.stringify({ status: 'passed', checks: ['original assertions', 'x'.repeat(12000)] }));
    write(`${name}/doctor.json`, JSON.stringify({ alive: true }));
    for (let i = 0; i < 12; i++) write(`${name}/shot-${i}.png`, 'png');
  }
  const root = `verify-chat-working-live-${history}/break-it`;
  const variations = ['resize', 'maximize', 'fast-switch', 'long-chat', 'stream-scroll', 'busy-send', 'reconnect'].map(name => {
    write(`${root}/${name}/after.png`, 'png');
    write(`${root}/${name}/journey.mp4`, 'video');
    write(`${root}/${name}/video.json`, JSON.stringify({ streams: [{ width: 1024, height: 768 }] }));
    write(`${root}/${name}/break-it-input.json`, JSON.stringify({ actions: ['physical input'] }));
    return { name, status: name === 'maximize' ? 'failed' : 'passed', error: name === 'maximize' ? 'missing inline dots' : '', cleanup: 'complete', actions: 1 };
  });
  write(`${root}/result.json`, JSON.stringify({ feature: 'chat-working-live', status: 'failed', variations }));
  fs.writeFileSync(path.join(directory, 'selection.json'), JSON.stringify({ features, breakItHistory: history, compareBase: false }));
  const result = require('node:child_process').spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'summarize', evidence, path.join(directory, 'selection.json'), 'b'.repeat(40), directory], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  const material = fs.readFileSync(path.join(directory, 'judge-inputs.md'), 'utf8');
  assert.ok(material.length <= 60000);
  for (const feature of features) assert.ok(material.includes(`${feature}: head passed`), feature);
  assert.match(material, /historical.*ordinary passed/i);
  for (const { name } of variations) {
    assert.ok(material.includes(`break-it/${name}/journey.mp4`), name);
    assert.ok(material.includes(`break-it/${name}/video.json`), name);
    assert.ok(material.includes(`break-it/${name}/break-it-input.json`), name);
  }
  assert.match(material, /maximize.*failed.*missing inline dots/);
});
