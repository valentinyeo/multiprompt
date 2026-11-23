const std = @import("std");
const app_state = @import("app_state.zig");
const chat_session = @import("chat_session.zig");
const SessionIdentity = @import("session_identity.zig").Session;

const Reply = struct { result: struct { status: []const u8 = "", on: bool = false } = .{} };

const Toggle = struct { identity: SessionIdentity };

pub fn startToggle(tab: u32) bool {
    const identity = chat_session.chatFileIdentityForShell(tab).checked() orelse return false;
    const job = std.heap.page_allocator.create(Toggle) catch return false;
    job.* = .{ .identity = identity };
    const thread = std.Thread.spawn(.{ .stack_size = 256 * 1024 }, run, .{job}) catch {
        std.heap.page_allocator.destroy(job);
        return false;
    };
    thread.detach();
    return true;
}

fn request(out: []u8, identity: SessionIdentity) ?[]const u8 {
    const provider = identity.provider();
    const sid = std.mem.sliceTo(&identity.sid, 0);
    if (provider.len == 0 or sid.len == 0) return null;
    return std.fmt.bufPrint(out, "{{\"op\":\"set_auto_switch\",\"id\":{d},\"host\":{d},\"provider\":\"{s}\",\"sid\":\"{s}\",\"toggle\":true}}", .{ identity.owner, identity.host.index(), provider, sid }) catch null;
}

fn notice(text: []const u8) void {
    const a = std.heap.page_allocator;
    const message = a.dupeZ(u8, text) catch return;
    if (app_state.g_main_hwnd == null or @import("focus.zig").PostMessageW(app_state.g_main_hwnd, app_state.WM_APP_CHAT_ATTACH_FAILED, 0, @bitCast(@intFromPtr(message.ptr))) == 0) a.free(message);
}

fn run(job: *Toggle) void {
    defer std.heap.page_allocator.destroy(job);
    var buf: [320]u8 = undefined;
    const body = request(&buf, job.identity) orelse {
        notice("Auto-switch AI failed: this live chat cannot change it");
        return;
    };
    var response: std.ArrayList(u8) = .empty;
    defer response.deinit(std.heap.page_allocator);
    if (!chat_session.chatHistoryPersistent(job.identity, body, 65536, &response, null)) {
        notice("Auto-switch AI failed: the server did not answer");
        return;
    }
    const parsed = std.json.parseFromSlice(Reply, std.heap.page_allocator, std.mem.trim(u8, response.items, " \r\n"), .{ .ignore_unknown_fields = true }) catch {
        notice("Auto-switch AI failed: the server did not answer");
        return;
    };
    defer parsed.deinit();
    if (!std.mem.eql(u8, parsed.value.result.status, "ok")) {
        notice("Auto-switch AI failed: this live chat cannot change it");
        return;
    }
    notice(if (parsed.value.result.on) "Auto-switch AI is on" else "Auto-switch AI is off");
}

test "SOFT-2469 the auto-switch row toggles the saved host setting" {
    var buf: [320]u8 = undefined;
    const identity = SessionIdentity.remote(1, "same-chat", "11111111-2222-4333-8444-555555555555", 1) orelse return error.TestUnexpectedResult;
    const body = request(&buf, identity) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, body, "\"op\":\"set_auto_switch\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"toggle\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"provider\":\"claude\"") != null);
    try std.testing.expect(request(&buf, SessionIdentity.remote(1, "same-chat", "", 1) orelse return error.TestUnexpectedResult) == null);
}
