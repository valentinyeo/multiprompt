const { copyZig } = require('./zig-copy');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

test('IGSH-923 isolated remote fixture uses the actual persisted agent identity key', () => {
  const parser = fs.readFileSync('src/json_reader.zig', 'utf8');
  const key = parser.match(/tab\.claude_sid_len = copyString\(obj, "([^"]+)"/)[1];
  const driver = fs.readFileSync('tools/verify-chat-delivery/drive.ps1', 'utf8');
  assert.ok(driver.includes('$savedSession.tabs[0].' + key + ' ='));
  assert.ok(!driver.includes('$savedSession.tabs[0].claude_sid ='));
});

test('IGSH-923 reopening refreshes both triggers, errors back off, and failed responses preserve selectable cached skills', () => {
  const source = fs.readFileSync('src/chat_composer.zig', 'utf8');
  const state = fs.readFileSync('src/app_state.zig', 'utf8');
  const done = source.slice(source.indexOf('pub fn chatAcOnFetchDone('), source.indexOf('\nfn chatAcOnComposerChanged('));
  const afterSend = source.slice(source.indexOf('pub fn chatAcAfterSend('), source.indexOf('\npub fn chatAcOpenBrowse('));
  const policy = source.slice(source.indexOf('    if (opening and slot.pending', source.indexOf('fn chatAcOnComposerChanged(')), source.indexOf('\n}', source.indexOf('    if (opening and slot.pending', source.indexOf('fn chatAcOnComposerChanged('))));
  const slot = state.slice(state.indexOf('const ChatAcSlot = struct'), state.indexOf('\nconst ChatAc = struct'));
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-refresh-'));
  try {
    copyZig(['chat_complete.zig'], dir);
    fs.writeFileSync(path.join(dir, 'test.zig'), `const std = @import("std");
const chat_complete = @import("chat_complete.zig");
${slot}
const Mutex = struct { fn tryLock(_: *@This()) bool { return true; } fn unlock(_: *@This()) void {} };
const app_state = struct {
    var active_shell: usize = 0;
    var shell_count: usize = 1;
    var shells: [1]struct {
        kind: enum { tmux, vps2, local } = .tmux,
        tmux_host: u8 = 0,
        tmux_session: [64]u8 = @splat(0),
        tmux_session_len: usize = 0,
        claude_cwd: [192]u8 = @splat(0),
        claude_cwd_len: usize = 0,
    } = @splat(.{});
    var g_chat_ac_slots: [1]ChatAcSlot = @splat(.{});
    var g_chat_ac_mutex = Mutex{};
    var g_chat_ac = struct { open: bool = false, slot: usize = 0, token: chat_complete.Token = .{ .mode = .slash, .start = 0, .end = 1 } }{};
    const g_chat_composer_hwnd: usize = 0;
    const g_main_hwnd: usize = 0;
};
var agent: chat_complete.Agent = .claude;
fn chatAcAgent() chat_complete.Agent { return agent; }
fn isRemoteShellKind(kind: @TypeOf(app_state.shells[0].kind)) bool { return kind != .local; }
var clock: u64 = 1000000;
var requests: usize = 0;
var ranked: usize = 0;
const TIMER_CHAT_AC_DEBOUNCE = 1;
fn Sleep(_: u32) void {}
fn GetTickCount64() u64 { return clock; }
fn GetWindowTextW(_: usize, _: []u16, _: usize) i32 { return 0; }
fn SetTimer(_: usize, _: usize, _: u32, _: ?usize) usize { return 1; }
fn chatAcRank(_: []const u16, _: chat_complete.Token) void { ranked += 1; }
fn chatAcRequest(_: usize) void { requests += 1; }
fn refresh(opening: bool) void {
    const slot = &app_state.g_chat_ac_slots[0];
    const index: usize = 0;
${policy}
}
${done}
${afterSend}
fn response(bytes: []const u8) void {
    const item = &app_state.g_chat_ac_slots[0];
    item.pending = 7;
    item.pending_len = bytes.len;
    @memcpy(item.bytes[1 - item.active][0..bytes.len], bytes);
    chatAcOnFetchDone(7, 0);
}
test "reload refreshes only its own Claude session after a composer send" {
    const item = &app_state.g_chat_ac_slots[0];
    item.* = .{ .agent = .claude, .host = 0 };
    requests = 0;
    chatAcAfterSend(std.unicode.utf8ToUtf16LeStringLiteral("/help"));
    chatAcAfterSend(std.unicode.utf8ToUtf16LeStringLiteral("say /reload-plugins"));
    try std.testing.expectEqual(@as(usize, 0), requests);
    chatAcAfterSend(std.unicode.utf8ToUtf16LeStringLiteral(" /reload-plugins "));
    try std.testing.expectEqual(@as(usize, 1), requests);
    item.pending = 7;
    chatAcAfterSend(std.unicode.utf8ToUtf16LeStringLiteral("/reload-plugins"));
    try std.testing.expect(item.refresh_pending);
    try std.testing.expectEqual(@as(usize, 1), requests);
    item.pending = 0;
    item.host = 1;
    chatAcAfterSend(std.unicode.utf8ToUtf16LeStringLiteral("/reload-plugins"));
    try std.testing.expectEqual(@as(usize, 1), requests);
    item.host = 0;
    item.session[0] = 'x';
    chatAcAfterSend(std.unicode.utf8ToUtf16LeStringLiteral("/reload-plugins"));
    try std.testing.expectEqual(@as(usize, 1), requests);
    item.session[0] = 0;
    agent = .codex;
    chatAcAfterSend(std.unicode.utf8ToUtf16LeStringLiteral("/reload-plugins"));
    try std.testing.expectEqual(@as(usize, 1), requests);
    agent = .claude;
}
test "open triggers refresh; typing does not; errors retain sixty-second retry" {
    const item = &app_state.g_chat_ac_slots[0];
    item.* = .{ .fetched = clock - 1, .status = .ok };
    for ([_]chat_complete.Mode{ .slash, .dollar }) |mode| {
        item.mode = mode;
        requests = 0;
        refresh(false);
        try std.testing.expectEqual(@as(usize, 0), requests);
        refresh(true);
        try std.testing.expectEqual(@as(usize, 1), requests);
        item.pending = 1;
        refresh(true);
        try std.testing.expectEqual(@as(usize, 1), requests);
        try std.testing.expect(item.refresh_pending);
        item.refresh_pending = false;
        item.pending = 0;
    }
    requests = 0;
    item.fetched = clock - 600001;
    refresh(false);
    try std.testing.expectEqual(@as(usize, 1), requests);
    requests = 0;
    item.status = .@"error";
    item.fetched = clock - 59999;
    refresh(true);
    try std.testing.expectEqual(@as(usize, 0), requests);
    clock += 1;
    refresh(true);
    try std.testing.expectEqual(@as(usize, 1), requests);
}
test "bad refresh leaves old rows and their backing bytes usable" {
    app_state.g_chat_ac_slots[0] = .{};
    response("@mp\\t7\\tslash\\tok\\t/\\t1\\nS\\told-skill\\t\\tCached\\n@@MP_END@@\\n");
    for ([_][]const u8{ "bad", "@mp\\t8\\tslash\\tok\\t/\\t0\\n@@MP_END@@\\n", "@mp\\t7\\tslash\\terror\\t/\\t0\\n@@MP_END@@\\n", "@mp\\t7\\tslash\\tok\\t/\\t1\\nS\\twrong\\t\\tpartial\\n" }) |bad| {
        response(bad);
        const item = &app_state.g_chat_ac_slots[0];
        try std.testing.expectEqual(@as(usize, 1), item.count);
        try std.testing.expectEqualStrings("old-skill", item.entries[0].name);
        try std.testing.expectEqual(chat_complete.Status.@"error", item.status);
    }
    response("@mp\\t7\\tslash\\tloading\\t/\\t0\\n@@MP_END@@\\n");
    try std.testing.expectEqualStrings("old-skill", app_state.g_chat_ac_slots[0].entries[0].name);
    response("@mp\\t7\\tslash\\tok\\t/\\t1\\nS\\tnew-skill\\t\\tFresh\\n@@MP_END@@\\n");
    try std.testing.expectEqualStrings("new-skill", app_state.g_chat_ac_slots[0].entries[0].name);
}
test "reload requested during an inflight response runs afterward" {
    requests = 0;
    app_state.g_chat_ac_slots[0].refresh_pending = true;
    response("@mp\\t7\\tslash\\tok\\t/\\t0\\n@@MP_END@@\\n");
    try std.testing.expectEqual(@as(usize, 1), requests);
    try std.testing.expect(!app_state.g_chat_ac_slots[0].refresh_pending);
    requests = 0;
    app_state.g_chat_ac_slots[0].refresh_pending = true;
    response("bad");
    try std.testing.expectEqual(@as(usize, 0), requests);
    try std.testing.expect(!app_state.g_chat_ac_slots[0].refresh_pending);
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', 'test.zig'], { cwd: dir, encoding: 'utf8', timeout: 90000 });
    assert.equal(result.status, 0, JSON.stringify({ error: result.error?.message, signal: result.signal, stdout: result.stdout, stderr: result.stderr }));
    assert.match(result.stderr, /All \d+ tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
