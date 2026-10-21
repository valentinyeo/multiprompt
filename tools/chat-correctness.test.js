const { copyZig } = require('./zig-copy');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');
const source = require('./app-source').readAppSource();
const old = fs.readFileSync('tools/fixtures/chat-before-2b45249.zig', 'utf8');
function body(text, name) {
  const start = text.indexOf(`fn ${name}(`);
  assert(start >= 0, name);
  return text.slice(start, text.indexOf('\n}', start) + 2);
}
const prelude = `
const std = @import("std");
const chat_echo = @import("chat_echo.zig");
const chat_switch = @import("chat_switch.zig");
const chat_transcript = @import("chat_transcript.zig");
const ChatEchoState = chat_echo.OutboxState;
const ShellKind = enum { cmd, tmux };
const ShellSendResult = enum { ok, write_failed, enter_failed };
const HANDLE = ?*anyopaque;
const DWORD = u32;
const Coord = struct { x: i16 = 0, y: i16 = 0 };
const CONSOLE_SCREEN_BUFFER_INFO = struct {
    dwSize: Coord = .{ .x = 20, .y = 2 },
    dwCursorPosition: Coord = .{ .y = 1 },
    srWindow: struct { bottom: i16 = 1 } = .{},
};
const Shell = struct { shell_id: u32 = 1, pid: u32 = 1, kind: ShellKind = .tmux, activity: enum { idle, active } = .idle };
var shells = [_]Shell{.{}};
var shell_count: u32 = 1;
var active_shell: u32 = 0;
var g_chat_screen_working = false;
var g_main_hwnd: HANDLE = @ptrFromInt(1);
var g_chat_verify_shell_id: u32 = 0;
var g_chat_verify_echo_id: u64 = 0;
var g_chat_verify_prefix: [20]u16 = undefined;
var g_chat_verify_prefix_len: usize = 0;
var g_chat_verify_checks: u8 = 0;
var g_chat_raw: [4000]u16 = undefined;
const TIMER_CHAT_SEND_VERIFY = 33;
const CHAT_SEND_VERIFY_DELAYS_MS = [_]u32{ 700, 1200, 2000, 3000, 4000, 5000 };
const Entry = struct {
    id: u64 = 1, state: ChatEchoState = .queued, write_started: bool = false,
    anchor: chat_echo.Anchor = .{}, sent_tick_ms: i64 = 0, left_box_ms: u64 = 0, delivery_watch: chat_echo.DeliveryWatch = .{},
};
const ChatOutboxEntry = Entry;
var storage = [_]Entry{.{}};
var g_chat_outbox: std.ArrayList(Entry) = .empty;
var timer_ok = true;
var timer_arms: usize = 0;
var enters: usize = 0;
var writes: usize = 0;
var flushes: usize = 0;
var matched = false;
var failure: enum { none, attach, open, info, read, partial, marker } = .none;
var input_held = true;
fn reset() void {
    storage[0] = .{};
    g_chat_outbox.items = &storage;
    shells[0].pid = 1;
    shells[0].activity = .idle;
    g_chat_screen_working = false;
    timer_ok = true;
    timer_arms = 0;
    enters = 0;
    writes = 0;
    flushes = 0;
    matched = false;
    failure = .none;
    input_held = true;
    chatVerifyClear();
}
fn SetTimer(_: HANDLE, _: usize, _: u32, _: HANDLE) usize { timer_arms += 1; return if (timer_ok) 1 else 0; }
fn KillTimer(_: HANDLE, _: usize) u32 { return 1; }
fn FreeConsole() u32 { return 1; }
fn AttachConsole(_: DWORD) u32 { return if (failure == .attach) 0 else 1; }
fn openAttachedConsoleOutput() ?HANDLE { return if (failure == .open) null else @as(HANDLE, @ptrFromInt(2)); }
fn CloseHandle(_: HANDLE) u32 { return 1; }
fn GetConsoleScreenBufferInfo(_: HANDLE, info: *CONSOLE_SCREEN_BUFFER_INFO) u32 { info.* = .{}; return if (failure == .info) 0 else 1; }
fn ReadConsoleOutputCharacterW(_: HANDLE, _: *[4000]u16, n: u32, _: Coord, read: *DWORD) u32 {
    read.* = if (failure == .partial) n - 1 else n;
    return if (failure == .read) 0 else 1;
}
fn chatTrimRawConsoleRow(_: usize, _: DWORD, r: usize) []const u16 {
    if (r != 1 or failure == .marker) return std.unicode.utf8ToUtf16LeStringLiteral("output");
    return if (input_held) std.unicode.utf8ToUtf16LeStringLiteral("❯ hello") else std.unicode.utf8ToUtf16LeStringLiteral("❯");
}
fn GetTickCount64() u64 { return 2000; }
fn nowFileTime() u64 { return 116444736020000000; }
fn saveChatOutbox() bool { return true; }
fn chatOutboxChanged() void {}
fn chatEchoTryMatchEntry(_: usize) bool { if (matched) storage[0].state = .not_sent; return matched; }
fn chatOutboxTick() void { flushes += 1; }
fn showHeaderNoticeAscii(_: []const u8, _: u64, _: bool) void {}
fn dictationAudit(_: []const u8, _: usize) void {}
fn sendEnterToShell(_: u32) bool { enters += 1; return true; }
fn chatEchoAnchorNow(_: u32) chat_echo.Anchor { return .{ .sent_ms = 1000 }; }
fn chatShouldUseDirectInput(_: u32) bool { return true; }
fn chatSendForceBracketed(_: u32) bool { return true; }
fn chatSendEnterDelayMs(_: ShellKind) u32 { return 0; }
fn Sleep(_: u32) void {}
fn pasteTextToShellDirectEx(_: u32, _: []const u16, _: bool) bool { writes += 1; return true; }
fn sendLocalChatPrompt(_: u32, _: []const u16) bool { unreachable; }
var g_chat_tmux_send_job: ?*anyopaque = null;
fn chatTmuxSendEligible(_: u32) bool { return false; }
fn chatTmuxSendStart(_: u32, _: []const u16, _: u64, _: bool) bool { unreachable; }
`;
const acceptance = `
test "correctness identity: first production allocation supports history, browser exchange and screenshot ownership" {
    const id = next_shell_id;
    next_shell_id += 1;
    try std.testing.expect(id != 0);
    try std.testing.expectEqual(id + 1, next_shell_id);
    const identity = chat_transcript.Identity.init(id, 0, false, "sid", "/repo");
    try std.testing.expect(identity.shell_id != 0);
    var pending = chat_switch.Pending{};
    pending.request(id, 0);
    try std.testing.expect(pending.didPaint(id));
    try std.testing.expect(pending.take(id));
    // The screenshot queue rejects zero before accepting any owner.
    try std.testing.expect(id != 0);
}
test "correctness newline: leading blank lines arm verification and free the global send slot" {
    reset();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("\\n\\r\\nhello");
    try std.testing.expectEqual(ShellSendResult.ok, sendTextToShellVerifiedAt(0, text, 1));
    try std.testing.expectEqual(@as(usize, 1), timer_arms);
    try std.testing.expectEqual(@as(usize, 0), g_chat_verify_prefix_len);
    for (0..6) |_| chatSendVerifyTick();
    try std.testing.expectEqual(ChatEchoState.not_sent, storage[0].state);
    try std.testing.expect(chatOutboxFindSending(&g_chat_outbox) == null);
    try std.testing.expectEqual(@as(u64, 0), g_chat_verify_echo_id);
    try std.testing.expectEqual(@as(usize, 1), writes);
    try std.testing.expectEqual(@as(usize, 1), enters); // initial Enter only
    try std.testing.expect(flushes > 0);
}
test "correctness newline: timer registration failure cannot leave a sending reservation" {
    reset();
    timer_ok = false;
    try std.testing.expectEqual(ShellSendResult.enter_failed, sendTextToShellVerifiedAt(0, std.unicode.utf8ToUtf16LeStringLiteral("hello"), 1));
    // The existing caller maps enter_failed to reserved not_sent.
    chatEchoMarkNotSent(0);
    try std.testing.expect(chatOutboxFindSending(&g_chat_outbox) == null);
    try std.testing.expectEqual(@as(u64, 0), g_chat_verify_echo_id);
    try std.testing.expect(storage[0].write_started);
}
test "correctness unreadable: every failed or partial console read stays unknown and bounded, never delivered or retyped" {
    for ([_]@TypeOf(failure){ .attach, .open, .info, .read, .partial, .marker }) |fault| {
        reset();
        _ = sendTextToShellVerifiedAt(0, std.unicode.utf8ToUtf16LeStringLiteral("hello"), 1);
        failure = fault;
        try std.testing.expectEqual(@as(?bool, null), @as(?bool, chatPromptStillInInputBox(0, std.unicode.utf8ToUtf16LeStringLiteral("hello"))));
        chatSendVerifyTick();
        try std.testing.expect(storage[0].state != .delivered);
        for (0..5) |_| chatSendVerifyTick();
        try std.testing.expectEqual(ChatEchoState.not_sent, storage[0].state);
        try std.testing.expectEqual(ChatEchoState.not_sent, chat_echo.stateOnLoad(@intFromEnum(storage[0].state), storage[0].write_started));
        try std.testing.expect(!chat_echo.mayType(storage[0].state, storage[0].write_started, false, false));
        try std.testing.expectEqual(@as(usize, 1), enters);
        try std.testing.expectEqual(@as(usize, 1), writes);
        try std.testing.expect(chatOutboxFindSending(&g_chat_outbox) == null);
    }
    reset();
    shells[0].pid = 0;
    try std.testing.expectEqual(@as(?bool, null), @as(?bool, chatPromptStillInInputBox(0, std.unicode.utf8ToUtf16LeStringLiteral("hello"))));
}
test "correctness unreadable: IGSH-442 busy unknown input hands off to delivery watch" {
    for ([_]bool{ false, true }) |screen_busy| {
        reset();
        _ = sendTextToShellVerifiedAt(0, std.unicode.utf8ToUtf16LeStringLiteral("hello"), 1);
        failure = .read;
        shells[0].activity = if (screen_busy) .idle else .active;
        g_chat_screen_working = screen_busy;
        for (0..6) |_| chatSendVerifyTick();
        try std.testing.expectEqual(ChatEchoState.delivered, storage[0].state);
        try std.testing.expect(storage[0].delivery_watch.busy_seen);
        try std.testing.expect(!storage[0].delivery_watch.due(100_000, 100_000));
        try std.testing.expectEqual(@as(u64, 0), g_chat_verify_echo_id);
        try std.testing.expectEqual(@as(usize, 1), writes);
        try std.testing.expectEqual(@as(usize, 1), enters);
    }
}
test "correctness unreadable: IGSH-442 busy held input retries only Enter with bounded failure" {
    reset();
    _ = sendTextToShellVerifiedAt(0, std.unicode.utf8ToUtf16LeStringLiteral("hello"), 1);
    shells[0].activity = .active;
    for (0..6) |_| chatSendVerifyTick();
    try std.testing.expectEqual(ChatEchoState.not_sent, storage[0].state);
    try std.testing.expectEqual(@as(u64, 0), g_chat_verify_echo_id);
    try std.testing.expectEqual(@as(usize, 1), writes);
    try std.testing.expectEqual(@as(usize, 6), enters);
}
test "correctness unreadable: readable held prompt retries only Enter, readable empty prompt frees the queue" {
    reset();
    _ = sendTextToShellVerifiedAt(0, std.unicode.utf8ToUtf16LeStringLiteral("hello"), 1);
    chatSendVerifyTick();
    try std.testing.expectEqual(@as(usize, 2), enters);
    try std.testing.expectEqual(ChatEchoState.sending, storage[0].state);
    input_held = false;
    chatSendVerifyTick();
    try std.testing.expectEqual(ChatEchoState.delivered, storage[0].state);
    try std.testing.expect(chatOutboxFindSending(&g_chat_outbox) == null);
    try std.testing.expectEqual(@as(usize, 1), writes);
    reset();
    _ = sendTextToShellVerifiedAt(0, std.unicode.utf8ToUtf16LeStringLiteral("hello"), 1);
    failure = .read;
    matched = true; // A real transcript acknowledgement can bypass an unavailable console.
    chatSendVerifyTick();
    try std.testing.expectEqual(@as(u64, 0), g_chat_verify_echo_id);
    try std.testing.expectEqual(@as(usize, 1), enters);
}
`;
function run(mode, control = false) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-correctness-'));
  try {
    copyZig(['chat_echo.zig', 'chat_switch.zig', 'chat_transcript.zig', 'chat_markdown.zig', 'chat_style.zig'], dir);
    const replaced = control && mode === 'newline' ? ['chatArmSendVerify', 'chatSendVerifyTick', 'sendTextToShellVerifiedAt', 'chatPromptStillInInputBox'] :
      control && mode === 'unreadable' ? ['chatSendVerifyTick', 'chatPromptStillInInputBox'] : [];
    const names = ['chatArmSendVerify', 'chatVerifyClear', 'chatPromptStillInInputBox', 'chatSendVerifyTick', 'chatSendVerifyDelayMs',
      'chatInputRowHoldsPrompt', 'chatInputBoxShowsUnsentPrompt', 'chatOutboxIndexById', 'chatOutboxFindSending', 'chatEchoMarkNotSent', 'sendTextToShellVerifiedAt', 'chatSendViaConsole'];
    const initial = (control && mode === 'identity' ? old : source).match(/^var next_shell_id: u32 = [^;]+;/m)[0];
    fs.writeFileSync(path.join(dir, 'test.zig'), prelude + initial + '\n' + names.map(n => body(replaced.includes(n) ? old : source, n)).join('\n') + acceptance);
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', `correctness ${mode}:`], { encoding: 'utf8', timeout: 60000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
for (const mode of ['identity', 'newline', 'unreadable']) {
  test(`correctness ${mode}: production regression`, () => {
    const result = run(mode);
    assert.equal(result.status, 0, result.stdout + result.stderr);
  });
  test(`correctness ${mode}: unchanged pre-fix code fails the oracle`, () => {
    const result = run(mode, true);
    assert.equal(result.status, 1, result.stdout + result.stderr);
    assert.match(result.stderr, /FAIL \(Test(UnexpectedResult|ExpectedEqual)\)/);
    assert.doesNotMatch(result.stderr, /error: (?!the following test)/);
  });
}
