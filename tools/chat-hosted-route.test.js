const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const source = require('./app-source').readAppSource();

function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

const prelude = String.raw`
const std = @import("std");
const ShellKind = enum { cmd, pwsh, vps, tmux, vps2, bash, gitbash };
const Shell = struct {
    kind: ShellKind = .tmux,
    ai_agent: u8 = 0,
    tmux_session: [64]u8 = @splat(0),
    tmux_session_len: u32 = 0,
};
`;

const checks = String.raw`
fn tab(tmux: []const u8, ai_agent: u8) Shell {
    var s = Shell{ .ai_agent = ai_agent };
    s.tmux_session_len = @intCast(tmux.len);
    @memcpy(s.tmux_session[0..tmux.len], tmux);
    return s;
}

test "SOFT-2824 a chat started on the server routes its first message to the host" {
    const hosted = tab("live-multiprompt-android-mwnl43gt", 0);
    try std.testing.expect(chatHostedShell(&hosted));
    try std.testing.expect(chatHostedMessageGoesToHost(hosted.kind, hosted.ai_agent, chatHostedShell(&hosted)));
    try std.testing.expectEqual(ChatSendRoute.host_message, chatSendRoute(hosted.kind, hosted.ai_agent, true, chatHostedShell(&hosted)));
    try std.testing.expectEqual(ChatSendRoute.wait_for_start, chatSendRoute(hosted.kind, hosted.ai_agent, false, chatHostedShell(&hosted)));
    const known = tab("live-308b1fc", 1);
    try std.testing.expectEqual(ChatSendRoute.host_message, chatSendRoute(known.kind, known.ai_agent, true, chatHostedShell(&known)));
}

test "SOFT-2824 a plain tab keeps its console and hold behaviour" {
    const tmux = tab("projects", 0);
    try std.testing.expect(!chatHostedShell(&tmux));
    try std.testing.expect(!chatHostedMessageGoesToHost(tmux.kind, tmux.ai_agent, chatHostedShell(&tmux)));
    try std.testing.expectEqual(ChatSendRoute.wait_for_start, chatSendRoute(tmux.kind, tmux.ai_agent, true, chatHostedShell(&tmux)));
    const plain = Shell{ .kind = .vps };
    try std.testing.expect(!chatHostedShell(&plain));
    try std.testing.expectEqual(ChatSendRoute.terminal_send, chatSendRoute(plain.kind, plain.ai_agent, true, chatHostedShell(&plain)));
    const local = Shell{ .kind = .cmd };
    try std.testing.expectEqual(ChatSendRoute.terminal_send, chatSendRoute(local.kind, 1, true, chatHostedShell(&local)));
}
`;

test('SOFT-2824 a server-started chat sends to the host without a detected pane agent', () => {
  assert.match(source, /fn chatSessionHosted\(tmux: \[\]const u8\) bool \{\s*return std\.mem\.startsWith\(u8, tmux, "live-"\);/,
    'one named rule decides that a live session is hosted');
  assert.match(source, /fn chatHostedShell\(shell: \*const @import\("app_state\.zig"\)\.Shell\) bool \{/,
    'a saved tab answers the same rule from its tmux session name');
  assert.match(source, /fn chatSendRoute\(kind: @import\("app_state\.zig"\)\.ShellKind, ai_agent: u8, sid_present: bool, hosted: bool\) ChatSendRoute/,
    'the send route is decided from the session, not only from the detected agent');
  assert.match(source, /if \(chatHostedMessageGoesToHost\(kind, ai_agent, hosted\)\) return if \(sid_present\) \.host_message else \.wait_for_start;/,
    'a hosted chat with a session id is a host message even before its agent is classified');
  assert.match(source, /fn chatHostedMessageGoesToHost\(kind: @import\("app_state\.zig"\)\.ShellKind, ai_agent: u8, hosted: bool\) bool \{\s*return chatMessageGoesToHost\(kind, ai_agent\) or \(kind == \.tmux and hosted\);/,
    'a hosted tmux tab joins the existing hosted agent rule');
  const enqueue = source.slice(source.indexOf('fn chatEchoEnqueueForShell('), source.indexOf('fn chatEchoMarkNotSent('));
  assert.match(enqueue, /chatHostedMessageGoesToHost\(shells\[idx\]\.kind, shells\[idx\]\.ai_agent, chatHostedShell\(&shells\[idx\]\)\)/,
    'the queued entry is marked as a host message for a live session');
  const sync = source.slice(source.indexOf('if (g_chat_message_sync_job == null'), source.indexOf('if (ISSUE_349_FULL_SETTLE) chatFullSettleFinish();'));
  assert.match(sync, /shell\.ai_agent == 0 and chatHostedShell\(&shell\)/, 'the message sync polls a hosted chat with no detected pane agent');
});

test('SOFT-2824 the hosted route executes in Zig', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-hosted-route-'));
  try {
    const file = path.join(dir, 'test.zig');
    const functions = ['chatSessionHosted', 'chatHostedShell', 'chatMessageGoesToHost', 'chatHostedMessageGoesToHost', 'chatSendRoute'].map(body).join('\n')
      .replaceAll('@import("app_state.zig").ShellKind', 'ShellKind')
      .replaceAll('@import("app_state.zig").Shell', 'Shell');
    fs.writeFileSync(file, prelude + 'const ChatSendRoute = enum { host_message, terminal_send, wait_for_start };\n' + functions + checks);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000, maxBuffer: 8 * 1024 * 1024 });
    assert.equal(result.status, 0, String(result.error || '') + result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
