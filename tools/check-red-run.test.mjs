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
  const run = (ref = base) => spawnSync(process.execPath, [checker, ref, git('rev-parse', 'HEAD')], { cwd: repo, encoding: 'utf8' });
  const regression = "const {test}=require('node:test'); const assert=require('node:assert/strict'); const fs=require('node:fs'); test('fixed value',()=>assert.equal(fs.readFileSync('src/value.txt','utf8'),'fixed'));\n";
  return { repo, git, write, commit, base, run, regression };
}

if (fs.existsSync(checker)) {
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

test('regression admission installs the pinned Zig compiler before executing project tests', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/check-red-run.yml'), 'utf8');
  const install = workflow.indexOf('- name: Install Zig 0.16.0');
  assert.ok(install >= 0 && install < workflow.indexOf('- name: Test admission controls'));
  const step = workflow.slice(install, workflow.indexOf('- name: Test admission controls'));
  assert.match(step, /https:\/\/ziglang\.org\/download\/0\.16\.0\/zig-x86_64-linux-0\.16\.0\.tar\.xz/);
  assert.match(step, /70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00/);
  assert.match(step, /sha256sum -c -/);
  assert.match(step, /echo "\$RUNNER_TEMP\/zig-x86_64-linux-0\.16\.0" >> "\$GITHUB_PATH"/);
});
