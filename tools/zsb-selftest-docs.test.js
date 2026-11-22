const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const root = path.resolve(__dirname, '..');

test('help advertises selftest and hosting diagnostics without needing a tunnel', () => {
  for (const args of [['--help'], ['selftest', '--help'], ['pane-info', '--help']]) {
    const run = spawnSync('bash', ['tools/vps-multiprompt-browser.sh', ...args], { cwd: root, encoding: 'utf8', env: { ...process.env, TMUX: '', ZSB_SESSION: '' } });
    assert.equal(run.status, 0, run.stderr);
    assert.match(run.stdout, args[0] === '--help' ? /selftest[\s\S]*pane-info/ : new RegExp(`usage: zsb ${args[0]}`));
  }
});

test('wiki covers per-step output, visibility, cleanup and duplicate policy; versions agree', () => {
  const doc = fs.readFileSync(path.join(root, 'openwiki/browser/zsb-selftest.md'), 'utf8');
  for (const step of ['open', 'text', 'type', 'click', 'screenshot', 'hosting', 'close']) assert.match(doc, new RegExp('`' + step + '`'));
  for (const field of ['tab_name', 'active', 'visible', 'windowId', 'pass']) assert.ok(doc.includes(field), field);
  assert.match(doc, /most recently viewed complete record and its name/);
  assert.match(doc, /different\s+hosts/);
  assert.match(doc, /cleanup is still attempted/);
  assert.match(doc, /Exit 0[\s\S]*exit 1/);
  assert.match(fs.readFileSync(path.join(root, 'openwiki/browser/index.md'), 'utf8'), /zsb-selftest\.md/);
  assert.match(fs.readFileSync(path.join(root, 'openwiki/browser/routing-state-machine.md'), 'utf8'), /zsb-selftest\.md/);
  const version = JSON.parse(fs.readFileSync(path.join(root, 'extension/manifest.json'), 'utf8')).version;
  assert.match(fs.readFileSync(path.join(root, 'src/bridge.zig'), 'utf8'), /const version = @import\("bridge_config"\)\.extension_version;/);
  assert.ok(doc.includes(version));
});
