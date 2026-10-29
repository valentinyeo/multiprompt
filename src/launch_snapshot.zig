const std = @import("std");
const markdown = @import("chat_markdown.zig");

pub const MAX_BYTES = 1024 * 1024;
pub const Row = struct {
    id: u32,
    chat_id: u64 = 0,
    last_read_message_id: u64 = 0,
    name: []const u16,
    tmux_session: []const u8 = "",
    kind: u8 = 0,
    workspace: u8 = 0,
    group_id: u32 = 0,
    starred_group_id: u32 = 0,
    agent: u8 = 0,
    pinned: bool = false,
    starred_pinned_top: bool = false,
    favorite: bool = false,
    muted: bool = false,
    unread: bool = false,
    last_active: u64 = 0,
    last_viewed: u64 = 0,
    browser: bool = false,
    browser_split: u16 = 350,
};
pub const Group = struct { id: u32, name: []const u16, collapsed: bool = false, color: u8 = 0 };
pub const Snapshot = struct {
    version: u32 = 1,
    active: u32,
    workspace: u8 = 0,
    starred: bool = false,
    workspaces: []const []const u8 = &.{},
    workspace_colors: []const ?u8 = &.{},
    groups: []const Group = &.{},
    rows: []const Row,
    chat: bool = false,
    clean_chat: bool = false,
    text: []const u16 = &.{},
    blocks: []const markdown.Block = &.{},
    font: i32 = 14,
    sidebar_width: i32 = 240,
    single_window: bool = true,
    sort_auto: bool = true,
    sidebar_collapsed: bool = false,
    sidebar_scroll: i32 = 0,
};

pub fn encode(a: std.mem.Allocator, snapshot: Snapshot) ![]u8 {
    if (!valid(snapshot)) return error.InvalidSnapshot;
    const bytes = try std.json.Stringify.valueAlloc(a, snapshot, .{});
    if (bytes.len > MAX_BYTES) {
        a.free(bytes);
        return error.SnapshotTooLarge;
    }
    return bytes;
}
pub fn decode(a: std.mem.Allocator, bytes: ?[]const u8) !?std.json.Parsed(Snapshot) {
    const input = bytes orelse return null;
    if (input.len == 0 or input.len > MAX_BYTES) return null;
    const parsed = std.json.parseFromSlice(Snapshot, a, input, .{ .allocate = .alloc_always }) catch return null;
    if (!valid(parsed.value)) {
        parsed.deinit();
        return null;
    }
    return parsed;
}

fn valid(s: Snapshot) bool {
    if (s.version != 1 or s.rows.len == 0 or s.rows.len > 256 or s.workspace >= 9 or s.workspaces.len > 9 or s.groups.len > 64 or s.text.len > 32768 or s.blocks.len > 256 or s.font < 10 or s.font > 28 or s.sidebar_width < 100 or s.sidebar_width > 1000) return false;
    var active = false;
    for (s.rows, 0..) |row, i| {
        if (row.id == 0 or row.name.len > 63 or row.tmux_session.len > 63 or row.kind > 6 or row.workspace >= 9 or row.browser_split > 1000) return false;
        for (s.rows[0..i]) |previous| if (previous.id == row.id) return false;
        if (row.id == s.active) active = true;
    }
    for (s.groups) |group| if (group.name.len > 63 or group.color >= 8) return false;
    for (s.workspaces) |name| if (name.len > 31) return false;
    if (s.workspace_colors.len != 0 and s.workspace_colors.len != s.workspaces.len) return false;
    for (s.workspace_colors) |color| if (color != null and color.? >= 7) return false;
    for (s.blocks) |block| {
        if (block.kind != .list and block.level > 6) return false;
        if (block.start > s.text.len or block.len > s.text.len - block.start or block.prefix > block.len or block.detail_start > s.text.len or block.detail_len > s.text.len - block.detail_start or block.diff_start > s.text.len or block.diff_len > s.text.len - block.diff_start) return false;
    }
    return active;
}

test "ISSUE-502 active session rendered chat blocks and sidebar round trip" {
    const a = std.testing.allocator;
    const text = [_]u16{ 'H', 'i', 0x2603 };
    const rows = [_]Row{.{ .id = 42, .chat_id = 99, .name = &text, .kind = 3, .unread = true }};
    const blocks = [_]markdown.Block{.{ .start = 0, .len = text.len, .role = .prose, .markdown = true }};
    const bytes = try encode(a, .{ .active = 42, .rows = &rows, .text = &text, .blocks = &blocks, .chat = true });
    defer a.free(bytes);
    const parsed = (try decode(a, bytes)) orelse return error.TestUnexpectedResult;
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u32, 42), parsed.value.active);
    try std.testing.expectEqual(@as(u64, 99), parsed.value.rows[0].chat_id);
    try std.testing.expectEqualSlices(u16, &text, parsed.value.text);
    try std.testing.expectEqual(markdown.Role.prose, parsed.value.blocks[0].role);
    try std.testing.expect(parsed.value.rows[0].unread);
}

