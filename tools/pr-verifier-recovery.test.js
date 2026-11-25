const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const verifier = require('./pr-verifier.cjs');

const recovery = require('./fixtures/SOFT-2498/recovery.json');
const artifacts = require('./fixtures/SOFT-2498/artifacts.json');
const expectedArtifactIds = [...artifacts.expectedIds, 14246149485, 14246145450];

for (const verdict of ['PASS', 'PASS+NOTES']) {
  test(`${verdict} is recognized with GitHub's rewritten check URL`, () => {
    const check = structuredClone(recovery.checks[1]);
    check.output.summary = check.output.summary.replace('PASS+NOTES', verdict);
    assert.equal(verifier.recoveryNeeded(recovery.run, recovery.headSha, [check]), false);
  });

  test(`a later ${verdict} can repair an older recovery BLOCKED`, () => {
    const check = structuredClone(recovery.checks[1]);
    check.output.summary = check.output.summary.replace('PASS+NOTES', verdict).replace(String(recovery.run.id), String(recovery.run.id + 1));
    assert.equal(verifier.recoveryNeeded(recovery.run, recovery.headSha, [recovery.checks[0], check]), true);
  });

  test(`a later posted ${verdict} supersedes an earlier FAIL and recovery BLOCKED`, () => {
    const comment = result => ({ user: { login: 'github-actions[bot]' }, body: recovery.checks[1].output.summary.replace('PASS+NOTES', result) });
    assert.equal(verifier.recoveryReport(recovery.run, recovery.headSha, [comment('FAIL'), comment('BLOCKED'), comment(verdict), comment('BLOCKED')]).result, verdict);
  });
}

test('an older verdict or a different head cannot suppress genuine recovery', () => {
  const check = structuredClone(recovery.checks[1]);
  check.output.summary = check.output.summary.replace(String(recovery.run.id), String(recovery.run.id - 1));
  check.completed_at = '2026-11-16T15:00:00Z';
  assert.equal(verifier.recoveryNeeded(recovery.run, recovery.headSha, [check]), true);
  assert.equal(verifier.recoveryNeeded(recovery.run, 'a'.repeat(40), recovery.checks), true);
});

test('retry collection selects one newest base and head artifact ID per journey', () => {
  assert.equal(typeof verifier.latestArtifacts, 'function');
  const selected = verifier.latestArtifacts(artifacts.artifacts, artifacts.selection);
  assert.deepEqual(selected.map(item => item.id).sort(), [...expectedArtifactIds].sort());
  assert.equal(new Set(selected.map(item => item.name)).size, selected.length);
  assert.deepEqual(verifier.latestArtifacts([...artifacts.artifacts].reverse(), artifacts.selection), selected);
  assert.equal(selected.filter(item => item.name.endsWith(artifacts.baseSha)).length, 2);
});

