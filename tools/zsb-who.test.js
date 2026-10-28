const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const test = require("node:test");

const source = require('./app-source').readAppSource(process.env.ZSB_MAIN_ZIG);
function section(start, end) {
  const begin = source.indexOf(start);
  const finish = source.indexOf(end, begin);
  assert.ok(begin >= 0 && finish > begin, `missing production section ${start}`);
  return source.slice(begin, finish);
}

test("tunnel listener answers ZSBWHO before notification handling, without reading shells", () => {
  const listener = section("fn tunnelInboundThread(", "fn startTunnelInboundListener(");
  assert.match(listener, /startsWith\(u8, trimmed, "ZSBWHO:"\)/);
  assert.match(listener, /sendZsbWhoResponse\(client, trimmed\[7\.\.\], host\);\s+_ = closesocket\(client\);\s+continue;/);
  assert.doesNotMatch(listener, /shells\[/);
  const responder = section("fn sendZsbWhoResponse(", "var g_zsb_open_mutex:");
  assert.doesNotMatch(responder.replace(/\/\/[^\n]*/g, ""), /shells\[|findLocalTmuxTab\(/);
  assert.match(source, /WM_APP_ZSB_WHO => \{\s+handleZsbWhoRequest\(\);/);
});

test("production Zig probe executes ownership, JSON, idle rollover and canceled-mailbox regressions", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "mp-who-test-"));
  try {
    const file = path.join(dir, "probe.zig");
    fs.writeFileSync(file, (String.raw`
const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const SOCKET = usize;
const DWORD = u32;
const LASTINPUTINFO = struct { cbSize: u32, dwTime: u32 };
const TMUX_HOST_DE = 0;
const TMUX_HOST_UK = 1;
const TMUX_HOST_INNE = 2;
const WM_APP_ZSB_WHO = 151;
const SpinMutex = struct {
    locked: bool = false,
    fn tryLock(self: *@This()) bool {
        if (self.locked) return false;
        self.locked = true;
        return true;
    }
    fn unlock(self: *@This()) void { self.locked = false; }
};
const Shell = struct {
    tmux_session: []const u8,
    tmux_session_len: usize,
    name: []const u16,
    name_len: usize,
};
const shells = [_]Shell{.{ .tmux_session = "agent-1", .tmux_session_len = 7,
    .name = &[_]u16{ 'C', 'l', 'a', 'u', 'd', 'e', ':', ' ', 'a', 'g', 'e', 'n', 't', '-', '1' }, .name_len = 15 }};
var g_main_hwnd: ?usize = 1;
var tick: u64 = 0;
var last_input: u32 = 0;
var input_ok = true;
var post_mode: enum { immediate, delayed, failed } = .immediate;
var owner_host: ?u8 = 0;
var sent: [1024]u8 = undefined;
var sent_len: usize = 0;
fn Sleep(_: u32) void { tick += 1; }
fn GetTickCount64() u64 { return tick; }
fn GetTickCount() u32 { return @truncate(tick); }
fn GetLastInputInfo(info: *LASTINPUTINFO) i32 {
    info.dwTime = last_input;
    return if (input_ok and info.cbSize == @sizeOf(LASTINPUTINFO)) 1 else 0;
}
fn GetComputerNameW(out: [*]u16, size: *DWORD) i32 {
    const host = [_]u16{ 'P', '1', '"', '\\', 0x00f3 };
    @memcpy(out[0..host.len], &host);
    size.* = host.len;
    return 1;
}
fn PostMessageW(_: ?usize, _: u32, _: usize, _: usize) i32 {
    if (post_mode == .failed) return 0;
    if (post_mode == .immediate) handleZsbWhoRequest();
    return 1;
}
fn findLocalTmuxTab(host: u8, session: []const u8) ?u32 {
    std.debug.assert(g_zsb_who_mutex.locked);
    return if (owner_host == host and std.mem.eql(u8, session, "agent-1")) 0 else null;
}
fn socketSendAll(_: SOCKET, out: []const u8) void {
    @memcpy(sent[0..out.len], out);
    sent_len = out.len;
}
` + section("var g_zsb_who_mutex:", "var g_zsb_open_mutex:") +
      section("fn shellTextMatchesToken(", "fn shellMatchesTitleTarget(i: usize, token: []const u8) bool {") +
      section("fn zsbAppendJsonString(", "fn zsbSendJsonError(") +
      section("fn appendAsciiBuf(", "\n}\n") + "\n}\n" + String.raw`
fn reset() void {
    tick = 100;
    last_input = 90;
    input_ok = true;
    post_mode = .immediate;
    g_main_hwnd = 1;
    owner_host = 0;
    sent_len = 0;
    g_zsb_who_pending = false;
    g_zsb_who_done = false;
}
fn checkReply(has_tab: bool, idle: u32) !void {
    try std.testing.expect(sent_len > 0);
    try std.testing.expectEqual(@as(u8, '\n'), sent[sent_len - 1]);
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, sent[0..sent_len], .{});
    defer parsed.deinit();
    const obj = parsed.value.object;
    try std.testing.expectEqual(has_tab, obj.get("has_tab").?.bool);
    try std.testing.expectEqual(@as(i64, idle), obj.get("idle_ms").?.integer);
    try std.testing.expectEqualStrings("P1\"\\ó", obj.get("host").?.string);
}
test "hex probe cannot match legacy notification tokens; plaintext positive control matches" {
    const messages = [_][]const u8{ "ZSBWHO:agent-1", "ZSBWHO:6167656e742d31" };
    for (messages, 0..) |message, i| {
        var tokens = std.mem.tokenizeAny(u8, message, "|,;:");
        var matched = false;
        while (tokens.next()) |token| {
            matched = matched or shellMatchesNotificationExact(0, token) or shellMatchesNotificationToken(0, token);
        }
        try std.testing.expectEqual(i == 0, matched);
    }
}
test "ownership on each tmux host and missing session" {
    for ([_]u8{ 0, 1, 2 }) |host| {
        reset();
        owner_host = host;
        sendZsbWhoResponse(1, "6167656e742d31", null);
        try checkReply(true, 10);
    }
    reset();
    sendZsbWhoResponse(1, "6f74686572", null);
    try checkReply(false, 10);
}
test "host-bound probes cannot claim the same session on another host" {
    reset();
    owner_host = 0;
    sendZsbWhoResponse(1, "6167656e742d31", 2);
    try checkReply(false, 10);
    reset();
    owner_host = 2;
    sendZsbWhoResponse(1, "6167656e742d31", 2);
    try checkReply(true, 10);
}
test "idle wraps at 32 bits and input failure ranks last" {
    reset();
    tick = 0x100000010;
    last_input = 0xfffffff0;
    sendZsbWhoResponse(1, "6167656e742d31", null);
    try checkReply(true, 32);
    reset();
    input_ok = false;
    sendZsbWhoResponse(1, "6167656e742d31", null);
    try checkReply(true, std.math.maxInt(u32));
}
test "timeout cancels mailbox and late UI dispatch cannot poison next probe" {
    reset();
    post_mode = .delayed;
    sendZsbWhoResponse(1, "6167656e742d31", null);
    try std.testing.expectEqual(@as(usize, 0), sent_len);
    try std.testing.expect(tick <= 301);
    try std.testing.expect(!g_zsb_who_pending);
    handleZsbWhoRequest();
    try std.testing.expect(!g_zsb_who_done);
    post_mode = .immediate;
    sendZsbWhoResponse(1, "6f74686572", null);
    try checkReply(false, @intCast(tick - last_input));
}
test "failed post and invalid session do not fabricate ownership" {
    reset();
    post_mode = .failed;
    sendZsbWhoResponse(1, "6167656e742d31", null);
    try std.testing.expect(!g_zsb_who_pending);
    try std.testing.expectEqual(@as(usize, 0), sent_len);
    reset();
    sendZsbWhoResponse(1, "", null);
    sendZsbWhoResponse(1, &([_]u8{'0'} ** 130), null);
    sendZsbWhoResponse(1, "6", null);
    sendZsbWhoResponse(1, "zz", null);
    sendZsbWhoResponse(1, "agent-1", null);
    try std.testing.expectEqual(@as(usize, 0), sent_len);
}
`).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const localZig = path.join(os.homedir(), ".local", "zig-0.16.0", "zig");
    const zig = process.env.ZIG || (fs.existsSync(localZig) ? localZig : "zig");
    const run = spawnSync(zig, ["test", file], { encoding: "utf8", timeout: 120000 });
    assert.equal(run.status, 0, run.stdout + run.stderr);
    assert.match(run.stderr, /All 5 tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
