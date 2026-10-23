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
    const start = code.lastIndexOf('        if (pos < json_buf.len - 540) {', code.indexOf('const saved_lock = @import("chat_view.zig").savedLock'));
    assert.ok(start >= 0, file);
    return code.slice(start, code.indexOf('\n        }', start) + 10).replaceAll('app_state.', '');
  });
  return `const std = @import("std");
const json_reader = @import("json_reader.zig");
const archive_rules = @import("archive_rules.zig");
const view = @import("chat_view.zig");
const chatViewShouldShowForTab = view.shouldShow;
const DWORD = u32;
const BROWSER_SPLIT_DEFAULT_PERMILLE = 350;
${kind}
${savedTab}
const Shell = struct { shell_id: u32 = 17, chat_view_on: bool = false, chat_view_lock: view.Lock = .none };
var shells = [_]Shell{ .{}, .{ .shell_id = 29 } };
var shell_count: u32 = 2;
var active_shell: u32 = 0;
var g_chat_active = true;
var saves: usize = 0;
fn showHeaderNoticeAscii(_: []const u8, _: u32, _: bool) void {}
fn saveSession() void { saves += 1; }
fn openChatView() void { g_chat_active = true; }
fn closeChatView() void { g_chat_active = false; }
${text}
test "ISSUE-611 user toggle sticks after a one-time everywhere action and respects locks" {
    view.setEverywhere(&shells, true);
    toggleChatView();
    try std.testing.expect(!g_chat_active and !shells[0].chat_view_on);
    try std.testing.expect(shells[1].chat_view_on);
    active_shell = 1;
    g_chat_active = chatViewShouldShowForTab(shells[1].chat_view_on, shells[1].chat_view_lock);
    try std.testing.expect(g_chat_active);
    active_shell = 0;
    g_chat_active = chatViewShouldShowForTab(shells[0].chat_view_on, shells[0].chat_view_lock);
    try std.testing.expect(!g_chat_active);
    toggleChatView();
    try std.testing.expect(g_chat_active and shells[0].chat_view_on);
    try std.testing.expectEqual(@as(usize, 2), saves);
    for ([_]view.Lock{ .chat, .shell }) |lock| {
        view.setLock(&shells[0], lock);
        g_chat_active = lock == .chat;
        toggleChatView();
        try std.testing.expectEqual(lock == .chat, g_chat_active);
        try std.testing.expectEqual(lock == .chat, shells[0].chat_view_on);
        try std.testing.expectEqual(@as(usize, 2), saves);
    }
    view.setLock(&shells[0], .none);
    toggleChatView();
    try std.testing.expect(g_chat_active and shells[0].chat_view_on);
    try std.testing.expectEqual(@as(usize, 3), saves);
}
test "ISSUE-611 ISSUE-373 legacy shell override migration is scoped and does not become a lock" {
    const json = "{\\\"chat_view_mode\\\":\\\"everywhere\\\",\\\"tabs\\\":[{\\\"kind\\\":\\\"cmd\\\",\\\"name\\\":\\\"Shell\\\",\\\"cso\\\":true},{\\\"kind\\\":\\\"cmd\\\",\\\"name\\\":\\\"Chat\\\",\\\"extra\\\":{\\\"cso\\\":true}}]}";
    var parsed = try json_reader.parse(std.testing.allocator, json);
    defer parsed.deinit();
    var tabs: [2]SavedTab = undefined;
    try std.testing.expectEqual(@as(u32, 2), json_reader.sessionTabs(parsed.value, &tabs, 16));
    try std.testing.expect(!tabs[0].cv and tabs[1].cv);
    try std.testing.expectEqual(view.Lock.none, tabs[0].chat_view_lock);
    try std.testing.expectEqual(view.Lock.none, tabs[1].chat_view_lock);
}
${writers.map((writer, index) => `test "ISSUE-611 writer ${index} round trips both locks and omits cleared locks" {
    for ([_]view.Lock{ .none, .chat, .shell }) |lock| {
        view.setLock(&shells[0], lock);
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
        try std.testing.expectEqual(lock, tabs[0].chat_view_lock);
        try std.testing.expectEqual(lock != .none, std.mem.indexOf(u8, json_buf[0..pos], "chat_view_lock") != null);
        try std.testing.expectEqual(lock == .chat, tabs[0].cv);
    }
}`).join('\n')}
`;
}

test('ISSUE-611 executes user toggles, tab routing, legacy shell migration and both production JSON writers', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-view-locks-'));
  try {
    copyZig(['json_reader.zig', 'chat_view.zig'], dir);
    const file = path.join(dir, 'test.zig');
    const production = body('toggleChatView');
    fs.writeFileSync(file, harness(production));
    const zig = process.env.ZIG || 'zig';
    const result = spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
    const broken = production.replace('@import("chat_view.zig").toggle(shell);', 'shell.chat_view_on = true;');
    assert.notEqual(broken, production);
    fs.writeFileSync(file, harness(broken));
    const negative = spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(negative.status, 0);
    assert.match(negative.stderr, /ISSUE-611 user toggle[^]*FAIL/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('ISSUE-611 automatic view functions preserve locks and respawn and restoration retain them', () => {
  for (const name of ['openChatView', 'closeChatView']) assert.doesNotMatch(body(name), /chat_view_lock\s*=(?!=)/);
  assert.match(body('respawnShellInPlace'), /const saved_chat_view_lock = shells\[idx\]\.chat_view_lock;/);
  assert.match(body('respawnShellInPlace'), /\.chat_view_lock = saved_chat_view_lock,/);
  assert.match(body('restoreBrowserStateFromSavedTab'), /shells\[idx\]\.chat_view_lock = tab\.chat_view_lock;/);
  const main = fs.readFileSync('src/main.zig', 'utf8');
  assert.ok(main.indexOf('const restored = restoreSession();') < main.lastIndexOf('applySessionView('));
  assert.match(main, /launch_cache.bindRestoredChat\(\);\s*@import\("chat_composer.zig"\).applySessionView\(\);/);
});