test('retry collection downloads exact IDs and replaces evidence without duplicate extraction', { skip: process.platform !== 'linux' }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-retry-'));
  try {
    const bin = path.join(dir, 'bin');
    fs.mkdirSync(bin);
    fs.writeFileSync(path.join(bin, 'gh'), `#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.GH_REQUESTS, JSON.stringify(args) + '\\n');
if (args[0] === 'run') {
  console.error('duplicate artifact extraction: action.focus.json: file exists');
  process.exit(1);
}
if (args.some(arg => /\\/artifacts\\/\\d+\\/zip$/.test(arg))) {
  process.stdout.write(Buffer.from(process.env.GH_ARCHIVE, 'base64'));
} else {
  const artifacts = JSON.parse(fs.readFileSync(process.env.GH_ARTIFACTS, 'utf8')).artifacts;
  process.stdout.write(artifacts.map(item => args.includes('.artifacts[].name') ? item.name : JSON.stringify(item)).join('\\n') + '\\n');
}
`, { mode: 0o755 });
    const selection = path.join(dir, 'selection.json');
    fs.writeFileSync(selection, JSON.stringify(artifacts.selection));
    const evidence = path.join(dir, 'evidence');
    const requests = path.join(dir, 'requests.jsonl');
    const env = {
      ...process.env,
      PATH: `${bin}${path.delimiter}${process.env.PATH}`,
      REPO: 'valentinyeo/multiprompt',
      RUN_ID: artifacts.runId,
      GH_ARTIFACTS: path.join(__dirname, 'fixtures/SOFT-2498/artifacts.json'),
      GH_REQUESTS: requests,
      GH_ARCHIVE: 'UEsDBBQAAAAAAAAAIVw/cY1iJQAAACUAAAALAAAAcmVzdWx0Lmpzb257InN0YXR1cyI6InBhc3NlZCIsInZlcnNpb24iOiJyZXRyeSJ9UEsDBBQAAAAAAAAAIVys7j7LFAAAABQAAAARAAAAYWN0aW9uLmZvY3VzLmpzb257ImNhcHR1cmUiOiJsYXRlc3QifVBLAQIUAxQAAAAAAAAAIVw/cY1iJQAAACUAAAALAAAAAAAAAAAAAACAAQAAAAByZXN1bHQuanNvblBLAQIUAxQAAAAAAAAAIVys7j7LFAAAABQAAAARAAAAAAAAAAAAAACAAU4AAABhY3Rpb24uZm9jdXMuanNvblBLBQYAAAAAAgACAHgAAACRAAAAAAA=',
    };
    for (let attempt = 0; attempt < 2; attempt++) {
      const result = spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'download', selection, evidence], { env, encoding: 'utf8' });
      assert.equal(result.status, 0, result.stderr);
      for (const name of ['verify-chat-focus', 'verify-command-palette']) {
        const proof = path.join(evidence, name, 'action.focus.json');
        assert.ok(fs.existsSync(proof), `${name} retained its evidence`);
        assert.equal(JSON.parse(fs.readFileSync(proof, 'utf8')).capture, 'latest');
      }
    }
    const calls = fs.readFileSync(requests, 'utf8').trim().split('\n').map(line => JSON.parse(line));
    const downloaded = calls.flatMap(args => args.filter(arg => /\/artifacts\/\d+\/zip$/.test(arg)).map(arg => Number(arg.match(/\/artifacts\/(\d+)\/zip$/)[1])));
    assert.deepEqual(downloaded.sort(), [...expectedArtifactIds, ...expectedArtifactIds].sort());
    assert.ok(calls.every(args => args[0] !== 'run'));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('a later successful retry of an older run suppresses recovery', () => {
  const check = structuredClone(recovery.checks[1]);
  check.output.summary = check.output.summary.replace(String(recovery.run.id), String(recovery.run.id - 1));
  assert.equal(verifier.recoveryNeeded(recovery.run, recovery.headSha, [check]), false);
});

test('verdict and recovery writers share a non-cancelling publication lock', () => {
  const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/pr-verifier.yml'), 'utf8');
  const observer = fs.readFileSync(path.join(__dirname, '../.github/workflows/pr-verifier-blocked.yml'), 'utf8');
  assert.match(workflow, /run-name: verify PR \$\{\{ inputs.pr \|\| github.event.pull_request.number \}\}/);
  assert.match(workflow, /group: pstack-verdict-\$\{\{ format\('verify PR \{0\}', inputs.pr \|\| github.event.pull_request.number\) \}\}\n      cancel-in-progress: false/);
  assert.match(observer, /group: pstack-verdict-\$\{\{ github.event.workflow_run.display_title \}\}\n      cancel-in-progress: false/);
});

