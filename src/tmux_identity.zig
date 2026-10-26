const std = @import("std");

pub fn same(host_a: u8, session_a: []const u8, host_b: u8, session_b: []const u8) bool {
    return session_a.len > 0 and host_a == host_b and std.ascii.eqlIgnoreCase(session_a, session_b);
}

fn validIdentity(value: []const u8) bool {
    if (value.len == 0 or value.len > 63) return false;
    var parts = std.mem.splitScalar(u8, value, ':');
    const started = std.fmt.parseInt(u64, parts.next() orelse return false, 10) catch return false;
    const pid = std.fmt.parseInt(u32, parts.next() orelse return false, 10) catch return false;
    const session = parts.next() orelse return false;
    if (started == 0 or pid == 0 or session.len < 2 or session[0] != '$' or parts.next() != null) return false;
    _ = std.fmt.parseInt(u32, session[1..], 10) catch return false;
    for (value) |c| if (!std.ascii.isDigit(c) and c != ':' and c != '$') return false;
    return true;
}

pub fn fromProbe(output: []const u8, session: []const u8) ?[]const u8 {
    var found: ?[]const u8 = null;
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, "\r");
        if (!std.mem.startsWith(u8, line, "@@I ")) continue;
        const split = std.mem.indexOfScalar(u8, line[4..], '|') orelse continue;
        if (!std.mem.eql(u8, line[4 .. 4 + split], session)) continue;
        const value = line[5 + split ..];
        if (!validIdentity(value)) return null;
        if (found) |previous| if (!std.mem.eql(u8, previous, value)) return null;
        found = value;
    }
    return found;
}

fn quote(writer: *std.Io.Writer, value: []const u8) !void {
    try writer.writeByte('\'');
    for (value) |c| {
        if (c == '\'') try writer.writeAll("'\\''") else try writer.writeByte(c);
    }
    try writer.writeByte('\'');
}

pub fn attachCommand(buf: []u8, session: []const u8, identity: []const u8, create: bool) ![]const u8 {
    var writer = std.Io.Writer.fixed(buf);
    if (identity.len == 0) {
        try writer.writeAll(if (create) "tmux new-session -A -s " else "tmux attach -t ");
        var target: [66]u8 = undefined;
        try quote(&writer, if (create) session else try std.fmt.bufPrint(&target, "={s}", .{session}));
    } else {
        if (!validIdentity(identity)) return error.InvalidIdentity;
        var target: [66]u8 = undefined;
        var condition: [128]u8 = undefined;
        var check = std.Io.Writer.fixed(&condition);
        try check.writeAll("#{==:#{start_time}:#{pid}:#{session_id},");
        try check.writeAll(identity);
        try check.writeByte('}');
        try writer.writeAll("tmux if-shell -F -t ");
        try quote(&writer, try std.fmt.bufPrint(&target, "={s}:", .{session}));
        try writer.writeByte(' ');
        try quote(&writer, check.buffered());
        try writer.writeByte(' ');
        const session_id = identity[(std.mem.lastIndexOfScalar(u8, identity, ':') orelse unreachable) + 1 ..];
        var attach: [96]u8 = undefined;
        try quote(&writer, try std.fmt.bufPrint(&attach, "attach-session -t '{s}'", .{session_id}));
        try writer.writeByte(' ');
        try quote(&writer, "display-message -p 'Saved terminal session changed; refusing to attach.'");
    }
    return writer.buffered();
}

pub const Pane = struct {
    active: bool = false,
    visible: bool = false,
    last_viewed: u64 = 0,
};

pub fn prefer(candidate: Pane, current: Pane) bool {
    if (candidate.active != current.active) return candidate.active;
    if (candidate.visible != current.visible) return candidate.visible;
    return candidate.last_viewed > current.last_viewed;
}

pub fn restoreWinner(tabs: anytype, index: usize) usize {
    const tab = &tabs[index];
    var winner = index;
    for (tabs, 0..) |*other, i| {
        if (!same(tab.tmux_host, tab.tmux_session[0..tab.tmux_session_len], other.tmux_host, other.tmux_session[0..other.tmux_session_len])) continue;
        if (other.last_viewed > tabs[winner].last_viewed or
            (other.last_viewed == tabs[winner].last_viewed and i < winner)) winner = i;
    }
    return winner;
}

