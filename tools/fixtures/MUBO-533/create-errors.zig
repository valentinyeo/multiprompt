const std = @import("std");
const diagnostics = struct { fn syncLog(_: []const u8) void {} };
var draft_saved = true;
var ready = false;
var error_text: [2048]u8 = undefined;
var error_len: usize = 0;
var account_len: usize = 0;
var restore_pending = false;
var selection_generation: u64 = 0;
var selection_waiting = false;
var discovery_attempts: u8 = 0;
const TIMER_ROOM = 1;
const app_state = struct { const g_main_hwnd: usize = 0; var g_account_locked = false; };
const w = struct {
    const LPCWSTR = [*:0]const u16;
    fn MessageBoxW(_: usize, reason: LPCWSTR, _: LPCWSTR, _: u32) i32 {
        error_len = std.unicode.utf16LeToUtf8(&error_text, std.mem.span(reason)) catch unreachable;
        return 1;
    }
    fn SetTimer(_: usize, _: usize, _: usize, _: ?*anyopaque) usize { return 1; }
};
const Controller = struct { job: ?u8 = null };
var controller: ?Controller = null;
var applied_routes: [3]?u8 = @splat(null);
var front: union(enum) { hidden, create: ?u8 } = .hidden;
var view = struct {
    fn openCreate(_: *@This()) void {}
    fn showUnavailable(_: *@This()) void {}
    fn showError(_: *@This(), reason: []const u8) void { @memcpy(error_text[0..reason.len], reason); error_len = reason.len; }
}{};
fn saveDraft() bool { return draft_saved; }
fn enter() bool { return ready; }
fn markUiDirty() void {}
fn scanCandidates() void {}
fn publishCreateCandidates() bool { return true; }
fn resize(_: usize) void {}
fn syncVisibility() void {}
fn beginDiscovery(_: bool) void {}
fn discoverStores() void {}
fn nextStatus(_: *Controller) bool { return false; }
fn armPoll() void {}

test "creation explains unavailable account state and never discards an unsaved draft" {
    openCreate();
    try std.testing.expect(std.mem.indexOf(u8, error_text[0..error_len], "Sign in") != null);
    account_len = 7;
    openCreate();
    try std.testing.expect(std.mem.indexOf(u8, error_text[0..error_len], "not ready") != null);
    ready = true;
    draft_saved = false;
    openCreate();
    try std.testing.expect(std.mem.indexOf(u8, error_text[0..error_len], "save your room draft") != null);
    draft_saved = true;
    openCreate();
    try std.testing.expect(std.mem.indexOf(u8, error_text[0..error_len], "Add a server") != null);
}
