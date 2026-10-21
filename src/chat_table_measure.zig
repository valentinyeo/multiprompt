const std = @import("std");
const md = @import("chat_markdown.zig");

pub fn Measurer(comptime Backend: type) type {
    return struct {
        backend: Backend,
        const Self = @This();

        pub fn deinit(_: *Self) void {}

        pub fn cell(self: *Self, text: []const u16, bold: bool) md.TableSize {
            const old = self.backend.select(self.backend.font(.{ .bold = bold }));
            defer _ = self.backend.select(old);
            var height = self.backend.lineHeight();
            var buf: [512]md.Span = undefined;
            const spans = if (text.len <= buf.len) buf[0..] else std.heap.page_allocator.alloc(md.Span, text.len) catch return .{ .width = self.backend.width(text), .height = height };
            defer if (text.len > buf.len) std.heap.page_allocator.free(spans);
            const n = md.inlineSpans(text, spans);
            var width: i32 = 0;
            for (spans[0..n]) |span| {
                var style = span.style;
                style.bold = style.bold or bold;
                _ = self.backend.select(self.backend.font(style));
                width += self.backend.width(text[span.text.start..span.text.end]);
                height = @max(height, self.backend.lineHeight());
            }
            return .{ .width = width, .height = height };
        }
    };
}

const CountingBackend = struct {
    pub const Font = u8;
    selected: Font = 99,
    selects: usize = 0,
    heights: usize = 0,
    widths: usize = 0,

    pub fn font(_: *CountingBackend, style: md.Style) Font {
        return @as(u8, @intFromBool(style.bold)) + 2 * @as(u8, @intFromBool(style.italic)) + 4 * @as(u8, @intFromBool(style.code));
    }

    pub fn select(self: *CountingBackend, value: Font) Font {
        const old = self.selected;
        self.selected = value;
        self.selects += 1;
        return old;
    }

    pub fn lineHeight(self: *CountingBackend) i32 {
        self.heights += 1;
        return 20 + @as(i32, self.selected);
    }

    pub fn width(self: *CountingBackend, text: []const u16) i32 {
        self.widths += 1;
        return @as(i32, @intCast(text.len)) * (8 + @as(i32, self.selected));
    }
};

test "IGSH-436 nine-cell table measures each font height once and keeps it selected" {
    const a = std.testing.allocator;
    var cache: md.TableCache = .{};
    defer cache.deinit(a);
    var measure = Measurer(CountingBackend){ .backend = .{} };
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| A | B | C |\n|---|---|---|\n| one | two | three |\n| four | five | six |");
    const table = try cache.layout(a, text, 0, .{ .view_w = 500, .font_pt = 13, .scale = 1024, .pad_x = 10, .pad_y = 6 }, &measure, Measurer(CountingBackend).cell);
    measure.deinit();
    try std.testing.expectEqual(@as(usize, 9), measure.backend.widths);
    try std.testing.expectEqual(@as(usize, 2), measure.backend.heights);
    try std.testing.expectEqual(@as(usize, 3), measure.backend.selects);
    try std.testing.expectEqual(@as(u8, 99), measure.backend.selected);
    try std.testing.expectEqualSlices(i32, &.{ 21, 20, 20 }, table.lines);
}
