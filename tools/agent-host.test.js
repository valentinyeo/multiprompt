const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const read = (file) => fs.readFileSync(file, 'utf8');

test('IGSH-1266 the app owned Claude start is off by default and typing a command start stays for other programs', () => {
  const host = read('src/agent_host.zig');
  assert.match(host, /pub const ENABLED = false;/);
  assert.match(host, /pub fn eligible\(program: \[\]const u8\) bool \{\s*return ENABLED and/);

  const palette = read('src/command_palette.zig');
  const start = palette.indexOf('pub fn spawnWorkspaceTmuxSession() bool {');
  const end = palette.indexOf('pub fn activeRemoteContextForCodexTmux(');
  assert.ok(start >= 0 && end > start, 'spawnWorkspaceTmuxSession must exist');
  const body = palette.slice(start, end);
  assert.match(body, /if \(agent_host\.eligible\(program\)\) agent_host\.mintSessionId\(&sid_buf\) else null/);
  assert.match(body, /agent_host\.launchCommand\(&host_buf, session, cwd, sid\)/);
  assert.ok(body.indexOf('var host_buf: [1024]u8') < body.indexOf('agent_host.launchCommand'), 'the host buffer must outlive the command');
  assert.match(body, /buildWorkspaceTmuxLaunchCmd\(&cmd_buf, session, cwd, program\)/);
  assert.match(body, /claude_sid_len = @intCast\(sid_len\)/);

  const codex = palette.indexOf('fn buildCodexTmuxLaunchCmd(');
  const codexEnd = palette.indexOf('fn buildCodexTmuxSessionName(');
  assert.match(palette.slice(codex, codexEnd), /tmux send-keys -t /);
});

test('IGSH-1266 the host start command starts the host and never types into a pane', () => {
  const host = read('src/agent_host.zig');
  const start = host.indexOf('pub fn launchCommand(');
  const body = host.slice(start, host.indexOf('test "IGSH-1266 session ids'));
  assert.match(body, /python3 \{s\} host enable claude \{s\} --tmux \{s\} --cwd \{s\}/);
  assert.match(body, /python3 \{s\} host start claude \{s\} --tmux \{s\} --cwd \{s\}/);
  assert.match(body, /tmux new-session -d -s \{s\} -c \{s\}/);
  assert.match(body, /tmux attach -t \{s\}/);
  assert.ok(!body.includes('send-keys'), 'the Claude start must not type into a pane');
});

test('IGSH-1266 mp-send ships inside the runtime bundle and is published next to the reader', () => {
  const session = read('src/chat_session.zig');
  assert.match(session, /const mp_send = @embedFile\("mp_send\.py"\);/);
  assert.match(session, /MP_SEND_SOURCE = '\{s\}'/);

  const reader = read('src/chat_history_reader.py');
  assert.match(reader, /def publish_tools\(data\):/);
  assert.match(reader, /publish\('reader\.py', data\)/);
  assert.match(reader, /publish\('mp-send', _base64\.b64decode\(mp_send_source\)\)/);
  assert.match(reader, /publish_tools\(source\)/);
  assert.match(reader, /publish_tools\(installed\)/);

  const source = read('src/mp_send.py');
  assert.match(source, /def submit\(reader, provider, sid, tmux, text, message_id=None\)/);
  assert.match(source, /reader\.message_store_request\(query\)/);
  assert.match(source, /op="message_submit", message_protocol=1/);
  assert.match(read('tools/mp-send'), /runpy\.run_path\(str\(target\), run_name="__main__"\)/);
});
