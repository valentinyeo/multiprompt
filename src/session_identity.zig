const std = @import("std");

pub const Host = enum(u8) {
    first,
    second,
    third,

    pub fn fromIndex(value: u8) ?Host {
        return std.enums.fromInt(Host, value);
    }

    pub fn index(self: Host) u8 {
        return @intFromEnum(self);
    }
};

pub const Session = struct {
    host: Host,
    owner: u32,
    sid: [40]u8,
    tmux: [64]u8,
    agent: enum { claude, codex, pi, hax, grok, cursor, antigravity },

    pub fn checked(key: anytype) ?Session {
        const host = Host.fromIndex(key.host) orelse return null;
        if (key.shell_id == 0 or (key.sid[0] == 0 and key.tmux[0] == 0)) return null;
        if (std.mem.indexOfScalar(u8, &key.sid, 0) == null or std.mem.indexOfScalar(u8, &key.tmux, 0) == null) return null;
        return .{
            .host = host,
            .owner = key.shell_id,
            .sid = key.sid,
            .tmux = key.tmux,
            .agent = std.meta.stringToEnum(@FieldType(Session, "agent"), key.provider()) orelse return null,
        };
    }

    pub fn fromShell(shell: anytype) ?Session {
        if (shell.shell_id == 0 or shell.claude_sid_len >= 40 or shell.tmux_session_len >= 64) return null;
        const host = switch (shell.kind) {
            .tmux => shell.tmux_host,
            .vps => 0,
            .vps2 => 1,
            else => return null,
        };
        var identity = remote(host, shell.tmux_session[0..shell.tmux_session_len], shell.claude_sid[0..shell.claude_sid_len], shell.ai_agent) orelse return null;
        identity.owner = shell.shell_id;
        identity.agent = switch (shell.ai_agent) {
            2 => .codex,
            3 => .pi,
            5 => .hax,
            6 => .grok,
            7 => .cursor,
            8 => .antigravity,
            else => .claude,
        };
        return identity;
    }

    pub fn remote(host_index: u8, tmux: []const u8, sid: []const u8, agent: u8) ?Session {
        const host = Host.fromIndex(host_index) orelse return null;
        if (tmux.len == 0 or tmux.len >= 64 or sid.len >= 40 or std.mem.indexOfScalar(u8, tmux, 0) != null or std.mem.indexOfScalar(u8, sid, 0) != null) return null;
        var identity = Session{ .host = host, .owner = 0, .sid = @splat(0), .tmux = @splat(0), .agent = switch (agent) {
            2 => .codex,
            3 => .pi,
            else => .claude,
        } };
        @memcpy(identity.tmux[0..tmux.len], tmux);
        @memcpy(identity.sid[0..sid.len], sid);
        return identity;
    }

    pub fn provider(self: Session) []const u8 {
        return @tagName(self.agent);
    }

    pub fn same(self: Session, other: Session) bool {
        return std.meta.eql(self, other);
    }

    pub fn requestId(self: Session, query: []const u8) ?u32 {
        const parsed = std.json.parseFromSlice(struct {
            id: u32,
            host: ?u8 = null,
            sid: ?[]const u8 = null,
            tmux: ?[]const u8 = null,
            provider: ?[]const u8 = null,
        }, std.heap.page_allocator, query, .{ .ignore_unknown_fields = true }) catch return null;
        defer parsed.deinit();
        const request = parsed.value;
        if (request.host) |host| if (host != self.host.index()) return null;
        if (request.sid) |sid| if (!std.mem.eql(u8, sid, std.mem.sliceTo(&self.sid, 0))) return null;
        if (request.tmux) |tmux| if (!std.mem.eql(u8, tmux, std.mem.sliceTo(&self.tmux, 0))) return null;
        if (request.provider) |name| if (!std.mem.eql(u8, name, self.provider())) return null;
        return request.id;
    }
};

test "SOFT-2525 checked sessions reject another host, session or provider before dispatch" {
    const Identity = struct {
        shell_id: u32 = 7,
        host: u8 = 1,
        sid: [40]u8 = @splat(0),
        tmux: [64]u8 = @splat(0),

        pub fn provider(_: @This()) []const u8 {
            return "claude";
        }
    };
    var key = Identity{};
    @memcpy(key.sid[0..8], "chat-one");
    @memcpy(key.tmux[0..8], "term-one");
    const session = Session.checked(key).?;
    try std.testing.expectEqual(Host.second, session.host);
    try std.testing.expectEqual(@as(u32, 7), session.owner);
    var other = session;
    other.host = .first;
    try std.testing.expect(!session.same(other));
    other = session;
    other.owner = 8;
    try std.testing.expect(!session.same(other));
    try std.testing.expectEqual(@as(?u32, 99), session.requestId("{\"id\":99,\"host\":1,\"sid\":\"chat-one\",\"tmux\":\"term-one\",\"provider\":\"claude\"}"));
    try std.testing.expect(session.requestId("{\"id\":99,\"host\":0,\"sid\":\"chat-one\"}") == null);
    try std.testing.expect(session.requestId("{\"id\":99,\"sid\":\"chat-two\"}") == null);
    try std.testing.expect(session.requestId("{\"id\":99,\"tmux\":\"term-two\"}") == null);
    try std.testing.expect(session.requestId("{\"id\":99,\"provider\":\"codex\"}") == null);
    try std.testing.expect(session.requestId("not json") == null);
    key.host = 3;
    try std.testing.expect(Session.checked(key) == null);
    key.host = 1;
    key.shell_id = 0;
    try std.testing.expect(Session.checked(key) == null);
    try std.testing.expect(Session.checked(Identity{}) == null);
}
