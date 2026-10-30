import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import test from 'node:test';
import { stampTree } from './version-stamp.mjs';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const checker = path.join(root, 'tools/check-red-run.mjs');

test('red-run admission checks every PR without a hand-picked test or source revision', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/check-red-run.yml'), 'utf8');
  assert.match(workflow, /workflow_call:/);
  assert.doesNotMatch(workflow, /matrix:|prefix:|paths:/);
  assert.match(workflow, /node tools\/check-red-run\.mjs/);
  const tests = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  assert.match(tests, /uses: \.\/\.github\/workflows\/check-red-run.yml/);
  assert.match(tests, /needs: \[[^\n]*check-red-run[^\n]*\]/);
  assert.match(tests, /RED_RUN: \$\{\{ needs.check-red-run.result \}\}/);
  assert.match(tests, /require_jobs "\$WINDOWS"[^\n]*"\$RED_RUN"/);
});

test('red-run uses the preceding revision for manual master runs without changing PR or branch baselines', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  const caller = workflow.match(/^  check-red-run:\n((?:(?!^  [\w-]+:)[\s\S])*)/m)?.[1];
  const expression = caller?.match(/^      base: \$\{\{ (.+) \}\}$/m)?.[1];
  assert.ok(expression, 'red-run caller supplies a base revision');
  const evaluate = new Function('github', 'format', `return (${expression});`);
  const format = (template, value) => template.replace('{0}', value);
  for (const [name, ref, event, expected] of [
    ['pull request', 'refs/pull/1/merge', { pull_request: { base: { sha: 'pr-base' } } }, 'pr-base'],
    ['master push', 'refs/heads/master', { before: 'push-base' }, 'push-base'],
    ['manual master run', 'refs/heads/master', {}, 'head^'],
    ['branch push', 'refs/heads/ceo/IGSH-1140', { before: 'push-base' }, 'origin/master'],
    ['manual branch run', 'refs/heads/ceo/IGSH-1140', {}, 'origin/master'],
  ]) {
    const github = { ref, sha: 'head', event: { pull_request: { base: {} }, ...event } };
    assert.equal(evaluate(github, format), expected, name);
  }
});

function fixture(t) {
  const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'red-run-test-'));
  t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-q');
  git('config', 'user.email', 'test@example.invalid');
  git('config', 'user.name', 'Test');
  const write = (name, text) => {
    fs.mkdirSync(path.dirname(path.join(repo, name)), { recursive: true });
    fs.writeFileSync(path.join(repo, name), text);
  };
  const commit = () => { git('add', '.'); git('commit', '-qm', 'fixture'); return git('rev-parse', 'HEAD'); };
  write('src/value.txt', 'broken');
  const base = commit();
  const env = { ...process.env };
  delete env.GITHUB_HEAD_REF;
  delete env.GITHUB_REF_NAME;
  const run = (ref = base, extra = {}) => spawnSync(process.execPath, [checker, ref, git('rev-parse', 'HEAD')], { cwd: repo, encoding: 'utf8', env: { ...env, ...extra } });
  const regression = "const {test}=require('node:test'); const assert=require('node:assert/strict'); const fs=require('node:fs'); test('fixed value',()=>assert.equal(fs.readFileSync('src/value.txt','utf8'),'fixed'));\n";
  return { repo, git, write, commit, base, run, regression };
}

