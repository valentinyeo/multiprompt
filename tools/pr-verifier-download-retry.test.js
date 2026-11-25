const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.join(__dirname, '..');
const headSha = 'c'.repeat(40);
const ARCHIVE = 'UEsDBBQAAAAAAA6uc13SG9tWgQAAAIEAAAALAAAAcmVzdWx0Lmpzb257InN0YXR1cyI6ICJwYXNzZWQiLCAidmVyc2lvbiI6ICIyODYwIiwgImNoZWNrcyI6IFt7Im5hbWUiOiAib3B0aW9ucyIsICJwYXNzZWQiOiB0cnVlfV0sICJjbGVhbnVwIjogIm93bmVkIHByb2Nlc3MgdHJlZSBzdG9wcGVkIn1QSwMEFAAAAAAADq5zXSaklQdGAAAARgAAABQAAABldmlkZW5jZS9vcHRpb25zLnBuZ4lQTkcNChoKAAAADUlIRFIAAAABAAAAAQgGAAAAHxXEiQAAAA1JREFUeNpj/M/AUA8ABIUBgISpjCEAAAAASUVORK5CYIJQSwMEFAAAAAAAyQp5XYKWqY8LAAAACwAAAAsAAABqb3VybmV5Lm1wNG1wNC1maXh0dXJlUEsBAhQDFAAAAAAADq5zXdIb21aBAAAAgQAAAAsAAAAAAAAAAAAAAIABAAAAAHJlc3VsdC5qc29uUEsBAhQDFAAAAAAADq5zXSaklQdGAAAARgAAABQAAAAAAAAAAAAAAIABqgAAAGV2aWRlbmNlL29wdGlvbnMucG5nUEsBAhQDFAAAAAAAyQp5XYKWqY8LAAAACwAAAAsAAAAAAAAAAAAAAIABIgEAAGpvdXJuZXkubXA0UEsFBgAAAAADAAMAtAAAAFYBAAAAAA==';

function scratch(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-download-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return dir;
}

function fakeGh(dir) {
  fs.writeFileSync(path.join(dir, 'gh'), `#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.GH_REQUESTS, JSON.stringify(args) + '\\n');
const endpoint = args[1] || '';
if (/\\/artifacts\\/\\d+\\/zip$/.test(endpoint)) {
  const seen = fs.existsSync(process.env.GH_COUNTER) ? Number(fs.readFileSync(process.env.GH_COUNTER, 'utf8')) : 0;
  fs.writeFileSync(process.env.GH_COUNTER, String(seen + 1));
  if (seen < Number(process.env.GH_TRANSIENT)) {
    console.error('gh: HTTP 503');
    process.exit(1);
  }
  process.stdout.write(fs.readFileSync(process.env.GH_ARCHIVE));
} else {
  console.log(JSON.stringify({ id: 11, name: 'verify-chat-options', created_at: '2026-11-19T19:47:23Z', expired: false }));
}
`, { mode: 0o755 });
  return {
    PATH: `${dir}${path.delimiter}${process.env.PATH}`,
    GH_REQUESTS: path.join(dir, 'requests.jsonl'),
    GH_COUNTER: path.join(dir, 'counter'),
    GH_ARCHIVE: path.join(dir, 'evidence.zip'),
    RUN_ID: '44599015698',
    REPO: 'valentinyeo/multiprompt',
    BASE_SHA: 'b'.repeat(40),
  };
}

function writeSelection(dir) {
  const selection = path.join(dir, 'selection.json');
  fs.writeFileSync(path.join(dir, 'pr.json'), JSON.stringify({ headRefOid: headSha }));
  fs.writeFileSync(selection, JSON.stringify({ features: ['chat-options'], reason: 'Downloaded journey evidence' }));
  return selection;
}

function run(env, args) {
  return spawnSync(process.execPath, [path.join(root, 'tools/pr-verifier.cjs'), ...args], { encoding: 'utf8', env: { ...process.env, ...env } });
}

test('a transient artifact download error is retried so the journeys stay readable', t => {
  const dir = scratch(t);
  fs.writeFileSync(path.join(dir, 'evidence.zip'), Buffer.from(ARCHIVE, 'base64'));
  const env = { ...fakeGh(dir), GH_TRANSIENT: '2', ARTIFACT_ATTEMPTS: '5', ARTIFACT_RETRY_MS: '0' };
  const selection = writeSelection(dir);
  const evidence = path.join(dir, 'evidence');
  const download = run(env, ['download', selection, evidence]);
  assert.equal(download.status, 0, download.stderr);
  assert.match(download.stdout, /downloaded 1 of 1 evidence artifacts/);
  const result = path.join(evidence, 'verify-chat-options/result.json');
  assert.ok(fs.existsSync(result), 'the retried artifact must land in evidence');
  assert.equal(JSON.parse(fs.readFileSync(result, 'utf8')).status, 'passed');
  const zipCalls = fs.readFileSync(env.GH_REQUESTS, 'utf8').trim().split('\n').map(JSON.parse)
    .filter(args => /\/artifacts\/\d+\/zip$/.test(args[1] || ''));
  assert.equal(zipCalls.length, 3, 'two transient errors then the real archive');
  const summarize = run(env, ['summarize', evidence, selection, dir]);
  assert.equal(summarize.status, 0, summarize.stderr);
  const summary = fs.readFileSync(path.join(dir, 'evidence.md'), 'utf8');
  assert.match(summary, /## chat-options: head passed/);
  assert.doesNotMatch(summary, /could not be downloaded/);
});

test('an artifact that never downloads is named in the verdict instead of reported as every journey missing', t => {
  const dir = scratch(t);
  fs.writeFileSync(path.join(dir, 'evidence.zip'), Buffer.from(ARCHIVE, 'base64'));
  const env = { ...fakeGh(dir), GH_TRANSIENT: '99', ARTIFACT_ATTEMPTS: '2', ARTIFACT_RETRY_MS: '0', HEAD_SHA: headSha, RUN_URL: 'https://github.com/valentinyeo/multiprompt/actions/runs/44599015698' };
  const selection = writeSelection(dir);
  const evidence = path.join(dir, 'evidence');
  const download = run(env, ['download', selection, evidence]);
  assert.equal(download.status, 0, download.stderr);
  const failures = JSON.parse(fs.readFileSync(path.join(evidence, 'download-failures.json'), 'utf8'));
  assert.deepEqual(failures.map(item => item.artifact), ['verify-chat-options']);
  assert.match(failures[0].error, /HTTP 503/);
  const summarize = run(env, ['summarize', evidence, selection, dir]);
  assert.equal(summarize.status, 0, summarize.stderr);
  assert.match(fs.readFileSync(path.join(dir, 'evidence.md'), 'utf8'), /## Evidence artifacts that could not be downloaded\n\n- verify-chat-options: .*HTTP 503/);
  const finalize = run({ ...env, JOB_RESULTS: '{}' }, ['finalize', selection, path.join(dir, 'summary.json'), dir]);
  assert.equal(finalize.status, 0, finalize.stderr);
  const comment = fs.readFileSync(path.join(dir, 'comment.md'), 'utf8');
  assert.match(comment, /^pstack-verifier: BLOCKED @ c{40}/);
  assert.match(comment, /- Evidence artifact verify-chat-options could not be downloaded: .*HTTP 503\./);
  assert.match(comment, /- chat-options: head missing/);
  assert.doesNotMatch(comment, /Selection or journey evidence is missing or unreadable/);
});
