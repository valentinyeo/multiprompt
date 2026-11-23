const day: u64 = 500_000;
const fixture = [_]overview.Row{
    .{ .shell_id = 1, .kind = .archived, .host = 0, .workspace = 1, .last_active = day + 10, .ram_mb = 800 },
    .{ .shell_id = 2, .kind = .open, .host = 1, .workspace = 1, .last_active = day + 30, .favorite = true },
    .{ .shell_id = 3, .kind = .hidden, .host = 0, .workspace = 0, .last_active = day - 1, .frequent = true },
    .{ .shell_id = 4, .kind = .open, .host = 0, .workspace = 0, .last_active = day - 100, .attention = true },
    .{ .shell_id = 5, .kind = .vps_only, .host = 1, .workspace = 255, .last_active = day + 20, .ram_mb = 399 },
    .{ .shell_id = 6, .kind = .reminder, .host = 0, .workspace = 0, .last_active = 0, .ram_mb = 400 },
    .{ .shell_id = 7, .kind = .open, .host = 1, .workspace = 0, .last_active = day, .attention = true, .favorite = true, .frequent = true },
};

test "SOFT-2445 waiting first, Today by recency, then earlier" {
    var rows = fixture;
    std.mem.sort(overview.Row, &rows, day, overview.less);
    const expected = [_]u32{ 7, 4, 2, 5, 1, 3, 6 };
    for (rows, expected) |row, id| try std.testing.expectEqual(id, row.shell_id);
    try std.testing.expectEqual(overview.Group.today, overview.group(fixture[1], day));
    try std.testing.expectEqual(overview.Group.earlier, overview.group(fixture[2], day));
    try std.testing.expectEqual(overview.Group.earlier, overview.group(fixture[5], day));
}

test "SOFT-2445 run states are independent of waiting and hiding" {
    const expected = [_]overview.RunState{ .archived, .running, .running, .running, .no_window, .no_window, .running };
    for (fixture, expected) |row, state| try std.testing.expectEqual(state, overview.runState(row));
    try std.testing.expectEqualStrings("Running", overview.stateLabel(.running));
    try std.testing.expectEqualStrings("No window", overview.stateLabel(.no_window));
    try std.testing.expectEqualStrings("Archived", overview.stateLabel(.archived));
}

test "SOFT-2445 counts and server buttons describe disjoint states" {
    try std.testing.expectEqual(@as(u32, 7), overview.count(&fixture, .{}));
    try std.testing.expectEqual(@as(u32, 4), overview.count(&fixture, .{ .state = .running }));
    try std.testing.expectEqual(@as(u32, 2), overview.count(&fixture, .{ .state = .no_window }));
    try std.testing.expectEqual(@as(u32, 1), overview.count(&fixture, .{ .state = .archived }));
    try std.testing.expectEqual(@as(u32, 2), overview.serverCount(&fixture));
    for ([_]u8{ 0, 1 }) |host| try std.testing.expectEqual(@as(u32, 2), overview.count(&fixture, .{ .host = host, .state = .running }));
    try std.testing.expectEqual(@as(u32, 0), overview.count(&fixture, .{ .host = 2 }));
    try std.testing.expectEqual(@as(u32, 0), overview.serverCount(&.{fixture[0]}));
    try std.testing.expectEqual(@as(u32, 0), overview.count(&.{}, .{}));
}

test "SOFT-2445 server, run state and workspace filters compose" {
    try std.testing.expectEqual(@as(u32, 1), overview.count(&fixture, .{ .host = 1, .state = .running, .tab = 1 }));
    try std.testing.expectEqual(@as(u32, 0), overview.count(&fixture, .{ .host = 0, .state = .running, .tab = 1 }));
    try std.testing.expectEqual(@as(u32, 1), overview.count(&fixture, .{ .state = .no_window, .tab = 201 }));
    try std.testing.expectEqual(@as(u32, 2), overview.count(&fixture, .{ .tab = 202 }));
    try std.testing.expectEqual(@as(u32, 1), overview.count(&fixture, .{ .tab = 203 }));
    try std.testing.expectEqual(@as(u32, 2), overview.count(&fixture, .{ .tab = 204 }));
    try std.testing.expectEqual(@as(u32, 2), overview.count(&fixture, .{ .tab = 205 }));
    try std.testing.expectEqual(@as(u32, 1), overview.count(&fixture, .{ .host = 0, .tab = 204 }));
    try std.testing.expectEqual(@as(u32, 0), overview.count(&fixture, .{ .state = .no_window, .tab = 205 }));
}

test "SOFT-2445 repeated inventory and archive records count once per server identity" {
    var rows = [_]overview.Row{
        .{ .kind = .archived, .host = 0 },
        .{ .kind = .reminder, .host = 0 },
        .{ .kind = .hidden, .host = 0 },
        .{ .kind = .vps_only, .host = 1 },
    };
    for (&rows) |*row| {
        @memcpy(row.session[0..4], "same");
        row.session_len = 4;
    }
    const len = overview.deduplicate(&rows);
    try std.testing.expectEqual(@as(usize, 2), len);
    try std.testing.expectEqual(@as(u32, 1), overview.count(rows[0..len], .{ .state = .running }));
    try std.testing.expectEqual(@as(u32, 1), overview.count(rows[0..len], .{ .state = .no_window }));
    try std.testing.expectEqual(@as(u32, 0), overview.count(rows[0..len], .{ .state = .archived }));
}

test "SOFT-2445 memory appears only at 400 MB or more, never for archived rows" {
    try std.testing.expect(!overview.highMemory(fixture[0]));
    try std.testing.expect(!overview.highMemory(fixture[4]));
    try std.testing.expect(overview.highMemory(fixture[5]));
    try std.testing.expect(!overview.highMemory(fixture[1]));
}
