const std = @import("std");
const account_keys = @import("account_keys.zig");
const HANDLE = ?*anyopaque;
const AccountJobKind = enum { startup, login, pull, push, devices, revoke, signout, device_keys, decide_keys };
const AccountJob = struct { kind: AccountJobKind, edited: ?[]u8 = null };
const LayoutReply = struct { job: AccountJob, device_keys: ?[]const u8, key_error: ?[]const u8 = null, unauthorized: bool = false, cancelled: bool = false };
var g_main_hwnd: HANDLE = @ptrFromInt(1);
var g_account_busy = false;
var g_account_key_prompt_active = false;
var g_account_pending_device_keys: ?[]u8 = null;
var prompts: usize = 0;
var notices: usize = 0;
var dialog_answer: i32 = 2;
var decision_jobs: usize = 0;
const listing_bytes = "{\"device_id\":\"self\",\"keys\":[{\"device_id\":\"other\",\"name\":\"Laptop\",\"public_key\":\"ssh-ed25519 AAAA\",\"status\":\"pending\"}]}";
fn L(comptime text: []const u8) [*:0]const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(text);
}
fn MessageBoxW(_: HANDLE, _: [*:0]const u16, _: [*:0]const u16, _: u32) i32 {
    prompts += 1;
    return dialog_answer;
}
fn showHeaderNoticeAscii(text: []const u8, _: u64, beep: bool) void {
    std.debug.assert(std.mem.indexOf(u8, text, "device waits for approval") != null);
    std.debug.assert(std.mem.indexOf(u8, text, "Ctrl+K > Account: Approve devices") != null);
    std.debug.assert(!beep);
    notices += 1;
}
fn showSyncMessage(_: []const u8, _: bool) void {
    @panic("unexpected key error");
}
fn startAccountJob(job: AccountJob) void {
    std.debug.assert(job.kind == .decide_keys);
    std.heap.page_allocator.free(job.edited.?);
    decision_jobs += 1;
    g_account_busy = true;
}
fn reset() void {
    if (g_account_pending_device_keys) |bytes| std.heap.page_allocator.free(bytes);
    g_account_pending_device_keys = null;
    g_account_busy = false;
    g_account_key_prompt_active = false;
    prompts = 0;
    notices = 0;
    decision_jobs = 0;
    dialog_answer = 2;
}

test "ISSUE-451 background pending device replies retain state and show notice without prompting" {
    reset();
    defer reset();
    for ([_]AccountJobKind{ .startup, .login, .pull, .push, .decide_keys }) |kind| {
        deliver(kind, listing_bytes, false, false);
        try std.testing.expectEqual(@as(usize, 0), prompts);
        try std.testing.expect(g_account_pending_device_keys != null);
        try std.testing.expectEqualStrings(listing_bytes, g_account_pending_device_keys.?);
    }
    try std.testing.expectEqual(@as(usize, 5), notices);
    deliver(.pull, "{\"device_id\":\"self\",\"keys\":[]}", false, false);
    try std.testing.expect(g_account_pending_device_keys == null);
    try std.testing.expectEqual(@as(usize, 0), prompts);
}

test "ISSUE-451 explicit device command alone opens queued approvals and submits decisions" {
    reset();
    defer reset();
    deliver(.pull, listing_bytes, false, false);
    try std.testing.expectEqual(@as(usize, 0), prompts);
    dialog_answer = 6;
    deliver(.device_keys, listing_bytes, false, false);
    try std.testing.expectEqual(@as(usize, 1), prompts);
    try std.testing.expectEqual(@as(usize, 1), decision_jobs);
    try std.testing.expect(g_account_key_prompt_active);
    try std.testing.expect(g_account_busy);
}

test "ISSUE-451 Cancel keeps pending list but background replies never reprompt" {
    reset();
    defer reset();
    deliver(.device_keys, listing_bytes, false, false);
    try std.testing.expectEqual(@as(usize, 1), prompts);
    try std.testing.expect(!g_account_key_prompt_active);
    try std.testing.expect(!g_account_busy);
    try std.testing.expectEqual(@as(usize, 0), decision_jobs);
    for ([_]AccountJobKind{ .startup, .pull, .push }) |kind| deliver(kind, listing_bytes, false, false);
    try std.testing.expectEqual(@as(usize, 1), prompts);
    try std.testing.expect(g_account_pending_device_keys != null);
    deliver(.device_keys, listing_bytes, false, false);
    try std.testing.expectEqual(@as(usize, 2), prompts);
    deliver(.device_keys, listing_bytes, true, false);
    deliver(.device_keys, listing_bytes, false, true);
    try std.testing.expectEqual(@as(usize, 2), prompts);
}
