const test = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync, spawnSync } = require('node:child_process');
const { mkdtempSync, mkdirSync, writeFileSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const api = import('./check-regression-inputs.mjs');

function repository(t) {
  const dir = mkdtempSync(join(tmpdir(), 'regression-inputs-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8' }).trim();
  git('init', '-q');
  git('config', 'user.name', 'Fixture author');
  git('config', 'user.email', 'fixture@example.invalid');
  git('config', 'commit.gpgsign', 'false');
  const write = (file, source) => { mkdirSync(join(dir, file, '..'), { recursive: true }); writeFileSync(join(dir, file), source); };
  const commit = () => { git('add', '.'); git('commit', '-qm', 'fixture'); return git('rev-parse', 'HEAD'); };
  return { dir, git, write, commit };
}

test('historical 290c455 extraction names its location, input and durable replacement', async () => {
  const { findHistoryInputs } = await api;
  const source = "execFileSync('git', ['show', `cb15de6:${file}`]);";
  assert.deepEqual(findHistoryInputs('tools/startup.test.js', source, new Set([1])), [
    'tools/startup.test.js:1 loads cb15de6:${file} from git history; snapshot the exact input in tools/fixtures/<ticket>/ and read it with fs.readFileSync'
  ]);
});

test('shell, array, multiline and Python extraction forms are rejected', async () => {
  const { findHistoryInputs } = await api;
  for (const source of [
    "execSync('git show cb15de6:src/main.zig');",
    "execFileSync('git', [\n  'show',\n  `cb15de6:${file}`\n]);",
    "subprocess.check_output(['git', 'show', 'cb15de6:src/main.zig'])",
    "execFileSync('git', ['cat-file', '-p', 'cb15de6:src/main.zig']);",
    "execSync('git cat-file -p cb15de6:src/main.zig');",
    "execFileSync('git', ['archive', 'cb15de6']);",
    "execSync('git archive cb15de6 src');"
  ]) {
    const result = findHistoryInputs('tools/input.js', source, new Set([1, 2, 3, 4]));
    assert.equal(result.length, 1, source);
    assert.match(result[0], /tools\/fixtures/);
  }
});

test('unchanged legacy operations, metadata and checked-in fixture reads remain valid', async () => {
  const { findHistoryInputs } = await api;
  for (const source of ["execFileSync('git', ['show', '--format=%H']);", "fs.readFileSync('tools/fixtures/IGSH-543/main.zig');", "execFileSync('git', ['diff', 'base...HEAD']);"]) {
    assert.deepEqual(findHistoryInputs('tools/input.js', source, new Set([1])), []);
  }
  assert.deepEqual(findHistoryInputs('tools/input.js', "execFileSync('git', ['show', 'cb15de6:src/main.zig']);\nconst unrelated = 1;", new Set([2])), []);
});

test('only extraction using a newly created temp repository cwd is exempt', async () => {
  const { findHistoryInputs } = await api;
  const setup = "const dir = mkdtempSync(join(tmpdir(), 'fixture-'));\nexecFileSync('git', ['init'], { cwd: dir });\n";
  const local = "execFileSync('git', ['show', 'cb15de6:src/main.zig'], { cwd: dir });";
  assert.deepEqual(findHistoryInputs('tools/git.test.js', setup + local, new Set([3])), []);
  for (const options of ['', ', { cwd: process.cwd() }']) {
    const source = setup + `execFileSync('git', ['show', 'cb15de6:src/main.zig']${options});`;
    assert.equal(findHistoryInputs('tools/git.test.js', source, new Set([3])).length, 1);
  }
  const wrapper = "const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8' });\n";
  assert.deepEqual(findHistoryInputs('tools/git.test.js', setup + wrapper + "git(['show', 'cb15de6:src/main.zig']);", new Set([4])), []);
  assert.equal(findHistoryInputs('tools/git.test.js', local, new Set([1])).length, 1);
});

test('input scope matches only requested tool, test, build and workflow files', async () => {
  const { isInputFile } = await api;
  for (const file of ['tools/a.js', 'tools/nested/a.mjs', 'tools/a.cjs', 'tools/a.py', 'tests/a.zig', 'tests/nested/a', 'build.zig', '.github/workflows/test.yml']) assert.equal(isInputFile(file), true, file);
  for (const file of ['src/main.zig', 'openwiki/a.md', 'tools/a.ps1', '.github/workflows/nested/a.yml', 'build.zig.zon']) assert.equal(isInputFile(file), false, file);
});

test('diff line mapping handles deletions, multiple hunks and new files', async () => {
  const { addedLines } = await api;
  assert.deepEqual([...addedLines('--- a/x\n+++ b/x\n@@ -1,2 +1,2 @@\n-old\n+new\n context\n@@ -10,0 +11,2 @@\n+one\n+two')], [1, 11, 12]);
});

test('CLI checks committed additions via merge-base, not unchanged legacy or base-only changes', async t => {
  const { checkRegressionInputs } = await api;
  const { dir, git, write, commit } = repository(t);
  const old = "execFileSync('git', ['show', 'cb15de6:src/main.zig']);\n";
  write('tools/old.js', old);
  const base = commit();
  write('tools/base-only.js', old);
  commit();
  const baseTip = git('rev-parse', 'HEAD');
  git('checkout', '-q', '--detach', base);
  write('tools/old.js', old + 'const unrelated = 1;\n');
  write('src/ignored.zig', old);
  commit();
  assert.deepEqual(checkRegressionInputs(baseTip, dir).errors, []);
  write('tools/nested/new.test.js', old);
  commit();
  const result = checkRegressionInputs(base, dir);
  assert.equal(result.errors.length, 1);
  assert.match(result.errors[0], /^tools\/nested\/new.test.js:1 loads cb15de6:src\/main.zig/);
  const cli = spawnSync(process.execPath, [join(__dirname, 'check-regression-inputs.mjs'), base, '--root', dir], { encoding: 'utf8' });
  assert.equal(cli.status, 1);
  assert.match(cli.stderr, /tools\/fixtures/);
  write('tools/nested/new.test.js', "fs.readFileSync('tools/fixtures/IGSH-543/main.zig');\n");
  commit();
  const green = spawnSync(process.execPath, [join(__dirname, 'check-regression-inputs.mjs'), base, '--root', dir], { encoding: 'utf8' });
  assert.equal(green.status, 0, green.stderr);
  assert.match(green.stdout, /Regression inputs OK/);
});

test('synthetic source strings and regular expressions are not executed history readers', async () => {
  const { findHistoryInputs } = await api;
  const source = [
    'const control = "execFileSync(\'git\', [\'show\', `cb15de6:${file}`]);";',
    'const command = "git show cb15de6:src/main.zig";',
    'const pattern = /git show cb15de6:src/;',
    '/' + '/ execFileSync(\'git\', [\'show\', \'cb15de6:src/main.zig\']);'
  ].join('\n');
  assert.deepEqual(findHistoryInputs('tools/synthetic.test.js', source, new Set([1, 2, 3, 4])), []);
  const fs = require('node:fs');
  for (const file of ['check-regression-inputs.mjs', 'check-regression-inputs.test.js', 'check-routing-ids.test.js', 'check-powershell-host-names.test.js']) {
    const text = fs.readFileSync(join(__dirname, file), 'utf8');
    assert.deepEqual(findHistoryInputs(`tools/${file}`, text, new Set(text.split('\n').map((_, i) => i + 1))), [], file);
  }
});
