import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { grade, judgePassed, parseAnswer, plant, prompt, workspace } from './verify-skill-eval.mjs';

const cases = JSON.parse(fs.readFileSync(new URL('./verify-skill-cases.json', import.meta.url)));
const skill = '.claude/skills/verify-multiprompt';
const read = file => ({ name: 'read_file', args: { file }, ok: true });

function proof(scenario) {
  const transcript = [`${skill}/SKILL.md`, `${skill}/features/README.md`, `${skill}/features/${scenario.feature}.md`].map(read);
  transcript.push({ name: 'run_journey', args: { feature: scenario.feature }, ok: true });
  transcript.push(read('evidence/result.json'));
  const evidence = {
    'evidence/result.json': { feature: scenario.feature, status: scenario.verdict === 'PASS' ? 'passed' : 'failed', error: scenario.failure?.split('|')[0], sha256: 'a'.repeat(64), scratchRemoved: true },
    'evidence/build.json': { sha256: 'a'.repeat(64) },
    'evidence/doctor.json': { sha256: 'a'.repeat(64), pid: 123, hwnd: 456 },
    'evidence/process-tree.json': { activeAfterStop: 0 },
  };
  return { transcript, journey: { feature: scenario.feature }, answer: { verdict: scenario.verdict, evidence: [{ file: 'evidence/result.json', observation: 'The recorded outcome matches the request.' }] }, evidence };
}
const check = (scenario, fixture) => grade(scenario, fixture.transcript, fixture.journey, fixture.answer, fixture.evidence);

for (const scenario of cases) {
  test(`${scenario.id} requires its own journey and actual outcome`, () => {
    const fixture = proof(scenario);
    assert.equal(check(scenario, fixture).passed, true);
    fixture.answer.verdict = scenario.verdict === 'PASS' ? 'FAIL' : 'PASS';
    assert.equal(check(scenario, fixture).passed, false);
  });
  test(`${scenario.id} source mutation applies once and refuses source drift`, t => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'source-'));
    t.after(() => fs.rmSync(root, { recursive: true, force: true }));
    if (!scenario.seed) { plant(root, scenario); assert.deepEqual(fs.readdirSync(root), []); return; }
    const file = path.join(root, scenario.seed.file);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, scenario.seed.before);
    plant(root, scenario);
    assert.equal(fs.readFileSync(file, 'utf8'), scenario.seed.after);
    assert.throws(() => plant(root, scenario), /exactly once/);
  });
}

test('self-reported recipe selection without actual reads fails', () => {
  const fixture = proof(cases[0]);
  fixture.transcript = fixture.transcript.filter(event => !event.args.file?.endsWith('/appearance.md'));
  assert.equal(check(cases[0], fixture).checks.read_skill_and_recipe, false);
});

test('reading the recipe after execution does not count', () => {
  const fixture = proof(cases[0]);
  fixture.transcript.push(fixture.transcript.splice(2, 1)[0]);
  assert.equal(check(cases[0], fixture).passed, false);
});

test('wrong journey and fabricated citations fail even with the expected verdict', () => {
  const fixture = proof(cases[0]);
  fixture.journey.feature = 'inbox';
  fixture.answer.evidence[0].file = 'evidence/nonexistent.json';
  const result = check(cases[0], fixture);
  assert.equal(result.checks.ran_correct_journey, false);
  assert.equal(result.checks.file_backed_evidence, false);
});

test('infrastructure, absent cleanup and unrelated errors cannot detect planted bugs', () => {
  for (const mutate of [
    fixture => { fixture.evidence['evidence/result.json'].failureKind = 'infrastructure'; },
    fixture => { fixture.evidence['evidence/result.json'].scratchRemoved = false; },
    fixture => { fixture.evidence['evidence/process-tree.json'].activeAfterStop = 1; },
    fixture => { fixture.evidence['evidence/result.json'].error = 'Doctor: owned app window missing'; },
    fixture => { fixture.evidence['evidence/doctor.json'].sha256 = 'b'.repeat(64); },
  ]) {
    const fixture = proof(cases[1]);
    mutate(fixture);
    assert.equal(check(cases[1], fixture).passed, false);
  }
});

test('candidate prompts and visible filenames do not disclose the exercise', () => {
  const forbidden = /\b(eval|test|judge|experiment|rubric|score|compare|benchmark|candidate|arena)\b/i;
  for (const scenario of cases) assert.doesNotMatch(prompt(scenario.prompt), forbidden);
  const names = fs.readdirSync(new URL('../.claude/skills/verify-multiprompt/features/', import.meta.url));
  for (const name of names) assert.doesNotMatch(name, forbidden);
});

test('workspace restricts reads to the published project files', async t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'workspace-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const project = path.join(root, 'multiprompt');
  const out = path.join(root, 'private');
  fs.mkdirSync(project);
  fs.mkdirSync(out);
  fs.writeFileSync(path.join(project, 'README.md'), 'project');
  fs.writeFileSync(path.join(out, 'private.json'), 'secret');
  const call = workspace({ root, out, workspace: project });
  assert.deepEqual(await call('list_files', {}), { files: ['README.md'] });
  assert.equal((await call('read_file', { file: 'README.md' })).text, 'project');
  await assert.rejects(call('read_file', { file: '../private/private.json' }), /not available/);
});

test('malformed responses and empty evidence do not become passes', () => {
  for (const response of ['', '{}', '{"verdict":"PASS","evidence":[]}', '{"verdict":"PASS","evidence":[{"file":"x","observation":""}]}']) assert.throws(() => parseAnswer(response));
});

test('blinded verdict must include each label exactly once and cannot override failed checks', () => {
  const verdict = { verdict: 'PASS', results: [{ label: 'response-1', passed: true, reason: 'Recorded result supports the claim.' }] };
  assert.equal(judgePassed({ passed: true }, verdict, ['response-1']), true);
  assert.equal(judgePassed({ passed: false }, verdict, ['response-1']), false);
  assert.equal(judgePassed({ passed: true }, verdict, ['response-1', 'response-2']), false);
  assert.equal(judgePassed({ passed: true }, { ...verdict, results: [...verdict.results, ...verdict.results] }, ['response-1']), false);
});
