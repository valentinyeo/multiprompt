const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const source = require('./app-source').readAppSource();

function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

function harness(text) {
  const savedTab = source.match(/const SavedTab = struct \{[\s\S]*?\n};/)[0];
  const kind = source.match(/const ShellKind = enum[^;]+;/)[0];
  const writers = ['src/session.zig', 'src/workspaces.zig'].map(file => {
    const code = fs.readFileSync(file, 'utf8');
    const start = code.indexOf('        if (app_state.ISSUE_373_SHELL_OVERRIDE and app_state.shells[i].chat_shell_override');
    assert.ok(start >= 0, file);
    return code.slice(start, code.indexOf('\n        }', start) + 10).replaceAll('app_state.', '');
  });
  return `const std = @import("std");
const json_reader = @import("json_reader.zig");
const archive_rules = @import("archive_rules.zig");
const DWORD = u32;
const BROWSER_SPLIT_DEFAULT_PERMILLE = 350;
const ISSUE_373_SHELL_OVERRIDE = true;
const ChatViewMode = enum { everywhere, per_session, nowhere };
${kind}
${savedTab}
const Shell = struct { shell_id: u32 = 17, chat_view_on: bool = false, chat_shell_override: bool = false };
var shells = [_]Shell{ .{}, .{ .shell_id = 29 } };
var shell_count: u32 = 2;
var active_shell: u32 = 0;
var g_chat_view_mode: ChatViewMode = .everywhere;
var g_chat_active = true;
var saves: usize = 0;
var log: [96]u8 = undefined;
var log_len: usize = 0;
fn showHeaderNoticeAscii(_: []const u8, _: u32, _: bool) void {}
fn debugLog(line: []const u8) void { @memcpy(log[0..line.len], line); log_len = line.len; }
fn saveSession() void { saves += 1; }
fn openChatView() void { g_chat_active = true; }
fn closeChatView() void { g_chat_active = false; }
${text}
test "ISSUE-373 user toggle persists only the active session and clears its override" {
    toggleChatView();
    try std.testing.expect(!g_chat_active and shells[0].chat_shell_override);
    try std.testing.expect(!shells[1].chat_shell_override);
    try std.testing.expectEqualStrings("ISSUE-373 override=on shell=17", log[0..log_len]);
    active_shell = 1;
    g_chat_active = chatViewShouldShowForTab(.everywhere, shells[1].chat_view_on, shells[1].chat_shell_override, g_chat_active, true);
    try std.testing.expect(g_chat_active);
    active_shell = 0;
    g_chat_active = chatViewShouldShowForTab(.everywhere, shells[0].chat_view_on, shells[0].chat_shell_override, g_chat_active, true);
    try std.testing.expect(!g_chat_active);
    toggleChatView();
    try std.testing.expect(g_chat_active and !shells[0].chat_shell_override);
    try std.testing.expectEqualStrings("ISSUE-373 override=off shell=17", log[0..log_len]);
    try std.testing.expectEqual(@as(usize, 2), saves);
    g_chat_view_mode = .per_session;
    toggleChatView();
    try std.testing.expect(!shells[0].chat_shell_override);
    g_chat_view_mode = .nowhere;
    toggleChatView();
    try std.testing.expectEqual(@as(usize, 3), saves);
}
${writers.map((writer, index) => `test "ISSUE-373 writer ${index} round trips overrides and omits cleared overrides" {
    for ([_]bool{ false, true }) |override| {
        shells[0].chat_shell_override = override;
        var json_buf: [1024]u8 = undefined;
        const prefix = "{\\\"tabs\\\":[{\\\"kind\\\":\\\"cmd\\\",\\\"name\\\":\\\"Session\\\"";
        @memcpy(json_buf[0..prefix.len], prefix);
        var pos: usize = prefix.len;
        const i = 0;
${writer}
        @memcpy(json_buf[pos..][0..3], "}]}");
        pos += 3;
        var parsed = try json_reader.parse(std.testing.allocator, json_buf[0..pos]);
        defer parsed.deinit();
        var tabs: [1]SavedTab = undefined;
        try std.testing.expectEqual(@as(u32, 1), json_reader.sessionTabs(parsed.value, &tabs, 16));
        try std.testing.expectEqual(override, tabs[0].cso);
        try std.testing.expectEqual(override, std.mem.indexOf(u8, json_buf[0..pos], "\\\"cso\\\":true") != null);
    }
}`).join('\n')}
`;
}

test('ISSUE-373 executes user toggles, tab routing and both production JSON writers', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh373-'));
  try {
    copyZig(['json_reader.zig'], dir);
    const file = path.join(dir, 'test.zig');
    const production = body('chatViewShouldShowForTab') + '\n' + body('toggleChatView');
    fs.writeFileSync(file, harness(production));
    const zig = process.env.ZIG || 'zig';
    const result = spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
    const broken = production.replace('!(ISSUE_373_SHELL_OVERRIDE and shell_override)', '(!shell_override or true)');
    assert.notEqual(broken, production);
    fs.writeFileSync(file, harness(broken));
    const negative = spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(negative.status, 0);
    assert.match(negative.stderr, /ISSUE-373 user toggle[^]*FAIL/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('ISSUE-373 automatic view functions never change shell overrides and respawn preserves them', () => {
  for (const name of ['openChatView', 'closeChatView']) assert.doesNotMatch(body(name), /chat_shell_override\s*=/);
  assert.match(body('respawnShellInPlace'), /const saved_chat_shell_override = shells\[idx\]\.chat_shell_override;/);
  assert.match(body('respawnShellInPlace'), /\.chat_shell_override = saved_chat_shell_override,/);
  assert.match(body('restoreBrowserStateFromSavedTab'), /shells\[idx\]\.chat_shell_override = tab\.cso;/);
  const main = fs.readFileSync('src/main.zig', 'utf8');
  assert.ok(main.indexOf('const restored = restoreSession();') < main.lastIndexOf('chatViewShouldShowForTab('));
  assert.match(main.slice(main.lastIndexOf('chatViewShouldShowForTab(')), /chat_shell_override/);
});
