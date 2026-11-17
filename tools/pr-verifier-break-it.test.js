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

test('chat journeys require streaming, busy-send and reconnect variations too', () => {
  assert.equal(typeof verifier.breakItVariations, 'function');
  assert.deepEqual(verifier.breakItVariations('chat-delivery'), ['resize', 'maximize', 'fast-switch', 'long-chat', 'stream-scroll', 'busy-send', 'reconnect']);
});