if (fs.existsSync(checker)) {
  test('manual master checks compare the preceding commit without weakening PR or branch proof', t => {
    const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
    const f = fixture(t);
    f.write('src/value.txt', 'fixed');
    f.write('tools/value.test.cjs', f.regression);
    const head = f.commit();
    f.git('update-ref', 'refs/remotes/origin/master', head);
    for (const name of ['check-red-run', 'switch-performance']) {
      const job = workflow.split(`\n  ${name}:\n`)[1].split(/\n  [\w-]+:\n/)[0];
      const expression = job.match(/(?:base|BASE): \$\{\{ (.+) \}\}/)?.[1];
      assert.ok(expression, `${name} baseline expression exists`);
      const select = new Function('github', 'format', `return (${expression});`);
      const format = (template, value) => template.replace('{0}', value);
      for (const [event, ref, before, pull, expected] of [
        ['workflow_dispatch', 'refs/heads/master', undefined, undefined, f.base],
        ['workflow_dispatch', 'refs/heads/ceo/IGSH-9999', undefined, undefined, head],
        ['push', 'refs/heads/master', f.base, undefined, f.base],
        ['push', 'refs/heads/ceo/IGSH-9999', f.base, undefined, head],
        ['pull_request', 'refs/pull/1/merge', undefined, { base: { sha: f.base } }, f.base],
      ]) {
        const selected = select({ event_name: event, ref, sha: head, event: { before, pull_request: pull || { base: {} } } }, format);
        assert.equal(f.git('merge-base', selected, head), expected, `${name} ${event} ${ref}`);
        if (event === 'workflow_dispatch' && ref === 'refs/heads/master') {
          const proof = f.run(selected);
          assert.equal(proof.status, 0, proof.stdout + proof.stderr);
          assert.match(proof.stdout, /RED PROVEN tools\/value.test.cjs/);
        }
      }
    }
  });

  test('a genuine changed regression fails only on merge-base production source', t => {
    const f = fixture(t);
    f.write('src/value.txt', 'fixed');
    f.write('tools/value.test.cjs', f.regression);
    f.commit();
    const result = f.run();
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /RED PROVEN tools\/value.test.cjs/);
    assert.equal(f.git('status', '--porcelain'), '');
    assert.equal(f.git('worktree', 'list', '--porcelain').match(/^worktree /gm).length, 1);
  });

  test('an ineffective test is rejected, even when another suite catches the bug', t => {
    const f = fixture(t);
    f.write('src/value.txt', 'fixed');
    f.write('tools/value.test.cjs', f.regression);
    f.write('tools/ineffective.test.cjs', "require('node:test')('always passes',()=>{});\n");
    f.commit();
    const result = f.run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /ineffective.test.cjs stayed green on merge-base source/);
  });

  test('a broken green test cannot be used as red proof', t => {
    const f = fixture(t);
    f.write('src/value.txt', 'still broken');
    f.write('tools/value.test.cjs', f.regression);
    f.commit();
    const result = f.run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /does not pass on PR source/);
  });

  test('missing modules are errors rather than regression evidence', t => {
    const f = fixture(t);
    f.write('src/new.cjs', 'module.exports = 1;');
    f.write('tools/new.test.cjs', "const assert=require('node:assert/strict'); require('node:test')('new',()=>assert.equal(require('../src/new.cjs'),1));\n");
    f.commit();
    const result = f.run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /assertion failure/);
  });

  test('syntax errors and missing fixtures cannot masquerade as red assertions', t => {
    const f = fixture(t);
    f.write('src/logic.cjs', 'module.exports = ;');
    const base = f.commit();
    f.write('src/logic.cjs', 'module.exports = 1;');
    f.write('tools/logic.test.cjs', "const assert=require('node:assert/strict'); require('node:test')('logic',()=>assert.equal(require('../src/logic.cjs'),1));\n");
    f.commit();
    const result = f.run(base);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /assertion failure/);
  });

  for (const input of ['tools/fixtures/expected.txt', 'tests/fixtures/expected.txt', 'tools/account-hosts-fixture.zig']) {
    test(`fixture and test changes pass without artificial red: ${input}`, t => {
      const f = fixture(t);
      f.write(input, 'old fixture');
      const base = f.commit();
      f.write(input, 'new fixture');
      f.write('tools/value.test.cjs', `const {test}=require('node:test'); const assert=require('node:assert/strict'); const fs=require('node:fs'); test('fixture',()=>assert.equal(fs.readFileSync(${JSON.stringify(input)},'utf8'),'new fixture'));\n`);
      f.commit();
      const result = f.run(base);
      assert.equal(result.status, 0, result.stdout + result.stderr);
      assert.match(result.stdout, /TEST_ONLY_PROVEN 1 changed suites/);
      assert.doesNotMatch(result.stdout, /RED PROVEN/);
    });
  }

  test('source plus fixture changes still reject a test that stays green on merge-base', t => {
    const f = fixture(t);
    f.write('src/value.txt', 'fixed');
    f.write('tools/fixtures/expected.txt', 'fixed');
    f.write('tools/value.test.cjs', "const {test}=require('node:test'); const assert=require('node:assert/strict'); const fs=require('node:fs'); test('fixture',()=>assert.equal(fs.readFileSync('tools/fixtures/expected.txt','utf8'),'fixed'));\n");
    f.commit();
    const result = f.run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /stayed green on merge-base source/);
  });

  test('fixture changes without a changed regression still fail closed', t => {
    const f = fixture(t);
    f.write('tools/fixtures/expected.txt', 'new fixture');
    f.commit();
    const result = f.run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /No changed regression tests/);
  });

  test('deleted fixture inputs are not treated as copied fixture changes', t => {
    const f = fixture(t);
    f.write('tools/fixtures/expected.txt', 'old fixture');
    const base = f.commit();
    fs.unlinkSync(path.join(f.repo, 'tools/fixtures/expected.txt'));
    f.write('tools/value.test.cjs', "require('node:test')('passes',()=>{});\n");
    f.commit();
    const result = f.run(base);
    assert.notEqual(result.status, 0);
    assert.doesNotMatch(result.stdout, /TEST_ONLY_PROVEN/);
  });

  test('non-fixture tooling changes still require red proof', t => {
    const f = fixture(t);
    f.write('tools/utility.cjs', 'module.exports = 1;\n');
    f.write('tools/value.test.cjs', "require('node:test')('always passes',()=>{});\n");
    f.commit();
    const result = f.run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /stayed green on merge-base source/);
  });

  test('changed fixtures travel with the test, but implementation stays at merge-base', t => {
    const f = fixture(t);
    f.write('src/value.txt', 'fixed');
    f.write('tools/fixtures/expected.txt', 'fixed');
    f.write('tools/value.test.cjs', f.regression.replace("'fixed'", "fs.readFileSync('tools/fixtures/expected.txt','utf8')"));
    f.commit();
    const result = f.run();
    assert.equal(result.status, 0, result.stdout + result.stderr);
  });

  test('merge-base is computed rather than assuming the latest base source', t => {
    const f = fixture(t);
    f.git('checkout', '-qb', 'fix');
    f.write('src/value.txt', 'fixed');
    f.write('tools/value.test.cjs', f.regression);
    const head = f.commit();
    f.git('checkout', '--detach', f.base);
    f.write('src/value.txt', 'fixed');
    const newerBase = f.commit();
    f.git('checkout', '--detach', head);
    const result = f.run(newerBase);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, new RegExp(`merge-base=${f.base}`));
  });

  test('source changes without runnable changed regressions fail closed', t => {
    const f = fixture(t);
    f.write('src/value.txt', 'fixed');
    f.commit();
    const result = f.run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /No changed regression tests/);
  });

  test('auto-revert branches undo master without a new regression, other branches still need one', t => {
    const f = fixture(t);
    f.write('tools/value.test.cjs', f.regression);
    const base = f.commit();
    fs.unlinkSync(path.join(f.repo, 'tools/value.test.cjs'));
    f.write('src/value.txt', 'reverted');
    f.commit();
    const revert = f.run(base, { GITHUB_HEAD_REF: 'auto-revert/40533455263' });
    assert.equal(revert.status, 0, revert.stdout + revert.stderr);
    assert.match(revert.stdout, /RED_RUN_NOT_REQUIRED auto-revert/);
    const dispatched = f.run(base, { GITHUB_REF_NAME: 'auto-revert/40533455263' });
    assert.equal(dispatched.status, 0, dispatched.stdout + dispatched.stderr);
    for (const branch of ['ceo/IGSH-1-auto-revert/x', 'poteto/auto-revert']) {
      const other = f.run(base, { GITHUB_HEAD_REF: branch });
      assert.notEqual(other.status, 0);
      assert.match(other.stderr, /No changed regression tests/);
    }
  });

  test('documentation-only changes do not need a fake regression', t => {
    const f = fixture(t);
    f.write('README.md', 'Documentation');
    f.commit();
    const result = f.run();
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /RED_RUN_NOT_REQUIRED/);
  });

  test('mechanical release stamps pass only when exact generated contents match', t => {
    const f = fixture(t);
    const files = {
      'src/main.zig': 'pub const APP_VERSION = "1.2.3";\n',
      'src/changelog.zig': 'pub const CHANGELOG = [_]ChangelogEntry{\n};\n',
      'changelog.d/DEMO-1-change.md': 'Opening tabs works.\n',
    };
    for (const [file, text] of Object.entries(files)) f.write(file, text);
    const base = f.commit();
    const stamped = stampTree(files);
    for (const [file, text] of Object.entries(stamped.files)) f.write(file, text);
    for (const file of stamped.removed) fs.unlinkSync(path.join(f.repo, file));
    f.commit();
    const result = f.run(base);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /verified mechanical release stamp/);
    f.write('src/value.txt', 'hidden app change');
    f.commit();
    const hidden = f.run(base);
    assert.notEqual(hidden.status, 0);
    assert.match(hidden.stderr, /No changed regression tests/);
  });

  test('Python assertion regressions receive the same green-then-red proof', t => {
    const f = fixture(t);
    f.write('src/value.txt', 'fixed');
    f.write('tools/value.test.py', "import pathlib, unittest\nclass Value(unittest.TestCase):\n def test_value(self): self.assertEqual(pathlib.Path('src/value.txt').read_text(), 'fixed')\nunittest.main()\n");
    f.commit();
    const result = f.run();
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /RED PROVEN tools\/value.test.py/);
  });

  test('deleted tests do not count as new regression evidence', t => {
    const f = fixture(t);
    f.write('tools/value.test.cjs', f.regression);
    const base = f.commit();
    fs.unlinkSync(path.join(f.repo, 'tools/value.test.cjs'));
    f.write('src/value.txt', 'fixed');
    f.commit();
    const result = f.run(base);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /No changed regression tests/);
  });
}