test "pane choice prefers active then visible then last viewed with stable ties" {
    try std.testing.expect(prefer(.{ .active = true }, .{ .visible = true, .last_viewed = 999 }));
    try std.testing.expect(!prefer(.{ .visible = true, .last_viewed = 999 }, .{ .active = true }));
    try std.testing.expect(prefer(.{ .visible = true }, .{ .last_viewed = 999 }));
    try std.testing.expect(prefer(.{ .last_viewed = 20 }, .{ .last_viewed = 10 }));
    try std.testing.expect(!prefer(.{ .last_viewed = 10 }, .{ .last_viewed = 10 }));
}

test "restore dedupe keeps newest full record and name, separating hosts and empty identities" {
    const Tab = struct {
        tmux_host: u8 = 0,
        tmux_session: []const u8 = "remote-3",
        tmux_session_len: usize = 8,
        last_viewed: u64 = 0,
        name: []const u8,
        pinned_top: bool = false,
    };
    var tabs = [_]Tab{
        .{ .name = "secondary Growth Bot", .last_viewed = 10 },
        .{ .name = "Meta Klaviyo Connection", .last_viewed = 30, .pinned_top = true },
        .{ .name = "other host", .tmux_host = 1 },
        .{ .name = "local", .tmux_session_len = 0 },
        .{ .name = "local 2", .tmux_session_len = 0 },
        .{ .name = "tie", .last_viewed = 30 },
    };
    var kept: usize = 0;
    for (&tabs, 0..) |_, i| {
        const winner = restoreWinner(&tabs, i);
        if (i == winner) kept += 1;
        if (i == 0 or i == 1 or i == 5) {
            try std.testing.expectEqual(@as(usize, 1), winner);
            try std.testing.expectEqualStrings("Meta Klaviyo Connection", tabs[winner].name);
            try std.testing.expect(tabs[winner].pinned_top);
        } else try std.testing.expectEqual(i, winner);
    }
    try std.testing.expectEqual(@as(usize, 4), kept);
}

test "open and adoption identity excludes empty sessions and other hosts" {
    try std.testing.expect(same(0, "remote-3", 0, "remote-3"));
    try std.testing.expect(!same(0, "remote-3", 1, "remote-3"));
    try std.testing.expect(!same(0, "remote-3", 0, "remote-3-2"));
    try std.testing.expect(!same(0, "", 0, ""));
}

test "IGSH-985 generation probe is exact, validated and not overwritten by a prefix" {
    const wire = "@@I remote-long|1700:123:$2\n@@I remote|1700:123:$7\n";
    try std.testing.expectEqualStrings("1700:123:$7", fromProbe(wire, "remote").?);
    try std.testing.expect(fromProbe(wire, "missing") == null);
    try std.testing.expect(fromProbe("@@I remote|bad;command\n", "remote") == null);
    try std.testing.expect(fromProbe("@@I remote|1700:123:$7\n@@I remote|1700:123:$8\n", "remote") == null);
}

test "IGSH-985 guarded attach checks generation and addresses immutable session ID in one server command" {
    var buf: [2048]u8 = undefined;
    const command = try attachCommand(&buf, "remote", "1700:123:$7", true);
    try std.testing.expect(std.mem.startsWith(u8, command, "tmux if-shell -F -t '=remote:' "));
    try std.testing.expect(std.mem.indexOf(u8, command, "#{==:#{start_time}:#{pid}:#{session_id},1700:123:$7}") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, "attach-session -t ") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, "new-session") == null);
    try std.testing.expect(std.mem.indexOf(u8, command, "refusing to attach") != null);
    try std.testing.expectError(error.InvalidIdentity, attachCommand(&buf, "remote", "bad", false));
}

test "IGSH-985 first attach is exact and shell metacharacters remain quoted" {
    var buf: [2048]u8 = undefined;
    try std.testing.expectEqualStrings("tmux attach -t '=remote'", try attachCommand(&buf, "remote", "", false));
    try std.testing.expectEqualStrings("tmux new-session -A -s 'remote'", try attachCommand(&buf, "remote", "", true));
    try std.testing.expectEqualStrings("tmux attach -t '=a'\\''b'", try attachCommand(&buf, "a'b", "", false));
}
