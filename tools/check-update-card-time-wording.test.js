const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { discoverTests } = require('./discover-tests.cjs');

const root = path.resolve(__dirname, '..');
const checker = path.join(__dirname, 'check-update-card-time-wording.mjs');

function scan(t, source) {
  assert.ok(fs.existsSync(checker), 'The update card time estimate check must exist.');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'update-card-time-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const file = path.join(dir, 'update_card.zig');
  fs.writeFileSync(file, source);
  return spawnSync(process.execPath, [checker, file], { encoding: 'utf8' });
}

test('the shipped subtitle that claimed a few seconds is rejected', t => {
  const result = scan(t, 'const subtitle = std.fmt.bufPrint(&buf, "v{s} \\xc2\\xb7 takes a few seconds", .{ver}) catch "Takes a few seconds";\n');
  assert.equal(result.status, 1, result.stdout);
  assert.match(result.stderr, /never show a time estimate/i);
  assert.match(result.stderr, /takes a few seconds/);
});

test('every time estimate form is rejected', t => {
  for (const wording of ['Takes 30 seconds', 'Ready in 2 minutes', 'a few moments', 'ETA 5', 'ready in ~5 s', '3 secs left']) {
    const result = scan(t, `const note = "${wording}";\n`);
    assert.equal(result.status, 1, `${wording} must fail: ${result.stdout}`);
  }
});

test('the version only subtitle and the rest of the real card pass', t => {
  const result = scan(t, [
    'const subtitle = std.fmt.bufPrint(&buf, "v{s} \\xc2\\xb7 {s}", .{ver, note}) catch "";',
    'const title = "Update ready";',
    'const delayed = "No verified update available. Please try again later.";',
    'const downloading = "Downloading update. Restart will follow.";',
    '',
  ].join('\n'));
  assert.equal(result.status, 0, result.stderr);
});

test('the update card source in this repo shows no time estimate', () => {
  const result = spawnSync(process.execPath, [checker], { cwd: root, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
});

test('this check runs in CI', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  assert.match(workflow, /node --test tools\/check-update-card-time-wording\.test\.js/);
  assert.match(workflow, /node tools\/check-update-card-time-wording\.mjs/);
  assert.doesNotMatch(discoverTests(root).join('\n'), /check-update-card-time-wording\.test\.js/);
});
