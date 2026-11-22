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
  for (const name of ['spawnHostedChatSession', 'spawnWorkspaceSessionAt']) {
    const spawn = body(palette, name);
    const started = spawn.indexOf('live.starting(');
    assert.ok(started >= 0, `${name} marks the chat as starting`);
    const launch = spawn.search(/if \(shell\.native_terminal\) @import\("native_session\.zig"\)\.launch\(shell\.shell_id, (host_sid\.\?|sid)\);/);
    assert.ok(launch > started, `${name} must run the start command for a native live chat`);
  }
  const consoleSource = read('src/console.zig');
  assert.match(body(consoleSource, 'spawnNativeShell'), /chat_view_on or app_state\.g_chat_active/, 'live chats still open no terminal');
});

test('the start command runs once over the shared connection and reports failure in the chat', () => {
  const native = read('src/native_session.zig');
  const launch = body(native, 'launch');
  assert.match(launch, /slot\.command\[0\.\.slot\.command_len\]/);
  assert.match(launch, /std\.Thread\.spawn/);
  const worker = body(native, 'launchWorker');
  assert.match(worker, /transport\.openCommand\(host, command\)/);
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
