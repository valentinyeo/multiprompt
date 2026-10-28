const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const script = path.join(__dirname, 'discover-tests.cjs');

function fixture(run) {
  assert.ok(fs.existsSync(script), 'automatic test discovery must exist without editing build.zig for each test');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'test-discovery-'));
  const put = (file, text = '') => {
    fs.mkdirSync(path.dirname(path.join(dir, file)), { recursive: true });
    fs.writeFileSync(path.join(dir, file), text);
  };
  for (const folder of ['tools', 'extension', 'service/test', '.github/workflows']) fs.mkdirSync(path.join(dir, folder), { recursive: true });
  put('build.zig');
  try { run(dir, put); } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}

test('new conventional tests need no shared-list edit; discovery stays sorted and excludes non-tests', () => fixture((dir, put) => {
  for (const file of ['tools/z.test.cjs', 'tools/a.test.mjs', 'extension/b.test.js', 'service/test/c.test.js',
    'tools/ignored.test.json', 'tools/ignored.test.js.orig', 'tools/fixtures/ignored.test.js', 'tools/node_modules/ignored.test.js']) put(file);
  const before = fs.readFileSync(path.join(dir, 'build.zig'), 'utf8');
  assert.deepEqual(require(script).discoverTests(dir), ['extension/b.test.js', 'service/test/c.test.js', 'tools/a.test.mjs', 'tools/z.test.cjs']);
  assert.equal(fs.readFileSync(path.join(dir, 'build.zig'), 'utf8'), before);
}));

test('special build/workflow commands and local Wine tests keep their original execution contracts', () => fixture((dir, put) => {
  put('build.zig', 'b.addSystemCommand(&.{ "node", "--test", "tools/native.test.js" });');
  put('.github/workflows/verify.yml', '- run: node --test extension/live.test.mjs\n  paths: [tools/native-extra.test.js]\n');
  for (const file of ['tools/native.test.js', 'extension/live.test.mjs', 'tools/chat-working-bar.test.mjs',
    'tools/chat-permission-buttons.test.mjs', 'tools/native-extra.test.js']) put(file);
  assert.deepEqual(require(script).discoverTests(dir), ['tools/native-extra.test.js']);
}));

test('the normal command runs newly added tests and returns failure when their assertions fail', () => fixture((dir, put) => {
  const invoke = (...args) => spawnSync(process.execPath, [script, ...args], {
    cwd: dir, encoding: 'utf8', env: { ...process.env, NODE_TEST_CONTEXT: undefined }, timeout: 30000,
  });
  const source = pass => `require('node:test')('unlisted feature', () => { require('node:assert/strict').equal(${pass}, true); console.log('UNLISTED_FEATURE_EXECUTED'); });`;
  put('tools/unlisted.test.cjs', source(true));
  const green = invoke();
  assert.equal(green.status, 0, green.stdout + green.stderr);
  assert.match(green.stdout, /UNLISTED_FEATURE_EXECUTED/);
  assert.match(green.stdout, /# tests 1/);
  put('tools/unlisted.test.cjs', source(false));
  const red = invoke();
  assert.equal(red.status, 1, red.stdout + red.stderr);
  assert.match(red.stdout, /ERR_ASSERTION/);
  assert.match(red.stdout, /# fail 1/);
  assert.equal(invoke('--list').stdout.trim(), 'tools/unlisted.test.cjs');
}));

test('empty discovery succeeds without accidentally invoking Node whole-tree discovery', () => fixture((dir, put) => {
  put('tools/fixtures/must-not-run.test.cjs', "throw new Error('fixture ran');");
  const result = spawnSync(process.execPath, [script], { cwd: dir, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.equal(result.stdout, '');
}));

test('the standard server graph reaches automatic discovery with the selected compiler', () => {
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  assert.match(build, /const server_tool_tests = b\.addSystemCommand\(&\.\{ "node", "tools\/discover-tests\.cjs" \}\);/);
  for (const name of ['ZIG', 'ZIG_EXE']) assert.match(build, new RegExp(`server_tool_tests\\.setEnvironmentVariable\\("${name}", b\\.graph\\.zig_exe\\)`));
  assert.match(build, /vps_test_step\.dependOn\(&server_tool_tests\.step\)/);
});
