const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');

const root = path.resolve(__dirname, '..');

function scratch(t, name) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), `chat-text-formatting-${name}-`));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true, maxRetries: 10, retryDelay: 100 }));
  return dir;
}

function zig(dir, args, timeout = 300000) {
  return spawnSync(process.env.ZIG || 'zig', [...args, '-j1', '--cache-dir', path.join(dir, 'zig-cache'), '--global-cache-dir', process.env.ZIG_GLOBAL_CACHE_DIR || path.join(dir, 'zig-global-cache')], {
    cwd: dir, encoding: 'utf8', timeout, maxBuffer: 16 * 1024 * 1024,
  });
}

function expectPass(result, label) {
  if (result.error) assert.fail(`${label} could not run: ${result.error.message}`);
  assert.equal(result.status, 0, `${label} exited ${result.status}: ${result.stdout}${result.stderr}`);
}

function dropFunction(source, name) {
  const start = source.indexOf(`pub fn ${name}(`);
  assert.ok(start >= 0, `src/chat_inline_code.zig declares ${name}`);
  return source.slice(0, start) + source.slice(source.indexOf('\n}', start) + 2);
}

function chipSource() {
  let source = fs.readFileSync(path.join(root, 'src/chat_inline_code.zig'), 'utf8');
  for (const name of ['metricsForScreen', 'padX', 'paint']) source = dropFunction(source, name);
  source = source
    .replace('const w = @import("win32.zig");\n', '')
    .replace('const HANDLE = w.HANDLE;\n', '')
    .replace('const RECT = w.RECT;\n', 'pub const RECT = struct { left: i32, top: i32, right: i32, bottom: i32 };\n');
  assert.doesNotMatch(source, /win32|HANDLE/, 'the chip metrics no longer need the Windows drawing surface');
  assert.match(source, /^test "MUBO-593 inline code pills add horizontal padding that scales with the display"/m, 'the shipped chip padding test travels with the metrics');
  assert.match(source, /^test "MUBO-593 inline code sits on a tinted surface with its own calm monospace colour"/m, 'the shipped chip colour test travels with the metrics');
  assert.match(source, /^pub fn chipColor\(light: bool\) u32$/m, 'the chip colour stays under test');
  return source;
}

test('MUBO-593 inline code sits in a padded, tinted chip at every display scale', (t) => {
  const dir = scratch(t, 'chip');
  fs.writeFileSync(path.join(dir, 'chip.zig'), chipSource());
  expectPass(zig(dir, ['test', 'chip.zig']), 'the shipped inline code chip tests');
});

test('MUBO-593 web and file:/// addresses are links while other schemes stay plain text', (t) => {
  const dir = scratch(t, 'links');
  copyZig(['link_detect.zig'], dir);
  expectPass(zig(dir, ['test', 'link_detect.zig', '--test-filter', 'MUBO-593']), 'the shipped link scheme tests');
});

test('MUBO-593 a labelled link shows its label for web and file targets', (t) => {
  const dir = scratch(t, 'labelled-links');
  copyZig(['chat_markdown.zig'], dir);
  expectPass(zig(dir, ['test', 'chat_markdown.zig', '--test-filter', 'MUBO-593 labelled links']), 'the shipped labelled link tests');
});

test('MUBO-593 every list marker right-aligns inside its column and the body stays indented', (t) => {
  const result = spawnSync(process.execPath, ['--test', '--test-reporter=tap', '--test-name-pattern', 'ISSUE-376', 'tools/chat-view-gaps.test.js'], {
    cwd: root, encoding: 'utf8', timeout: 600000, maxBuffer: 16 * 1024 * 1024,
    env: { ...process.env, NODE_TEST_CONTEXT: undefined },
  });
  if (result.error) assert.fail(`the list layout harness could not run: ${result.error.message}`);
  assert.equal(result.status, 0, `the list layout harness exited ${result.status}: ${result.stdout}${result.stderr}`);
  assert.match(result.stdout, /ok \d+ - ISSUE-376 /, 'the list layout harness ran its marker assertions');
  assert.doesNotMatch(result.stdout, /not ok \d+ - ISSUE-376 /);
});