test "ISSUE-502 missing corrupt and out of range snapshot safely fall back" {
    const a = std.testing.allocator;
    for ([_]?[]const u8{ null, "", "{", "{}", "{\"version\":2,\"active\":0,\"rows\":[]}", "{\"active\":42,\"rows\":[]}" }) |bytes| {
        try std.testing.expect((try decode(a, bytes)) == null);
    }
}

test "ISSUE-502 snapshot rejects invalid row identities and unsafe block ranges" {
    const a = std.testing.allocator;
    const invalid = [_][]const u8{
        "{\"active\":1,\"rows\":[{\"id\":1,\"name\":[],\"kind\":7}]}",
        "{\"active\":1,\"rows\":[{\"id\":1,\"name\":[],\"workspace\":9}]}",
        "{\"active\":1,\"rows\":[{\"id\":1,\"name\":[]},{\"id\":1,\"name\":[]}]}",
        "{\"active\":1,\"rows\":[{\"id\":1,\"name\":[]}],\"blocks\":[{\"start\":1,\"len\":1,\"role\":\"prose\"}]}",
        "{\"active\":1,\"rows\":[{\"id\":1,\"name\":[]}],\"blocks\":[{\"start\":0,\"len\":0,\"role\":\"tool\",\"detail_len\":1}]}",
        "{\"active\":1,\"rows\":[{\"id\":1,\"name\":[]}],\"blocks\":[{\"start\":0,\"len\":0,\"role\":\"prose\",\"kind\":\"heading\",\"level\":7}]}",
        "{\"active\":1,\"rows\":[{\"id\":1,\"name\":[]}],\"blocks\":[{\"start\":0,\"len\":0,\"role\":\"prose\",\"level\":255}]}",
    };
    for (invalid) |bytes| try std.testing.expect((try decode(a, bytes)) == null);
    const oversized = try a.alloc(u8, MAX_BYTES + 1);
    defer a.free(oversized);
    @memset(oversized, ' ');
    try std.testing.expect((try decode(a, oversized)) == null);
}

test "IGSH-556 launch snapshot preserves both memberships with legacy defaults" {
    const a = std.testing.allocator;
    const bytes = try encode(a, .{ .active = 1, .rows = &.{.{ .id = 1, .name = &.{ 'C', 'M', 'D' }, .group_id = 17, .starred_group_id = 29, .starred_pinned_top = true }} });
    defer a.free(bytes);
    const restored = (try decode(a, bytes)).?;
    defer restored.deinit();
    try std.testing.expectEqual(@as(u32, 17), restored.value.rows[0].group_id);
    try std.testing.expectEqual(@as(u32, 29), restored.value.rows[0].starred_group_id);
    try std.testing.expect(restored.value.rows[0].starred_pinned_top);
    try std.testing.expect(!restored.value.rows[0].pinned);
    const legacy = (try decode(a, "{\"active\":1,\"rows\":[{\"id\":1,\"name\":[67],\"group_id\":17}]}")).?;
    defer legacy.deinit();
    try std.testing.expectEqual(@as(u32, 0), legacy.value.rows[0].starred_group_id);
    try std.testing.expect(!legacy.value.rows[0].starred_pinned_top);
}

test "ISSUE-569 launch snapshot round trips the Starred selection pair" {
    const a = std.testing.allocator;
    for ([_]bool{ false, true }) |starred| {
        const bytes = try encode(a, .{ .active = 42, .workspace = 0, .starred = starred, .rows = &.{.{ .id = 42, .workspace = 1, .favorite = true, .name = &.{'B'} }} });
        defer a.free(bytes);
        const parsed = (try decode(a, bytes)).?;
        defer parsed.deinit();
        try std.testing.expectEqual(starred, parsed.value.starred);
        try std.testing.expectEqual(@as(u32, 42), parsed.value.active);
        try std.testing.expectEqual(@as(u8, 0), parsed.value.workspace);
        try std.testing.expectEqual(@as(u8, 1), parsed.value.rows[0].workspace);
    }
}

