const std = @import("std");
const app_state = @import("app_state.zig");
const sidebar = @import("sidebar.zig");

test "IGSH-1890 group order by name moves known groups first and keeps the rest in place" {
    const saved_groups = app_state.groups;
    const saved_count = app_state.group_count;
    const saved_next = app_state.next_group_id;
    defer {
        app_state.groups = saved_groups;
        app_state.group_count = saved_count;
        app_state.next_group_id = saved_next;
    }
    app_state.group_count = 0;
    app_state.next_group_id = 1;
    const work = sidebar.createGroup(std.unicode.utf8ToUtf16LeStringLiteral("Work"));
    const home = sidebar.createGroup(std.unicode.utf8ToUtf16LeStringLiteral("Home"));
    const local = sidebar.createGroup(std.unicode.utf8ToUtf16LeStringLiteral("Local"));
    try std.testing.expect(sidebar.orderGroupsByName(&.{ "Local", "Missing", "Work" }));
    try std.testing.expectEqual(local, app_state.groups[0].id);
    try std.testing.expectEqual(work, app_state.groups[1].id);
    try std.testing.expectEqual(home, app_state.groups[2].id);
    try std.testing.expect(!sidebar.orderGroupsByName(&.{ "Local", "Work", "Home" }));
    try std.testing.expect(sidebar.orderGroupsByName(&.{ "Home", "Work", "Local" }));
    try std.testing.expectEqual(home, app_state.groups[0].id);
    try std.testing.expectEqual(local, app_state.groups[2].id);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const tabs = [_]@import("session_layout.zig").Tab{
        .{ .name = "a", .tmux_session = "a", .tmux_host = 0, .workspace = "W", .group = "Local" },
        .{ .name = "b", .tmux_session = "b", .tmux_host = 0, .workspace = "W", .group = "Home" },
        .{ .name = "c", .tmux_session = "c", .tmux_host = 0, .workspace = "W", .group = "" },
    };
    const names = (try sidebar.groupOrderFor(arena.allocator(), &tabs)).?;
    try std.testing.expectEqual(@as(usize, 2), names.len);
    try std.testing.expectEqualStrings("Home", names[0]);
    try std.testing.expectEqualStrings("Local", names[1]);
}

test "IGSH-1890 group order lists groups used only in the Favorites view" {
    const saved_groups = app_state.groups;
    const saved_count = app_state.group_count;
    const saved_next = app_state.next_group_id;
    defer {
        app_state.groups = saved_groups;
        app_state.group_count = saved_count;
        app_state.next_group_id = saved_next;
    }
    app_state.group_count = 0;
    app_state.next_group_id = 1;
    _ = sidebar.createGroup(std.unicode.utf8ToUtf16LeStringLiteral("Product"));
    _ = sidebar.createGroup(std.unicode.utf8ToUtf16LeStringLiteral("Hypertask"));
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const tabs = [_]@import("session_layout.zig").Tab{
        .{ .name = "a", .tmux_session = "a", .tmux_host = 0, .workspace = "W", .group = "Product" },
        .{ .name = "b", .tmux_session = "b", .tmux_host = 0, .workspace = "W", .group = "", .starred_group = "Hypertask" },
    };
    const names = (try sidebar.groupOrderFor(arena.allocator(), &tabs)).?;
    try std.testing.expectEqual(@as(usize, 2), names.len);
    try std.testing.expectEqualStrings("Product", names[0]);
    try std.testing.expectEqualStrings("Hypertask", names[1]);
}