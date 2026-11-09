const std = @import("std");

pub const Session = struct {
    id: u32,
    tmux: []const u8 = "",
    front: bool = false,
};

pub fn shellKey(id: u32, out: []u8) []const u8 {
    const prefix = "zss-";
    if (out.len < prefix.len + 10) return out[0..0];
    @memcpy(out[0..prefix.len], prefix);
    var value = id;
    var digits: [10]u8 = undefined;
    var count: usize = 0;
    if (value == 0) {
        digits[0] = '0';
        count = 1;
    } else {
        while (value > 0) {
            digits[count] = '0' + @as(u8, @intCast(value % 10));
            count += 1;
            value /= 10;
        }
    }
    var index: usize = 0;
    while (index < count) : (index += 1) out[prefix.len + index] = digits[count - 1 - index];
    return out[0 .. prefix.len + count];
}

fn shared(sessions: []const Session, tmux: []const u8) bool {
    if (tmux.len == 0) return false;
    var count: usize = 0;
    for (sessions) |session| {
        if (session.tmux.len == tmux.len and std.ascii.eqlIgnoreCase(session.tmux, tmux)) count += 1;
    }
    return count > 1;
}

pub fn name(sessions: []const Session, index: usize, out: []u8) []const u8 {
    const session = sessions[index];
    if (session.tmux.len > 0 and !shared(sessions, session.tmux)) {
        const len = @min(session.tmux.len, out.len);
        @memcpy(out[0..len], session.tmux[0..len]);
        return out[0..len];
    }
    return shellKey(session.id, out);
}

pub fn target(sessions: []const Session, token_raw: []const u8) ?usize {
    const token = std.mem.trim(u8, token_raw, " \t\r\n");
    if (token.len == 0) return null;
    var key_hit: ?usize = null;
    var tmux_count: usize = 0;
    var sole: ?usize = null;
    var front_hit: ?usize = null;
    for (sessions, 0..) |session, index| {
        var key_buf: [16]u8 = undefined;
        const key = shellKey(session.id, &key_buf);
        if (std.ascii.eqlIgnoreCase(key, token)) {
            if (key_hit != null) return null;
            key_hit = index;
        }
        if (session.tmux.len == 0 or !std.ascii.eqlIgnoreCase(session.tmux, token)) continue;
        tmux_count += 1;
        sole = index;
        if (session.front) {
            if (front_hit != null) return null;
            front_hit = index;
        }
    }
    if (key_hit) |index| return index;
    if (tmux_count == 1) return sole;
    if (tmux_count > 1) return front_hit;
    return null;
}

pub fn shown(sessions: []const Session) ?usize {
    var found: ?usize = null;
    for (sessions, 0..) |session, index| {
        if (!session.front) continue;
        if (found != null) return null;
        found = index;
    }
    return found;
}

test "IGSH-1199 sessions that share a browser name keep separate panes and the front session shows its own" {
    const sessions = [_]Session{
        .{ .id = 12, .tmux = "inne-cro", .front = true },
        .{ .id = 13, .tmux = "inne-cro", .front = false },
    };
    var front_name: [32]u8 = undefined;
    var back_name: [32]u8 = undefined;
    const front_pane = name(&sessions, 0, &front_name);
    const back_pane = name(&sessions, 1, &back_name);
    try std.testing.expectEqualStrings("zss-12", front_pane);
    try std.testing.expectEqualStrings("zss-13", back_pane);
    try std.testing.expect(!std.mem.eql(u8, front_pane, back_pane));
    try std.testing.expectEqual(@as(?usize, 0), target(&sessions, "zss-12"));
    try std.testing.expectEqual(@as(?usize, 1), target(&sessions, "zss-13"));
    try std.testing.expectEqual(@as(?usize, 0), target(&sessions, "inne-cro"));
    try std.testing.expect(target(&sessions, "zss-13") != shown(&sessions));
    try std.testing.expectEqual(shown(&sessions), target(&sessions, "inne-cro"));
}

test "IGSH-1199 a session with its own name never receives another session's pane" {
    const sessions = [_]Session{
        .{ .id = 12, .tmux = "inne-cro", .front = false },
        .{ .id = 13, .tmux = "inne-design", .front = true },
    };
    var chief: [32]u8 = undefined;
    var design: [32]u8 = undefined;
    try std.testing.expectEqualStrings("inne-cro", name(&sessions, 0, &chief));
    try std.testing.expectEqualStrings("inne-design", name(&sessions, 1, &design));
    try std.testing.expectEqual(@as(?usize, 0), target(&sessions, "inne-cro"));
    try std.testing.expectEqual(@as(?usize, 1), target(&sessions, "inne-design"));
    try std.testing.expectEqual(@as(?usize, 1), shown(&sessions));
    try std.testing.expect(target(&sessions, "inne-cro") != shown(&sessions));
}