test "ISSUE-569 legacy launch snapshot without Starred decodes as false" {
    const parsed = (try decode(std.testing.allocator, "{\"active\":42,\"workspace\":0,\"rows\":[{\"id\":42,\"workspace\":1,\"favorite\":true,\"name\":[66]}]}")).?;
    defer parsed.deinit();
    try std.testing.expect(!parsed.value.starred);
    try std.testing.expectEqual(@as(u32, 42), parsed.value.active);
    try std.testing.expect(parsed.value.rows[0].favorite);
}

test "IGSH-816 CLEAN launch snapshot round trips both modes and legacy defaults off" {
    const a = std.testing.allocator;
    const rows = [_]Row{.{ .id = 1, .name = &.{} }};
    for ([_]bool{ false, true }) |clean| {
        const bytes = try encode(a, .{ .active = 1, .rows = &rows, .clean_chat = clean });
        defer a.free(bytes);
        const parsed = (try decode(a, bytes)) orelse return error.TestUnexpectedResult;
        defer parsed.deinit();
        try std.testing.expectEqual(clean, parsed.value.clean_chat);
    }
    const legacy = (try decode(a, "{\"active\":1,\"rows\":[{\"id\":1,\"name\":[]}]}")) orelse return error.TestUnexpectedResult;
    defer legacy.deinit();
    try std.testing.expect(!legacy.value.clean_chat);
}

test "IGSH-814 launch snapshot preserves the saved read anchor per chat" {
    const a = std.testing.allocator;
    const rows = [_]Row{
        .{ .id = 1, .name = &.{}, .last_read_message_id = std.math.maxInt(u64) },
        .{ .id = 2, .name = &.{}, .last_read_message_id = 42 },
    };
    const bytes = try encode(a, .{ .active = 1, .rows = &rows });
    defer a.free(bytes);
    const parsed = (try decode(a, bytes)).?;
    defer parsed.deinit();
    try std.testing.expectEqual(std.math.maxInt(u64), parsed.value.rows[0].last_read_message_id);
    try std.testing.expectEqual(@as(u64, 42), parsed.value.rows[1].last_read_message_id);
    const legacy = (try decode(a, "{\"active\":1,\"rows\":[{\"id\":1,\"name\":[]}]}")).?;
    defer legacy.deinit();
    try std.testing.expectEqual(@as(u64, 0), legacy.value.rows[0].last_read_message_id);
}

test "IGSH-925 launch snapshot carries the browser pane split and legacy decodes to the default" {
    const a = std.testing.allocator;
    const rows = [_]Row{
        .{ .id = 1, .name = &.{}, .browser = true, .browser_split = 420 },
        .{ .id = 2, .name = &.{} },
    };
    const bytes = try encode(a, .{ .active = 1, .rows = &rows });
    defer a.free(bytes);
    const parsed = (try decode(a, bytes)).?;
    defer parsed.deinit();
    try std.testing.expect(parsed.value.rows[0].browser);
    try std.testing.expectEqual(@as(u16, 420), parsed.value.rows[0].browser_split);
    try std.testing.expect(!parsed.value.rows[1].browser);
    const legacy = (try decode(a, "{\"active\":1,\"rows\":[{\"id\":1,\"name\":[]}]}")).?;
    defer legacy.deinit();
    try std.testing.expect(!legacy.value.rows[0].browser);
    try std.testing.expectEqual(@as(u16, 350), legacy.value.rows[0].browser_split);
    try std.testing.expect((try decode(a, "{\"active\":1,\"rows\":[{\"id\":1,\"name\":[],\"browser_split\":1001}]}")) == null);
}

test "IGSH-1172 launch cache preserves colors and raw face identity" {
    const a = std.testing.allocator;
    const bytes = try encode(a, .{
        .active = 1,
        .rows = &.{.{ .id = 1, .name = &.{'X'}, .tmux_session = "agent-one", .workspace = 1 }},
        .workspaces = &.{ "Cedar", "Orbit" },
        .workspace_colors = &.{ null, 6 },
    });
    defer a.free(bytes);
    const parsed = (try decode(a, bytes)).?;
    defer parsed.deinit();
    try std.testing.expectEqualStrings("agent-one", parsed.value.rows[0].tmux_session);
    try std.testing.expectEqualSlices(?u8, &.{ null, 6 }, parsed.value.workspace_colors);
    try std.testing.expectError(error.InvalidSnapshot, encode(a, .{
        .active = 1,
        .rows = &.{.{ .id = 1, .name = &.{'X'} }},
        .workspaces = &.{"Cedar"},
        .workspace_colors = &.{7},
    }));
}
