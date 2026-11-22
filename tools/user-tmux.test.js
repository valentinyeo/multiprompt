const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const shipped = path.join(root, 'tools/user-tmux.sh');
const available = process.platform !== 'win32' && spawnSync('tmux', ['-V']).status === 0;

function fixture(run) {
  assert.ok(available, 'tmux must be installed for the owner-session regression');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'owner-tmux-'));
  const socket = `owner-test-${process.pid}-${path.basename(dir)}`;
  const binary = spawnSync('sh', ['-c', 'command -v tmux'], { encoding: 'utf8' }).stdout.trim();
  const env = { ...process.env, PATH: `${dir}:${process.env.PATH}`, TEST_SOCKET: socket, TMUX: '' };
  const exec = (file, args, extra = {}) => spawnSync(file, args, { env: { ...env, ...extra }, encoding: 'utf8', timeout: 10000 });
  const tmux = (...args) => {
    const result = exec(binary, ['-L', `${socket}-bridge`, ...args]);
    assert.equal(result.status, 0, result.stderr);
    return result.stdout.trim();
  };
  const owner = (...args) => exec(binary, ['-L', `${socket}-owner`, ...args]);
  fs.writeFileSync(path.join(dir, 'tmux'), `#!/bin/bash\nexec ${JSON.stringify(binary)} -L "$TEST_SOCKET-\${TEST_LAYER:-bridge}" "$@"\n`, { mode: 0o755 });
  fs.writeFileSync(path.join(dir, 'ssh'), '#!/bin/bash\nunset TMUX\nexport TEST_LAYER=owner\nexec bash -c "${!#}"\n', { mode: 0o755 });
  const tool = fs.existsSync(shipped) ? shipped : path.join(dir, 'legacy.sh');
  if (!fs.existsSync(shipped)) fs.writeFileSync(tool, 'owner=$2; name=$3; directory=$4\ntmux has-session -t "=$name" 2>/dev/null || tmux new-session -d -s "$name" "ssh -tt $owner@localhost exec bash -l"\n');
  try {
    assert.equal(owner('new-session', '-d', '-s', 'control', 'sleep 120').status, 0);
    assert.equal(owner('set-hook', '-g', 'client-attached', 'wait-for -S owner-attached').status, 0);
    run({ dir, exec, tmux, owner, tool });
  } finally {
    exec(binary, ['-L', `${socket}-bridge`, 'kill-server']);
    exec(binary, ['-L', `${socket}-owner`, 'kill-server']);
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

function opened(context, name) {
  const result = context.exec('bash', [context.tool, '--stage', 'worker', name, context.dir]);
  assert.equal(result.status, 0, result.stderr);
}

function attached(context) {
  const result = context.owner('wait-for', 'owner-attached');
  assert.equal(result.status, 0, 'owner named session must attach, not open a bare SSH shell');
}

test('new cross-user bridges create named owner sessions and reconnect to the same pane', { skip: process.platform === 'win32' }, () => fixture(context => {
  opened(context, 'workspace');
  attached(context);
  const before = context.owner('display-message', '-p', '-t', '=workspace:', '#{pane_pid}|#{session_attached}');
  assert.equal(before.status, 0, before.stderr);
  assert.match(before.stdout.trim(), /^\d+\|1$/);
  assert.equal(context.tmux('show-options', '-p', '-t', '=workspace:', '-v', '@owner_session'), 'workspace');
  const client = Number(context.tmux('display-message', '-p', '-t', '=workspace:', '#{pane_pid}'));
  process.kill(client, 'SIGTERM');
  attached(context);
  const after = context.owner('display-message', '-p', '-t', '=workspace:', '#{pane_pid}|#{session_attached}');
  assert.equal(after.stdout, before.stdout, 'bridge reconnect must preserve the live owner process');
}));

test('staging preserves busy legacy panes and migrates only after their process exits', { skip: process.platform === 'win32' }, () => fixture(context => {
  context.tmux('new-session', '-d', '-s', 'legacy', 'exec bash -c read');
  const before = context.tmux('display-message', '-p', '-t', '=legacy:', '#{pane_pid}');
  opened(context, 'legacy');
  opened(context, 'legacy');
  assert.equal(context.tmux('display-message', '-p', '-t', '=legacy:', '#{pane_pid}'), before);
  assert.equal(context.owner('has-session', '-t', '=legacy').status, 1, 'staging must not move an active worker');
  context.tmux('send-keys', '-t', '=legacy:', 'C-d');
  attached(context);
  const migrated = context.owner('display-message', '-p', '-t', '=legacy:', '#{session_attached}');
  assert.equal(migrated.stdout.trim(), '1');
}));

test('invalid session names cannot become shell or tmux instructions', { skip: process.platform === 'win32' }, () => fixture(context => {
  const result = context.exec('bash', [context.tool, '--stage', 'worker', 'bad;name', context.dir]);
  assert.equal(result.status, 64);
}));