for (const gate of ['success', 'success-after-blocked', 'success-after-blocked-history', 'failure', 'queued', 'api-error']) {
  test(`recovering a published PASS+NOTES with Tests ${gate} stays fail-closed`, { skip: process.platform !== 'linux' }, () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-publish-'));
    try {
      const bin = path.join(dir, 'bin');
      fs.mkdirSync(bin);
      const requests = path.join(dir, 'requests.jsonl');
      const event = path.join(dir, 'event.json');
      fs.writeFileSync(event, JSON.stringify({ workflow_run: { ...recovery.run, event: 'workflow_dispatch', head_repository: { full_name: 'valentinyeo/multiprompt' }, display_title: 'verify PR 1052', pull_requests: [{ number: 1052, head: { sha: recovery.headSha } }] } }));
      fs.writeFileSync(path.join(bin, 'gh'), `#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.GH_REQUESTS, JSON.stringify(args) + '\\n');
const head = process.env.HEAD_SHA;
const repo = 'valentinyeo/multiprompt';
const fixture = JSON.parse(fs.readFileSync(process.env.GH_RECOVERY, 'utf8'));
const endpoint = args.find(arg => arg.startsWith('repos/')) || '';
if (args.includes('graphql')) {
  if (process.env.GH_GATE === 'api-error') process.exit(1);
  const checks = process.env.GH_BLOCKED === 'true' ? fixture.checks.slice(0, process.env.GH_HISTORY === 'true' ? 2 : 1) : [];
  const verdicts = checks.map(check => ({ databaseId: check.id, name: check.name, status: check.status.toUpperCase(), conclusion: check.conclusion.toUpperCase(), completedAt: check.completed_at, summary: check.output.summary }));
  process.stdout.write(JSON.stringify({ data: { repository: { pullRequest: { number: 1052, state: 'OPEN', isDraft: false, title: '', body: '', headRefOid: head, baseRefName: 'master', headRepository: { nameWithOwner: repo }, comments: { nodes: [{ author: { login: 'github-actions[bot]' }, body: fixture.checks[1].output.summary }] }, commits: { nodes: [{ commit: { checkSuites: { nodes: [{ status: process.env.GH_GATE === 'queued' ? 'QUEUED' : 'COMPLETED', conclusion: process.env.GH_GATE.toUpperCase(), workflowRun: { databaseId: 1, workflow: { name: 'Tests' } }, verdicts: { nodes: verdicts } }] } } }] } } } } }));
} else if (args[0] === 'pr' || args.includes('POST')) process.stdout.write('{}');
else if (endpoint.endsWith('/pulls/1052')) process.stdout.write(JSON.stringify({ state: 'open', head: { sha: head, repo: { full_name: repo } } }));
else if (endpoint.includes('/commits/')) process.stdout.write(process.env.GH_BLOCKED === 'true' ? fixture.checks.slice(0, process.env.GH_HISTORY === 'true' ? 2 : 1).map(check => JSON.stringify(check)).join('\\n') + '\\n' : '');
else if (endpoint.includes('/comments')) process.stdout.write(JSON.stringify({ user: { login: 'github-actions[bot]' }, body: fixture.checks[1].output.summary }) + '\\n');
else if (endpoint.includes('/test.yml/runs')) {
  if (process.env.GH_GATE === 'api-error') process.exit(1);
  process.stdout.write(JSON.stringify([{ id: 1, status: process.env.GH_GATE === 'queued' ? 'queued' : 'completed', conclusion: process.env.GH_GATE }]));
} else process.exit(2);
`, { mode: 0o755 });
      const result = spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'recover'], { encoding: 'utf8', env: {
        ...process.env, PATH: `${bin}${path.delimiter}${process.env.PATH}`, REPO: 'valentinyeo/multiprompt', HEAD_SHA: recovery.headSha,
        GITHUB_EVENT_PATH: event, GH_REQUESTS: requests, GH_GATE: gate.startsWith('success') ? 'success' : gate, GH_BLOCKED: String(gate.startsWith('success-after-blocked')), GH_HISTORY: String(gate.endsWith('-history')), GH_RECOVERY: path.join(__dirname, 'fixtures/SOFT-2498/recovery.json'),
      } });
      const calls = fs.readFileSync(requests, 'utf8').trim().split('\n').map(line => JSON.parse(line));
      if (gate === 'api-error') {
        assert.notEqual(result.status, 0);
        assert.equal(calls.some(args => args.includes('conclusion=success')), false);
        return;
      }
      assert.equal(result.status, 0, result.stderr);
      const check = calls.find(args => args.includes('name=pstack-verifier'));
      assert.ok(check, 'Recovery published the required head check');
      assert.ok(check.includes(`conclusion=${gate.startsWith('success') ? 'success' : 'failure'}`));
      assert.ok(check.includes(`output[title]=pstack-verifier: ${gate.startsWith('success') ? 'PASS+NOTES' : 'BLOCKED'}`));
      assert.equal(calls.filter(args => args.includes('graphql')).length, 1);
      assert.equal(calls.some(args => args.some(arg => /\/(?:comments|pulls\/1052|check-runs\?)/.test(arg))), false);
      assert.equal(calls.filter(args => args.some(arg => arg.includes('/test.yml/runs?head_sha='))).length, gate === 'queued' ? 0 : 1);
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });
}

test('an existing recovery BLOCKED is not a terminal verdict that hides later proof', () => {
  assert.equal(verifier.recoveryNeeded(recovery.run, recovery.headSha, [recovery.checks[0]]), true);
});
