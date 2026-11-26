const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

function body(source, name) {
  const start = source.search(new RegExp(`fn ${name}\\(`));
  assert.notEqual(start, -1, `missing fn ${name}`);
  const open = source.indexOf('{', start);
  let depth = 1;
  for (let i = open + 1; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(open + 1, i);
  }
  assert.fail(name);
}

test('a new live chat on the shared server connection runs its start command', () => {
  const palette = read('src/command_palette.zig');
  for (const name of ['spawnHostedChatNow', 'openWorkspaceTab']) {
    const spawn = body(palette, name);
    const started = spawn.indexOf('live.starting(');
    assert.ok(started >= 0, `${name} marks the chat as starting`);
    const launch = spawn.search(/if \(shell\.native_terminal\) @import\("native_session\.zig"\)\.launch\(SessionIdentity\.fromShell\(shell\.\*\) orelse return false\);/);
    assert.ok(launch > started, `${name} must run the start command for a native live chat`);
  }
  const consoleSource = read('src/console.zig');
  assert.match(body(consoleSource, 'spawnNativeShell'), /if \(app_state\.shells\[idx\]\.chat_view_on or \(app_state\.g_chat_active and !app_state\.g_restoring\)\) \{\s*app_state\.shells\[idx\]\.console_inflight = false;\s*\} else if \(!native\.connect\(shell_id\)\) native\.ready\(shell_id, false\);/, 'live chats open no terminal, but restored shells connect behind the current chat');
});

test('the start command runs once over the shared connection and reports failure in the chat', () => {
  const native = read('src/native_session.zig');
  const launch = body(native, 'launch');
  assert.match(launch, /slot\.command\[0\.\.slot\.command_len\]/);
  assert.match(launch, /std\.Thread\.spawn/);
  const worker = body(native, 'launchWorker');
  assert.match(worker, /transport\.openCommand\(identity\.host\.index\(\), command\)/);
  assert.doesNotMatch(worker, /openTerminal|reconnect/);
  assert.match(worker, /launchStarted\(/);
  assert.match(worker, /startFailed\(/);
  const started = body(native, 'launchStarted');
  assert.match(started, /"started"/);
  assert.match(started, /"already"/);
  const live = read('src/chat_live.zig');
  const failed = body(live, 'startFailed');
  assert.match(failed, /\.status = \.failed/);
  assert.match(failed, /\.held = true/);
  assert.match(failed, /\.state = \.idle/);
});
