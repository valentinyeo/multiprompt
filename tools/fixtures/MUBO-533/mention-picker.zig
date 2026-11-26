const std = @import("std");
var inserted: [260]u16 = undefined;
var inserted_len: usize = 0;
var selected_start: usize = 0;
var selected_end: usize = 0;
const w = struct {
    fn SendMessageW(_: usize, msg: u32, wp: usize, lp: isize) isize {
        if (msg == 0x00b1) { selected_start = wp; selected_end = @intCast(lp); }
        if (msg == 0x00c2) {
            const value: [*:0]const u16 = @ptrFromInt(@as(usize, @bitCast(lp)));
            const text = std.mem.span(value);
            @memcpy(inserted[0..text.len], text);
            inserted_len = text.len;
        }
        return 0;
    }
};
const Member = struct { alias: []const u16, name: []const u16 };
const View = struct {
    model: struct { members: []const Member },
    composer: usize = 1,
    picker: bool = true,
    fn draft(_: *@This(), _: *[65537]u16) ?[]const u16 { return std.unicode.utf8ToUtf16LeStringLiteral("prefix @Res"); }
    fn invalidate(_: *@This()) void {}
    fn setFocus(_: *@This(), _: usize) void {}
};

test "the picker inserts the full shown name and preserves the preceding draft" {
    const L = std.unicode.utf8ToUtf16LeStringLiteral;
    var view = View{ .model = .{ .members = &.{.{ .alias = L("agent_123456"), .name = L("Research Notes") }} } };
    chooseMention(&view, 0);
    try std.testing.expectEqualSlices(u16, L("@Research Notes "), inserted[0..inserted_len]);
    try std.testing.expectEqual(@as(usize, 7), selected_start);
    try std.testing.expectEqual(@as(usize, 11), selected_end);
    try std.testing.expect(!view.picker);
}

test "the picker inserts spaces punctuation and Unicode without changing the member name" {
    const L = std.unicode.utf8ToUtf16LeStringLiteral;
    var view = View{ .model = .{ .members = &.{.{ .alias = L("agent_123456"), .name = L("Zoë / QA 東京!") }} } };
    chooseMention(&view, 0);
    try std.testing.expectEqualSlices(u16, L("@Zoë / QA 東京! "), inserted[0..inserted_len]);
    try std.testing.expectEqual(@as(usize, 7), selected_start);
    try std.testing.expectEqual(@as(usize, 11), selected_end);
    try std.testing.expect(!view.picker);
}
