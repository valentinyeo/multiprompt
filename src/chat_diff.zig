const std = @import("std");

pub const removed_dark: u32 = 0x0024204A;
pub const added_dark: u32 = 0x0028401C;
pub const removed_light: u32 = 0x00E2E2FF;
pub const added_light: u32 = 0x00E2F5DC;
pub const row_height: i32 = 20;
pub const Kind = enum { added, removed, context };

pub fn classify(line: []const u16) Kind {
    if (line.len == 0) return .context;
    return switch (line[0]) {
        '+' => .added,
        '-' => .removed,
        else => .context,
    };
}

pub fn lines(text: []const u16) std.mem.SplitIterator(u16, .scalar) {
    return std.mem.splitScalar(u16, text, '\n');
}

pub fn rowCount(text: []const u16, open: bool) usize {
    if (text.len == 0) return 0;
    const count = 1 + std.mem.count(u16, text, &.{'\n'});
    return if (open) count else @min(count, 6);
}

pub fn summaryLen(text: []const u16) usize {
    const at = std.mem.lastIndexOf(u16, text, &.{ ' ', '+' }) orelse return text.len;
    const counts = text[at + 2 ..];
    const minus = std.mem.indexOf(u16, counts, &.{ ' ', '-' }) orelse return text.len;
    if (minus == 0 or minus + 2 == counts.len) return text.len;
    for (counts[0..minus]) |c| if (c < '0' or c > '9') return text.len;
    for (counts[minus + 2 ..]) |c| if (c < '0' or c > '9') return text.len;
    return at;
}

test "diff lines preserve code and classify only the prefix" {
    var split = lines(std.unicode.utf8ToUtf16LeStringLiteral("-before\n+after\n context\n … 9 more lines"));
    try std.testing.expectEqual(Kind.removed, classify(split.next().?));
    try std.testing.expectEqual(Kind.added, classify(split.next().?));
    try std.testing.expectEqual(Kind.context, classify(split.next().?));
    try std.testing.expectEqual(Kind.context, classify(split.next().?));
    try std.testing.expect(split.next() == null);
    try std.testing.expectEqual(Kind.context, classify(&.{}));
}

test "folded and open diff geometry uses the same fixed rows" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("-a\n+b\n c\n+d\n-e\n f\n+g\n … 8 more lines");
    try std.testing.expectEqual(@as(usize, 6), rowCount(text, false));
    try std.testing.expectEqual(@as(usize, 8), rowCount(text, true));
    try std.testing.expectEqual(@as(usize, 1), rowCount(&.{'+'}, false));
    try std.testing.expectEqual(@as(usize, 0), rowCount(&.{}, true));
}

test "full counts replace the previous compact summary counts" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("Edited foo.zig +30 -25");
    try std.testing.expectEqual(@as(usize, 14), summaryLen(text));
    const plain = std.unicode.utf8ToUtf16LeStringLiteral("Edited file +name -test");
    try std.testing.expectEqual(plain.len, summaryLen(plain));
}
