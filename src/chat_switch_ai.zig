const std = @import("std");
const SessionIdentity = @import("session_identity.zig").Session;

pub fn switchAiAgentTarget(agent: u8) ?u8 {
    return switch (agent) {
        1 => 1,
        2 => 2,
        3 => 3,
        8 => 4,
        else => null,
    };
}

pub fn switchAiVisible(agent: u8, target: u8) bool {
    const current = switchAiAgentTarget(agent) orelse return false;
    return current != target;
}

pub fn switchAiName(target: u8) []const u8 {
    return switch (target) {
        1 => "claude",
        2 => "codex",
        3 => "pi",
        4 => "antigravity",
        else => "",
    };
}

pub fn switchAgentId(name: []const u8) ?u8 {
    if (std.mem.eql(u8, name, "claude")) return 1;
    if (std.mem.eql(u8, name, "codex")) return 2;
    if (std.mem.eql(u8, name, "pi")) return 3;
    if (std.mem.eql(u8, name, "antigravity")) return 8;
    return null;
}

pub fn switchAiDone(target: u8) []const u8 {
    return switch (target) {
        1 => "Chat switched to Claude",
        2 => "Chat switched to Codex",
        3 => "Chat switched to Pi",
        4 => "Chat switched to Antigravity",
        else => "Chat switched",
    };
}

pub fn switchSidOk(sid: []const u8) bool {
    if (sid.len == 0 or sid.len > 40) return false;
    for (sid) |c| {
        if (!((c >= '0' and c <= '9') or (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or c == '-' or c == '_')) return false;
    }
    return true;
}

pub const SwitchEnvelope = struct {
    status: []const u8 = "",
    provider: []const u8 = "",
    sid: []const u8 = "",
    reason: []const u8 = "",
    result: struct {
        status: []const u8 = "",
        provider: []const u8 = "",
        sid: []const u8 = "",
        reason: []const u8 = "",
    } = .{},
};

pub fn switchEnvelopeFields(value: SwitchEnvelope) struct { status: []const u8, provider: []const u8, sid: []const u8, reason: []const u8 } {
    const nested = value.result.status.len != 0 or value.result.provider.len != 0 or value.result.sid.len != 0 or value.result.reason.len != 0;
    if (nested) return .{ .status = value.result.status, .provider = value.result.provider, .sid = value.result.sid, .reason = value.result.reason };
    return .{ .status = value.status, .provider = value.provider, .sid = value.sid, .reason = value.reason };
}

pub fn switchAgentKnown(agent: u8) bool {
    return agent == 1 or agent == 2 or agent == 3 or agent == 7 or agent == 8;
}

pub fn adoptShellAgent(agent: *u8, sid: []u8, sid_len: *u32, next_agent: u8, next_sid: []const u8) bool {
    if (!switchAgentKnown(next_agent) or !switchSidOk(next_sid) or next_sid.len > sid.len) return false;
    agent.* = next_agent;
    @memset(sid, 0);
    @memcpy(sid[0..next_sid.len], next_sid);
    sid_len.* = @intCast(next_sid.len);
    return true;
}

pub fn adoptedSwitch(allocator: std.mem.Allocator, body: []const u8, sid_out: []u8) ?struct { agent: u8, sid_len: usize } {
    const parsed = std.json.parseFromSlice(SwitchEnvelope, allocator, std.mem.trim(u8, body, " \r\n"), .{ .ignore_unknown_fields = true }) catch return null;
    defer parsed.deinit();
    const fields = switchEnvelopeFields(parsed.value);
    if (!std.mem.eql(u8, fields.status, "switched")) return null;
    const agent = switchAgentId(fields.provider) orelse return null;
    if (!switchSidOk(fields.sid) or fields.sid.len > sid_out.len) return null;
    @memcpy(sid_out[0..fields.sid.len], fields.sid);
    return .{ .agent = agent, .sid_len = fields.sid.len };
}

pub fn switchAiRequest(out: []u8, identity: SessionIdentity, to: []const u8) ?[]const u8 {
    const id = identity.owner;
    const host = identity.host.index();
    const provider = identity.provider();
    const sid = std.mem.sliceTo(&identity.sid, 0);
    if (provider.len == 0 or sid.len == 0 or to.len == 0) return null;
    return std.fmt.bufPrint(out, "{{\"op\":\"switch_ai\",\"id\":{d},\"host\":{d},\"provider\":\"{s}\",\"sid\":\"{s}\",\"to\":\"{s}\"}}", .{ id, host, provider, sid, to }) catch null;
}

test "IGSH-2280 a switch reply replaces the shell provider and sid" {
    const old = "11111111-2222-4333-8444-555555555555";
    const bare = "{\"status\":\"switched\",\"provider\":\"pi\",\"sid\":\"aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee\",\"tmux\":\"same-chat\",\"start\":\"started\"}";
    var sid_buf: [40]u8 = undefined;
    const adopted = adoptedSwitch(std.testing.allocator, bare, &sid_buf) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u8, 3), adopted.agent);
    var agent: u8 = 1;
    var shell_sid: [40]u8 = std.mem.zeroes([40]u8);
    @memcpy(shell_sid[0..old.len], old);
    var shell_sid_len: u32 = @intCast(old.len);
    try std.testing.expect(adoptShellAgent(&agent, &shell_sid, &shell_sid_len, adopted.agent, sid_buf[0..adopted.sid_len]));
    try std.testing.expect(switchAiVisible(agent, 1));
    try std.testing.expect(!switchAiVisible(agent, 3));
    try std.testing.expect(!switchAiVisible(1, 1));
    var buf: [256]u8 = undefined;
    const request = switchAiRequest(&buf, blk: {
        var key = @import("chat_transcript.zig").Identity.init(4, 0, false, shell_sid[0..shell_sid_len], "");
        key.agent = agent;
        break :blk key.checked().?;
    }, "claude") orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, request, "\"provider\":\"pi\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, request, "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee") != null);
    try std.testing.expect(std.mem.indexOf(u8, request, old) == null);
    const wrapped = "{\"id\":4,\"message_protocol\":1,\"result\":{\"status\":\"switched\",\"provider\":\"codex\",\"sid\":\"bbbbbbbb-cccc-4ddd-8eee-ffffffffffff\"}}";
    const again = adoptedSwitch(std.testing.allocator, wrapped, &sid_buf) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u8, 2), again.agent);
    try std.testing.expectEqualStrings("bbbbbbbb-cccc-4ddd-8eee-ffffffffffff", sid_buf[0..again.sid_len]);
    try std.testing.expect(adoptedSwitch(std.testing.allocator, "{\"status\":\"busy\",\"reason\":\"chat_busy\"}", &sid_buf) == null);
}
