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
    decision_jobs = 0;
    dialog_answer = 2;
}

test "IGSH-1657 discovery Cancel and explicit retry" {
    reset();
    defer reset();
    deliver(.pull, listing_bytes, false, false);
    try std.testing.expectEqual(@as(usize, 1), prompts);
    for ([_]AccountJobKind{ .startup, .login, .pull, .push }) |kind| deliver(kind, listing_bytes, false, false);
    try std.testing.expectEqual(@as(usize, 1), prompts);
    try std.testing.expectEqualStrings(listing_bytes, g_account_pending_device_keys.?);
    dialog_answer = 6;
    deliver(.device_keys, listing_bytes, false, false);
    try std.testing.expectEqual(@as(usize, 2), prompts);
    try std.testing.expectEqual(@as(usize, 1), decision_jobs);
    try std.testing.expect(g_account_key_prompt_active and g_account_busy);
}

test "IGSH-1657 new device and changed key after Cancel" {
    reset();
    defer reset();
    const two = "{\"device_id\":\"self\",\"keys\":[{\"device_id\":\"other\",\"name\":\"Laptop\",\"public_key\":\"ssh-ed25519 AAAA\",\"status\":\"pending\"},{\"device_id\":\"phone\",\"name\":\"Phone\",\"public_key\":\"ssh-ed25519 BBBB\",\"status\":\"pending\"}]}";
    const changed = "{\"device_id\":\"self\",\"keys\":[{\"device_id\":\"other\",\"name\":\"Laptop\",\"public_key\":\"ssh-ed25519 CCCC\",\"status\":\"pending\"}]}";
    deliver(.pull, listing_bytes, false, false);
    deliver(.pull, two, false, false);
    try std.testing.expectEqual(@as(usize, 2), prompts);
    deliver(.pull, changed, false, false);
    try std.testing.expectEqual(@as(usize, 3), prompts);
    deliver(.pull, changed, false, false);
    try std.testing.expectEqual(@as(usize, 3), prompts);
    deliver(.pull, "{\"device_id\":\"self\",\"keys\":[]}", false, false);
    try std.testing.expect(g_account_pending_device_keys == null);
}

test "IGSH-1657 guards and excluded devices" {
    reset();
    defer reset();
    const excluded = "{\"device_id\":\"self\",\"keys\":[{\"device_id\":\"self\",\"name\":\"Self\",\"public_key\":\"ssh-ed25519 AAAA\",\"status\":\"pending\"},{\"device_id\":\"other\",\"name\":\"Laptop\",\"public_key\":\"ssh-ed25519 BBBB\",\"status\":\"approved\"}]}";
    deliver(.pull, excluded, false, false);
    deliver(.pull, listing_bytes, true, false);
    deliver(.pull, listing_bytes, false, true);
    g_account_key_prompt_active = true;
    deliver(.pull, listing_bytes, false, false);
    g_account_key_prompt_active = false;
    g_account_busy = true;
    accountPromptDeviceKeys(listing_bytes, false);
    g_account_busy = false;
    try std.testing.expectEqual(@as(usize, 0), prompts);
    try std.testing.expect(g_account_pending_device_keys == null);
    deliver(.pull, listing_bytes, false, false);
    try std.testing.expectEqual(@as(usize, 1), prompts);
    try std.testing.expect(!g_account_busy and !g_account_key_prompt_active);
    try std.testing.expectEqual(@as(usize, 0), decision_jobs);
}
