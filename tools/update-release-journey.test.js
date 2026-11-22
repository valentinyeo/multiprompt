const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

const journeyPath = 'tools/update-release-journey.ps1';
const harnessPath = 'tools/update-release.test.ps1';

function harnessProofs() {
  return [...read(harnessPath).matchAll(/Passed '([^']+)'/g)].map(match => match[1]);
}

function journeyRequirements() {
  const journey = read(journeyPath);
  const list = journey.match(/\$proofNames = @\(([\s\S]*?)\)/);
  assert.ok(list, 'the journey declares the proof names it waits for');
  return [...list[1].matchAll(/'([^']+)'/g)].map(match => match[1]);
}

test('the update journey waits only for proofs the signed release harness passes', () => {
  const proofs = harnessProofs();
  assert.ok(proofs.length > 0, 'the harness announces its proofs by name');
  const required = journeyRequirements();
  for (const name of required) {
    assert.ok(proofs.includes(name), `journey waits for a proof the harness never passes: ${name}`);
  }
  assert.doesNotMatch(read(journeyPath), /locked backup update succeeds/);
  assert.ok(required.includes('update with old bridge helper running succeeds'));
  assert.ok(required.includes('update leaves no usage helper process'));
});

test('the update journey writes result.json only after its final check', () => {
  const journey = read(journeyPath);
  const write = journey.indexOf("feature = 'safe-updates'");
  assert.ok(write > 0, 'the journey writes evidence/result.json itself');
  const resultLine = journey.slice(write, journey.indexOf('\n', write));
  assert.match(resultLine, /'result\.json'/);
  assert.match(resultLine, /status = 'passed'/);
  for (const earlier of ['$proofNames', 'Missing signed local release proof', 'update-card-notes.png', 'Signed local release journey did not finish']) {
    const index = journey.indexOf(earlier);
    assert.ok(index > 0 && index < write, `${earlier} runs before the result is written`);
  }
  assert.equal(journey.split("'result.json'").length - 1, 1, 'the result is written once');
});

test('the workflow only fills in a result the journey never wrote, and never calls it passed', () => {
  const workflow = read('.github/workflows/verify.yml');
  const retain = workflow.match(/name: Retain pre-launch failure result[\s\S]*?run: \|\n([\s\S]*?)\n      - /)[1];
  assert.match(retain, /if \(\$env:FEATURE -eq 'safe-updates' -and \(Test-Path evidence\/safe-updates\.json\) -and -not \(Test-Path evidence\/result\.json\)\)/);
  const fallback = retain.split('\n').find(line => line.includes("feature = 'safe-updates';"));
  assert.ok(fallback, 'the workflow keeps a fallback result for a journey that produced none');
  assert.match(fallback, /status = 'failed'/);
  assert.doesNotMatch(fallback, /\$proof\.success/);
});
