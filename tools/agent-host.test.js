const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const read = (file) => fs.readFileSync(file, 'utf8');

test('IGSH-1266 new Claude sessions start on the app owned host and typing a command start stays for other programs', () => {
  const host = read('src/agent_host.zig');
  assert.match(host, /pub const ENABLED = true;/);
  assert.match(host, /pub fn eligible\(program: \[\]const u8\) bool \{\s*return ENABLED and std\.mem\.startsWith\(u8, program, "claude"\);/);
  assert.match(host, /try std\.testing\.expect\(!eligible\("codex"\)\);/);
  assert.match(host, /try std\.testing\.expect\(!eligible\("pi"\)\);/);

  const palette = read('src/command_palette.zig');
  const start = palette.indexOf('pub fn spawnWorkspaceTmuxSession() bool {');
  const end = palette.indexOf('pub fn activeRemoteContextForCodexTmux(');
  assert.ok(start >= 0 && end > start, 'spawnWorkspaceTmuxSession must exist');
  const body = palette.slice(start, end);
  assert.match(body, /if \(!plain_claude and agent_host\.eligible\(program\)\) agent_host\.mintSessionId\(&sid_buf\) else null/);
  assert.match(body, /pub fn spawnWorkspaceTmuxSession\(\) bool \{\s*return spawnWorkspaceSession\(true, false\);/, 'Ctrl+T always opens a live chat');
  assert.match(body, /pub fn spawnWorkspacePlainClaudeSession\(\) bool \{\s*return spawnWorkspaceSession\(true, true\);/, 'the old terminal Claude stays available from Ctrl+K');
  assert.match(body, /spawnWorkspaceSessionAt\(host, cwd_buf\[0\.\.cwd_len\], program_buf\[0\.\.program_len\], with_agent, plain_claude\)/);
  assert.match(body, /pickRepoOpen\(with_agent, false, workspaceHostForNewTab\(workspace\), plain_claude\)/);
  assert.match(palette, /const plain_claude = app_state\.g_search_pick_repo_plain_claude;\s*closePickRepo\(\);/);
  assert.match(palette, /spawnWorkspaceSessionAt\(host, path, program_buf\[0\.\.program_len\], with_agent, plain_claude\)/);
  assert.match(body, /const launch_cmd = workspaceLaunchCommand\(program, session, cwd, host_sid, &host_buf, &cmd_buf\) orelse \{/);
  assert.match(body, /var host_buf: \[WORKSPACE_HOST_LAUNCH_MAX\]u8 = undefined;/);
  assert.match(body, /if \(launch_cmd\.len > app_state\.g_pending_tmux_cmd\.len\)/, 'the pending command buffer must be checked before the copy');
  assert.ok(body.indexOf('var host_buf: [WORKSPACE_HOST_LAUNCH_MAX]u8') < body.indexOf('workspaceLaunchCommand'), 'the host buffer must outlive the command');
  assert.match(body, /claude_sid_len = @intCast\(sid_len\)/);

  const command = palette.indexOf('pub fn workspaceLaunchCommand(');
  const commandEnd = palette.indexOf('pub fn spawnWorkspaceTmuxSession() bool {');
  assert.ok(command >= 0 && commandEnd > command, 'workspaceLaunchCommand must exist');
  const choice = palette.slice(command, commandEnd);
  assert.match(choice, /if \(host_sid\) \|sid\| \{\s*if \(!agent_host\.eligible\(program\)\) return null;\s*return agent_host\.launchCommand\(host_out, session, cwd, sid\);/);
  assert.match(choice, /return buildWorkspaceTmuxLaunchCmd\(command_out, session, cwd, program\);/);
  assert.match(choice, /try std\.testing\.expectEqualStrings\(expected, spawned\);/);
  assert.match(choice, /try std\.testing\.expect\(workspaceLaunchCommand\("codex", "term-abc", "~\/projects", sid, &host_buf, &command_buf\) == null\);/);

  assert.ok(!palette.includes('fn buildCodexTmuxLaunchCmd('), 'Codex no longer types into a terminal');
});

test('IGSH-1447 Ctrl+T opens a live chat parked on an idle wait with no shell and no terminal Claude', () => {
  const host = read('src/agent_host.zig');
  const launch = host.slice(host.indexOf('pub fn launchCommandFor('));
  const format = launch.match(/std\.fmt\.bufPrint\(out, "([^"]*)"/);
  const args = launch.match(/\.\{ ([^}]*?) \}\) catch null;/);
  assert.ok(format && args, 'the launch command must be readable');
  const mode = host.match(/const mode = if \(provider == \.claude\) "([^"]*)" else "";/);
  const values = { name: 'claude', session: 'live-abc', cwd: '~/projects', sid: 'ffffffff-ffff-4fff-bfff-ffffffffffff', mode: mode ? mode[1] : '', READER: '~/.multiprompt-runtime/reader.py' };
  const parts = format[1].split('{s}');
  const ordered = args[1].split(',').map((value) => value.trim());
  assert.equal(parts.length - 1, ordered.length, 'every format hole must have one argument');
  const command = parts.reduce((text, part, index) => text + (index > 0 ? values[ordered[index - 1]] : '') + part, '');
  assert.equal(command,
    "tmux new-session -d -s live-abc -c ~/projects 'python3 ~/.multiprompt-runtime/reader.py host enable claude ffffffff-ffff-4fff-bfff-ffffffffffff --tmux live-abc --cwd ~/projects --permission-mode bypassPermissions >/dev/null 2>&1; python3 ~/.multiprompt-runtime/reader.py host start claude ffffffff-ffff-4fff-bfff-ffffffffffff >/dev/null 2>&1; exec sleep infinity' 2>/dev/null; tmux attach -t live-abc");
  assert.ok(!command.includes('handover'), 'the terminal must never own a live chat');
  assert.ok(!command.includes('send-keys'), 'nothing is typed into a shell');
  assert.ok(!command.includes('claude --session-id'), 'Claude must not run in the terminal');
  assert.ok(!command.includes('"'), 'the command is wrapped in double quotes for ssh');

  const palette = read('src/command_palette.zig');
  assert.match(palette, /const live_chat = host_sid != null and newTabOpensChatView\(program\);/);
  assert.match(palette, /app_state\.g_pending_chat_view = live_chat;/);
  assert.match(palette, /if \(live_chat\) buildLiveChatSessionName/);
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

test('IGSH-1266 a stopped live chat host restarts with the reader even when mp-send loaded it', () => {
  const reader = path.resolve('src/chat_history_reader.py');
  const run = spawnSync('python3', ['-I', '-c', [
    'import importlib.util,sys',
    'target=sys.argv[1]',
    "sys.argv=['/usr/local/bin/mp-send','claude','x']",
    "spec=importlib.util.spec_from_file_location('mp_reader',target)",
    'module=importlib.util.module_from_spec(spec)',
    'spec.loader.exec_module(module)',
    'print(module.host_runtime_file())',
  ].join('\n'), reader], { encoding: 'utf8', env: { PATH: process.env.PATH, HOME: process.env.HOME } });
  assert.equal(run.status, 0, run.stderr);
  assert.equal(run.stdout.trim(), reader);
});

test('IGSH-1546 Codex and Pi chats start the same live chat host with their own provider', () => {
  const host = read('src/agent_host.zig');
  const palette = read('src/command_palette.zig');
  const send = read('src/chat_send.zig');
  const transcript = read('src/chat_transcript.zig');
  assert.match(host, /pub const Provider = enum \{\s*claude,\s*codex,\s*pi,/);
  assert.match(host, /pub fn launchCommandFor\(out: \[\]u8, provider: Provider,/);
  assert.match(palette, /pub fn spawnCodexTmuxSession\(\) bool \{\s*return spawnHostedChatSession\(\.codex\);/);
  assert.match(palette, /pub fn spawnPiTmuxSession\(\) bool \{\s*return spawnHostedChatSession\(\.pi\);/);
  assert.match(palette, /ai_agent = provider\.aiAgent\(\)/);
  assert.match(palette, /g_pending_chat_view = true;/);
  assert.ok(!palette.includes('fn buildCodexTmuxSessionName('), 'Codex no longer types into a terminal');
  assert.match(transcript, /pub fn provider\(self: Identity\) \[\]const u8 \{\s*return if \(self\.pi\) "pi" else if \(self\.codex\) "codex" else "claude";/);
  assert.match(send, /\.provider = job\.key\.provider\(\), \.sid = /);
  assert.match(send, /return kind == \.tmux and \(ai_agent == 1 or ai_agent == 2 or ai_agent == 3\);/);
  assert.doesNotMatch(send, /if \(job\.key\.codex\) "codex" else "claude"/);
});
