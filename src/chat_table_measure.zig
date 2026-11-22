const std = @import("std");
const md = @import("chat_markdown.zig");

pub fn Measurer(comptime Backend: type) type {
    return struct {
        pub const Metrics = struct {
            const Entry = struct { font: Backend.Font, height: i32 };
            entries: [8]Entry = undefined,
            count: usize = 0,
            font_pt: i32 = 0,
            scale: i32 = 0,

            pub fn invalidate(self: *Metrics, font_pt: i32, scale: i32) void {
                if (self.font_pt == font_pt and self.scale == scale) return;
                self.count = 0;
                self.font_pt = font_pt;
                self.scale = scale;
            }
        };

        backend: Backend,
        metrics: *Metrics,
        selected: ?Backend.Font = null,
        original: Backend.Font = undefined,
        const Self = @This();

        pub fn deinit(self: *Self) void {
            if (self.selected != null) _ = self.backend.select(self.original);
            self.selected = null;
        }

        fn select(self: *Self, font: Backend.Font) void {
            if (self.selected) |selected| {
                if (selected == font) return;
                _ = self.backend.select(font);
            } else {
                self.original = self.backend.select(font);
            }
            self.selected = font;
        }

        fn lineHeight(self: *Self, font: Backend.Font) i32 {
            for (self.metrics.entries[0..self.metrics.count]) |entry| {
                if (entry.font == font) return entry.height;
            }
            self.select(font);
            const height = self.backend.lineHeight();
            if (self.metrics.count < self.metrics.entries.len) {
                self.metrics.entries[self.metrics.count] = .{ .font = font, .height = height };
                self.metrics.count += 1;
            }
            return height;
        }

        pub fn cell(self: *Self, text: []const u16, bold: bool) md.TableSize {
            const base = self.backend.font(.{ .bold = bold });
            var height = self.lineHeight(base);
            var buf: [512]md.Span = undefined;
            const spans = if (text.len <= buf.len) buf[0..] else std.heap.page_allocator.alloc(md.Span, text.len) catch {
                self.select(base);
                return .{ .width = self.backend.width(text), .height = height };
            };
            defer if (text.len > buf.len) std.heap.page_allocator.free(spans);
            const n = md.inlineSpans(text, spans);
            var width: i32 = 0;
            for (spans[0..n]) |span| {
                var style = span.style;
                style.bold = style.bold or bold;
                const font = self.backend.font(style);
                height = @max(height, self.lineHeight(font));
                self.select(font);
                width += self.backend.width(text[span.text.start..span.text.end]);
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
    var metrics: Measurer(CountingBackend).Metrics = .{};
    var measure = Measurer(CountingBackend){ .backend = .{}, .metrics = &metrics };
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| A | B | C |\n|---|---|---|\n| one | two | three |\n| four | five | six |");
    const table = try cache.layout(a, text, 0, .{ .view_w = 500, .font_pt = 13, .scale = 1024, .pad_x = 10, .pad_y = 6 }, &measure, Measurer(CountingBackend).cell);
    measure.deinit();
    try std.testing.expectEqual(@as(usize, 9), measure.backend.widths);
    try std.testing.expectEqual(@as(usize, 2), measure.backend.heights);
    try std.testing.expectEqual(@as(usize, 3), measure.backend.selects);
    try std.testing.expectEqual(@as(u8, 99), measure.backend.selected);
    try std.testing.expectEqualSlices(i32, &.{ 21, 20, 20 }, table.lines);
}

test "IGSH-436 warm tables reuse metrics and font or DPI changes invalidate them" {
    const M = Measurer(CountingBackend);
    var metrics: M.Metrics = .{};
    metrics.invalidate(13, 1024);
    var first = M{ .backend = .{}, .metrics = &metrics };
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const size = first.cell(w("plain **bold** *italic* `code`"), false);
    first.deinit();
    try std.testing.expectEqual(@as(usize, 4), first.backend.heights);
    try std.testing.expectEqual(@as(i32, 24), size.height);
    var warm = M{ .backend = .{}, .metrics = &metrics };
    const same = warm.cell(w("plain **bold** *italic* `code`"), false);
    warm.deinit();
    try std.testing.expectEqual(@as(usize, 0), warm.backend.heights);
    try std.testing.expectEqual(size, same);
    metrics.invalidate(13, 1024);
    try std.testing.expectEqual(@as(usize, 4), metrics.count);
    metrics.invalidate(13, 1536);
    try std.testing.expectEqual(@as(usize, 0), metrics.count);
    var scaled = M{ .backend = .{}, .metrics = &metrics };
    _ = scaled.cell(w("plain"), false);
    scaled.deinit();
    try std.testing.expectEqual(@as(usize, 1), scaled.backend.heights);
    metrics.invalidate(14, 1536);
    try std.testing.expectEqual(@as(usize, 0), metrics.count);
    var header = M{ .backend = .{}, .metrics = &metrics };
    const code = header.cell(w("`code`"), true);
    const empty = header.cell(w(""), true);
    header.deinit();
    try std.testing.expectEqual(@as(i32, 25), code.height);
    try std.testing.expectEqual(@as(i32, 52), code.width);
    try std.testing.expectEqual(@as(i32, 21), empty.height);
    try std.testing.expectEqual(@as(i32, 0), empty.width);
    try std.testing.expectEqual(@as(u8, 99), header.backend.selected);
}
