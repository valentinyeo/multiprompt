import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const moduleUrl = new URL('./verify-skill-eval.mjs', import.meta.url);
assert.ok(fs.existsSync(moduleUrl), 'The verification skill needs its executable exercise runner');
const { grade, judgePassed, parseAnswer, plant, prompt, workspace } = await import(moduleUrl.href);

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
    fs.writeFileSync(file, scenario.seed.before.replaceAll('\n', '\r\n'));
    plant(root, scenario);
    assert.equal(fs.readFileSync(file, 'utf8'), scenario.seed.after.replaceAll('\n', '\r\n'));
  });
}

test('each planted regression matches the current production source exactly once', () => {
  for (const scenario of cases.filter(item => item.seed)) {
    const source = fs.readFileSync(new URL(`../${scenario.seed.file}`, import.meta.url), 'utf8').replaceAll('\r\n', '\n');
    assert.equal(source.split(scenario.seed.before).length - 1, 1, scenario.id);
  }
});

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

test('reading the skill or index only after execution does not count', () => {
  for (const late of [0, 1]) {
    const fixture = proof(cases[0]);
    fixture.transcript.push(fixture.transcript.splice(late, 1)[0]);
    assert.equal(check(cases[0], fixture).passed, false);
  }
});

test('wrong journey and fabricated citations fail even with the expected verdict', () => {
  const fixture = proof(cases[0]);
  fixture.journey.feature = 'inbox';
  fixture.answer.evidence[0].file = 'evidence/nonexistent.json';
  const result = check(cases[0], fixture);
  assert.equal(result.checks.ran_correct_journey, false);
  assert.equal(result.checks.file_backed_evidence, false);
});

test('recipe citations can explain observations but cannot replace product evidence', () => {
  const fixture = proof(cases[0]);
  fixture.answer.evidence.push({ file: `${skill}/features/appearance.md`, observation: 'The recipe requires a saved Light choice.' });
  assert.equal(check(cases[0], fixture).passed, true);
  fixture.answer.evidence.shift();
  assert.equal(check(cases[0], fixture).passed, false);
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

test('the independent judge accepts only the known runner bots without relaxing PR trust', () => {
  const workflow = fs.readFileSync(new URL('../.github/workflows/verify-skill-eval.yml', import.meta.url), 'utf8');
  const judge = workflow.split('id: judge')[1].split('- name: Require both')[0];
  assert.match(judge, /allowed_bots: software-factory-runners,hypertask-runners\s/);
  assert.doesNotMatch(judge, /restrict_untrusted_prs:\s*["']?false/);
});

test('an existing but unread screenshot cannot support a passing answer', () => {
  const fixture = proof(cases[0]);
  fixture.evidence['evidence/after.png'] = { image: 'after.png' };
  fixture.answer.evidence.push({ file: 'evidence/after.png', observation: 'The file exists, but I could not inspect it.' });
  assert.equal(check(cases[0], fixture).checks.file_backed_evidence, false);
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

test('Codex workspace receives hosted context without credentials and still rejects non-Windows runners', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-workspace-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const clients = path.join(root, 'clients');
  const client = path.join(clients, 'node_modules/@openai/codex/bin/codex.js');
  fs.mkdirSync(path.dirname(client), { recursive: true });
  fs.writeFileSync(client, `
    const fs = require('node:fs');
    const { spawnSync } = require('node:child_process');
    const args = process.argv.slice(2);
    const option = name => JSON.parse(args.find(arg => arg.startsWith(name + '=')).slice(name.length + 1));
    const names = ['PATH', 'SystemRoot', ...(args.some(arg => arg.startsWith('mcp_servers.workspace.env_vars=')) ? option('mcp_servers.workspace.env_vars') : [])];
    const env = Object.fromEntries(names.filter(name => process.env[name] !== undefined).map(name => [name, process.env[name]]));
    const input = JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: 'run_journey', arguments: { feature: 'appearance' } } }) + '\\n';
    const child = spawnSync(option('mcp_servers.workspace.command'), option('mcp_servers.workspace.args'), { input, env, encoding: 'utf8', timeout: 10000 });
    if (child.status !== 0) throw new Error(child.stderr || child.error?.message);
    fs.writeFileSync(args[args.indexOf('--output-last-message') + 1], JSON.stringify({ verdict: 'BLOCKED', evidence: [{ file: 'probe', observation: JSON.stringify({ env, response: JSON.parse(child.stdout) }) }] }));
  `);
  fs.mkdirSync(path.join(root, 'desktop'));
  fs.writeFileSync(path.join(root, 'desktop/multiprompt.exe'), 'not an executable');
  fs.writeFileSync(path.join(root, 'desktop/build.json'), JSON.stringify({ sha256: 'incorrect' }));
  fs.cpSync(new URL('../.claude/', import.meta.url), path.join(root, '.claude'), { recursive: true });
  for (const [index, runner] of [
    { GITHUB_ACTIONS: 'true', RUNNER_OS: 'Windows' },
    { GITHUB_ACTIONS: 'true', RUNNER_OS: 'Linux' },
    { GITHUB_ACTIONS: 'false', RUNNER_OS: 'Windows' },
  ].entries()) {
    const out = path.join(root, `output-${index}`);
    const runnerTemp = path.join(root, `runner-${index}`);
    const child = spawnSync(process.execPath, [fileURLToPath(moduleUrl), 'agent', root, 'maple', 'codex', out], {
      encoding: 'utf8', timeout: 20000,
      env: { ...process.env, ...runner, RUNNER_TEMP: runnerTemp, CLIENTS: clients, CODEX_AUTH_JSON: '{}', DEEPSEEK_API_KEY: 'private', GH_TOKEN: 'private', GITHUB_TOKEN: 'private' },
    });
    assert.equal(child.status, 0, child.stderr);
    const answer = JSON.parse(fs.readFileSync(path.join(out, 'answer.json'), 'utf8'));
    const probe = JSON.parse(answer.evidence[0].observation);
    assert.equal(probe.env.GITHUB_ACTIONS, runner.GITHUB_ACTIONS);
    assert.equal(probe.env.RUNNER_OS, runner.RUNNER_OS);
    assert.equal(probe.env.RUNNER_TEMP, runnerTemp);
    for (const name of ['CODEX_AUTH_JSON', 'DEEPSEEK_API_KEY', 'GH_TOKEN', 'GITHUB_TOKEN']) assert.equal(probe.env[name], undefined);
    assert.equal(probe.response.result.isError, true);
    assert.equal(probe.response.result.content[0].text, index === 0 ? 'Downloaded executable hash mismatch' : 'Desktop journeys require hosted Windows');
  }
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
