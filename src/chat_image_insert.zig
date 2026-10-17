const std = @import("std");

pub const Insertion = struct {
    start: usize,
    end: usize,
    len: usize,
    caret: usize,
};

pub fn plan(current: []const u16, selection_start: usize, selection_end: usize, reference: []const u16, out: []u16) ?Insertion {
    const start = @min(@min(selection_start, selection_end), current.len);
    var end = @min(@max(selection_start, selection_end), current.len);
    const ref = std.mem.trimEnd(u16, reference, &.{' '});
    if (ref.len == 0) return null;
    const lead: usize = if (start > 0 and !whitespace(current[start - 1])) 1 else 0;
    const len = lead + ref.len + 1;
    if (out.len <= len) return null;
    while (end < current.len and current[end] == ' ') : (end += 1) {}
    if (lead != 0) out[0] = ' ';
    @memcpy(out[lead .. lead + ref.len], ref);
    out[len - 1] = ' ';
    out[len] = 0;
    return .{ .start = start, .end = end, .len = len, .caret = start + len };
}

fn whitespace(c: u16) bool {
    return c == ' ' or c == '\t' or c == '\r' or c == '\n';
}

fn verify(current: []const u16, start: usize, end: usize, reference: []const u16, expected: []const u16, caret: usize) !void {
    var replacement: [256]u16 = undefined;
    const insert = plan(current, start, end, reference, &replacement) orelse return error.NoInsertion;
    var result: [512]u16 = undefined;
    @memcpy(result[0..insert.start], current[0..insert.start]);
    @memcpy(result[insert.start .. insert.start + insert.len], replacement[0..insert.len]);
    const tail = current[insert.end..];
    @memcpy(result[insert.caret .. insert.caret + tail.len], tail);
    try std.testing.expectEqualSlices(u16, expected, result[0 .. insert.caret + tail.len]);
    try std.testing.expectEqual(caret, insert.caret);
    try std.testing.expectEqual(@as(u16, ' '), result[insert.caret - 1]);
    try std.testing.expectEqual(@as(u16, 0), replacement[insert.len]);
}

const w = std.unicode.utf8ToUtf16LeStringLiteral;

test "empty composer and end insertion leave caret after exactly one space" {
    try verify(w(""), 0, 0, w("shot.png"), w("shot.png "), 9);
    try verify(w("look"), 4, 4, w("shot.png"), w("look shot.png "), 14);
    try verify(w("look "), 5, 5, w("shot.png "), w("look shot.png "), 14);
}

test "middle insertion consumes an existing separator, including repeated spaces" {
    try verify(w("look here"), 4, 4, w("shot.png"), w("look shot.png here"), 14);
    try verify(w("look   here"), 4, 4, w("shot.png  "), w("look shot.png here"), 14);
    try verify(w("here"), 0, 0, w("shot.png"), w("shot.png here"), 9);
}

test "selection replacement, reversed and out-of-range selection preserve caret" {
    try verify(w("look old here"), 5, 8, w("shot.png"), w("look shot.png here"), 14);
    try verify(w("look old here"), 8, 5, w("shot.png"), w("look shot.png here"), 14);
    try verify(w("old"), 0, 99, w("shot.png"), w("shot.png "), 9);
    try verify(w("old"), 99, 99, w("shot.png"), w("old shot.png "), 13);
}

test "whitespace and UTF-16 code units do not glue the image to adjacent text" {
    try verify(w("a\n"), 2, 2, w("shot.png"), w("a\nshot.png "), 11);
    try verify(w("a\t"), 2, 2, w("shot.png"), w("a\tshot.png "), 11);
    try verify(w("🖼"), 2, 2, w("shot.png"), w("🖼 shot.png "), 12);
    try verify(w("\r\nnext"), 0, 0, w("shot.png"), w("shot.png \r\nnext"), 9);
}

test "empty references and insufficient buffers fail without a truncated image URL" {
    var out: [16]u16 = @splat(42);
    try std.testing.expect(plan(w(""), 0, 0, w(""), &out) == null);
    try std.testing.expect(plan(w(""), 0, 0, w("   "), &out) == null);
    try std.testing.expect(plan(w(""), 0, 0, w("shot.png"), out[0..9]) == null);
    try std.testing.expectEqual(@as(u16, 42), out[0]);
    try std.testing.expect(plan(w(""), 0, 0, w("shot.png"), out[0..10]) != null);
}

test "consecutive screenshot URLs leave each caret immediately after its single trailing space" {
    const first = w("https://example.invalid/first ");
    const next = w("https://example.invalid/second");
    const expected = w("https://example.invalid/first https://example.invalid/second ");
    try verify(first, first.len, first.len, next, expected, expected.len);
    const selected = w("note replace   suffix");
    const replaced = w("note https://example.invalid/second suffix");
    try verify(selected, 5, 12, next, replaced, 5 + next.len + 1);
}
