const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const workflow = name => fs.readFileSync(path.join(root, '.github/workflows', name), 'utf8');

test('only Tests completion wakes automerge; scheduled recovery remains', () => {
  const text = workflow('automerge.yml');
  assert.match(text, /workflows: \[Tests\]/);
  assert.match(text, /cron: '\*\/15 \* \* \* \*'/);
  assert.match(text, /cancel-in-progress: false/);
});

test('appearance excludes unrelated edits without losing native or journey coverage', () => {
  const text = workflow('verify.yml');
  const paths = text.split('  pull_request:\n')[1].split('\npermissions:')[0];
  assert.doesNotMatch(paths, /- ['"]?\*\*['"]?\s*$/m);
  assert.match(paths, /- src\/\*\*/);
  assert.match(paths, /- \.claude\/skills\/verify-multiprompt\/\*\*/);
});

for (const name of ['chat-bench-ab.yml', 'chat-table-bench.yml', 'probe-chrome-frameless.yml']) {
  test(`${name} starts only on explicit dispatch`, () => {
    const events = workflow(name).split('\non:\n')[1].split('\npermissions:')[0];
    assert.match(events, /^  workflow_dispatch:/m);
    assert.doesNotMatch(events, /^  (?:pull_request|push|schedule|workflow_run):/m);
  });
}

test('automerge completion never scans all PRs or admits a different head', () => {
  const text = workflow('automerge.yml');
  const run = text.split('        run: |\n')[1].split('\n').map(line => line.replace(/^          /, '')).join('\n');
  assert.match(run, /for pr in \$candidates; do/);
  const select = run.split('for pr in $candidates; do')[0];
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ci-admission-'));
  try {
    fs.writeFileSync(path.join(dir, 'gh'), '#!/bin/sh\nprintf "%s\\n" "$*" >> "$CALLS"\nprintf "%s\\n" "$PRS"\n', { mode: 0o755 });
    const head = 'a'.repeat(40);
    for (const [event, conclusion, source, prs, expected, query] of [
      ['workflow_run', 'success', 'pull_request', [{ number: 7, headRefOid: head }, { number: 8, headRefOid: 'b'.repeat(40) }], '7', '--head topic'],
      ['workflow_run', 'failure', 'pull_request', [], '', null],
      ['workflow_run', 'success', 'push', [], '', null],
      ['workflow_run', 'success', 'pull_request', [{ number: 8, headRefOid: 'b'.repeat(40) }], '', '--head topic'],
      ['schedule', '', '', [{ number: 9, headRefOid: head }], '9', '--search status:success'],
      ['workflow_dispatch', '', '', [], '', '--search status:success'],
    ]) {
      const calls = path.join(dir, 'calls');
      fs.rmSync(calls, { force: true });
      const result = spawnSync('bash', ['-c', `${select}\nprintf '%s' "$candidates"`], {
        encoding: 'utf8', env: { ...process.env, PATH: dir + path.delimiter + process.env.PATH, CALLS: calls, PRS: JSON.stringify(prs), REPO: 'owner/repo', EVENT_NAME: event, RUN_CONCLUSION: conclusion, RUN_EVENT: source, HEAD_BRANCH: 'topic', HEAD_SHA: head },
      });
      assert.equal(result.status, 0, result.stderr);
      assert.equal(result.stdout.trim(), expected);
      if (query) assert.ok(fs.readFileSync(calls, 'utf8').includes(query));
      else assert.equal(fs.existsSync(calls), false);
    }
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('one merge yields to master and periodic recovery does not run for every completion', () => {
  const text = workflow('automerge.yml');
  assert.match(text, /done\n\s+break\n\s+fi/);
  assert.match(text, /if \[ "\$EVENT_NAME" = workflow_run \]; then exit 0; fi\n\s+head_oid=/);
  assert.match(text, /if \[ "\$EVENT_NAME" = workflow_run \] && \[ "\$head_oid" != "\$HEAD_SHA" \]; then continue; fi/);
  assert.match(text, /--match-head-commit "\$head_oid"/);
  assert.match(text, /tools\/automerge-admit\.sh/);
});

test('a behind green pull request is updated through the API and not by pushing', () => {
  const text = workflow('automerge.yml');
  assert.match(text, /AUTOMERGE_TOKEN: \$\{\{ steps\.app-token\.outputs\.token \}\}/);
  assert.match(text, /uses: actions\/create-github-app-token@[0-9a-f]{40}/);
  assert.match(text, /environment: automerge/);
  assert.doesNotMatch(text, /git (?:push|rebase|merge)/);
  const run = text.split('        run: |\n')[1].split('\n').map(line => line.replace(/^          /, '')).join('\n');
  const block = run.match(/if \[ "\$verdict" = update \]; then[\s\S]*?\n {2}fi\n/)[0];
  assert.match(block, /\n {4}continue\n {2}fi\n$/);
  assert.doesNotMatch(block, /gh pr merge/);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ci-admission-update-'));
  try {
    fs.writeFileSync(path.join(dir, 'gh'), '#!/bin/sh\nprintf "token=%s\\n" "$GH_TOKEN" >> "$CALLS"\nprintf "%s\\n" "$*" >> "$CALLS"\nexit 0\n', { mode: 0o755 });
    const head = 'a'.repeat(40);
    const env = { ...process.env, PATH: dir + path.delimiter + process.env.PATH, CALLS: path.join(dir, 'calls'), REPO: 'owner/repo', GH_TOKEN: 'workflow-token', AUTOMERGE_TOKEN: 'app-token' };
    const script = `verdict=update\npr=605\nhead_oid=${head}\nfor once in once; do\n${block}\ndone`;
    const result = spawnSync('bash', ['-c', script], { encoding: 'utf8', env });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /#605: updated with master/);
    const calls = fs.readFileSync(env.CALLS, 'utf8');
    assert.match(calls, /token=app-token/);
    assert.match(calls, new RegExp(`api --method PUT repos/owner/repo/pulls/605/update-branch -f expected_head_sha=${head}`));
    fs.rmSync(env.CALLS);
    const noAppToken = spawnSync('bash', ['-c', script], { encoding: 'utf8', env: { ...env, AUTOMERGE_TOKEN: '' } });
    assert.equal(noAppToken.status, 0, noAppToken.stderr);
    assert.match(noAppToken.stdout, /#605: skip update \(no app token/);
    assert.equal(fs.existsSync(env.CALLS), false);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
