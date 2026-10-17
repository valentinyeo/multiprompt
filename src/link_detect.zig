const std = @import("std");

pub const Range = struct { start: usize, end: usize };

pub fn isUrlChar(c: u16) bool {
    if (c <= 0x20 or c == 0x7f or (c >= 0x2500 and c <= 0x259f)) return false;
    return switch (c) {
        '"', '\'', '<', '>', '`', '{', '}', '|', '\\', '^' => false,
        else => true,
    };
}

pub fn scheme(text: []const u16) bool {
    return std.mem.startsWith(u16, text, &[_]u16{ 'h', 't', 't', 'p', ':', '/', '/' }) or
        std.mem.startsWith(u16, text, &[_]u16{ 'h', 't', 't', 'p', 's', ':', '/', '/' }) or
        std.mem.startsWith(u16, text, &[_]u16{ 'w', 'w', 'w', '.' });
}

pub fn trimEnd(text: []const u16) usize {
    var end = text.len;
    while (end > 0) {
        const c = text[end - 1];
        if (c == '.' or c == ',' or c == ';' or c == ':' or c == '!' or c == '?') {
            end -= 1;
            continue;
        }
        if (c != ')' and c != ']' and c != '}') break;
        const opening: u16 = switch (c) {
            ')' => '(',
            ']' => '[',
            else => '{',
        };
        var balance: isize = 0;
        for (text[0..end]) |ch| {
            if (ch == opening) balance += 1;
            if (ch == c) balance -= 1;
        }
        if (balance >= 0) break;
        end -= 1;
    }
    return end;
}

pub fn next(text: []const u16, from: usize) ?Range {
    var i = from;
    while (i < text.len) : (i += 1) {
        if (!scheme(text[i..]) or (i > 0 and isUrlChar(text[i - 1]) and text[i - 1] != '(' and text[i - 1] != '[')) continue;
        var end = i;
        while (end < text.len and isUrlChar(text[end])) : (end += 1) {}
        end = i + trimEnd(text[i..end]);
        if (end > i + 8) return .{ .start = i, .end = end };
    }
    return null;
}

fn rowEnd(row: []const u16, width: usize) usize {
    var last = @min(row.len, width);
    while (last > 0 and row[last - 1] == ' ') : (last -= 1) {}
    if (last > 0 and (row[last - 1] == 0x2502 or row[last - 1] == '|')) {
        last -= 1;
        while (last > 0 and row[last - 1] == ' ') : (last -= 1) {}
    }
    return last;
}

pub fn rowEndsAtEdge(row: []const u16, width: usize) bool {
    const last = rowEnd(row, width);
    if (last == 0 or !isUrlChar(row[last - 1])) return false;
    if (last + 2 >= width) return true;
    for (row[last..@min(row.len, width)], last..) |c, i| {
        if (c == 0x2502 or c == '|') return i <= last + 2;
        if (c != ' ') break;
    }
    return false;
}

pub fn rowEndsNearEdge(rows: []const []const u16, width: usize, index: usize) bool {
    if (index >= rows.len) return false;
    const last = rowEnd(rows[index], width);
    if (last == 0 or !isUrlChar(rows[index][last - 1])) return false;
    if (rowEndsAtEdge(rows[index], width)) return true;
    var extent: usize = 0;
    for (index -| 3..@min(rows.len, index + 4)) |i| {
        if (i != index) extent = @max(extent, rowEnd(rows[i], width));
    }
    return extent > 0 and extent + 2 >= last and last + 2 >= extent;
}

fn matchingIndent(indent: usize, url_indent: usize) bool {
    return indent == 0 or indent == url_indent;
}

fn continuation(row: []const u16) ?Range {
    var start: usize = 0;
    while (start < row.len and row[start] == ' ') : (start += 1) {}
    var end = start;
    while (end < row.len and isUrlChar(row[end])) : (end += 1) {}
    if (end == start) return null;
    if (end < row.len and row[end] == ' ' and blk: {
        var j = end;
        while (j < row.len and row[j] == ' ') : (j += 1) {}
        break :blk j < row.len;
    }) return null;
    return .{ .start = start, .end = end };
}

pub fn continuationStart(row: []const u16) ?usize {
    return if (continuation(row)) |part| part.start else null;
}

pub fn endsWithUrl(row: []const u16) bool {
    var from: usize = 0;
    while (next(row, from)) |found| {
        if (found.end == row.len) return true;
        from = found.end;
    }
    return false;
}

pub fn at(rows: []const []const u16, width: usize, clicked_row: usize, col: usize, out: []u16) ?[]const u16 {
    if (clicked_row >= rows.len or col >= rows[clicked_row].len) return null;
    const row = rows[clicked_row];
    if (!isUrlChar(row[col])) return null;
    var start = col;
    while (start > 0 and isUrlChar(row[start - 1])) : (start -= 1) {}
    var end = col;
    while (end < row.len and isUrlChar(row[end])) : (end += 1) {}
    var first = clicked_row;
    var last = clicked_row;
    var begin = start;
    const finish = end;
    if (!scheme(row[start..end])) {
        while (first > 0 and first + 4 > clicked_row and rowEndsNearEdge(rows, width, first - 1)) {
            const current = continuation(rows[first]) orelse break;
            if (begin != current.start or end != current.end) break;
            const prev = rows[first - 1];
            const prev_end = rowEnd(prev, width);
            if (prev_end == 0 or !isUrlChar(prev[prev_end - 1])) break;
            var prev_begin = prev_end;
            while (prev_begin > 0 and isUrlChar(prev[prev_begin - 1])) : (prev_begin -= 1) {}
            if (!scheme(prev[prev_begin..prev_end])) {
                const prev_part = continuation(prev) orelse break;
                if (prev_part.start != prev_begin or prev_part.end != prev_end) break;
            }
            first -= 1;
            begin = prev_begin;
            end = prev_end;
            if (scheme(prev[begin..end])) break;
        }
    }
    if (!scheme(rows[first][begin..])) return null;
    const url_indent = begin;
    for (first + 1..clicked_row + 1) |i| {
        const part = continuation(rows[i]) orelse return null;
        if (!matchingIndent(part.start, url_indent)) return null;
    }
    var n: usize = 0;
    var r = first;
    while (r <= last and n < out.len) : (r += 1) {
        const part = if (r == first) rows[r][begin..(if (r == last) finish else rowEnd(rows[r], width))] else rows[r][(continuation(rows[r]) orelse return null).start..(if (r == last) finish else rowEnd(rows[r], width))];
        for (part) |c| {
            if (n == out.len) break;
            if (isUrlChar(c)) {
                out[n] = c;
                n += 1;
            } else if (c != ' ') break;
        }
    }
    while (last + 1 < rows.len and last - first < 3 and
        (if (last == clicked_row) finish == rowEnd(rows[last], width) else true) and
        rowEndsNearEdge(rows, width, last) and n < out.len)
    {
        const next_row = rows[last + 1];
        const part = continuation(next_row) orelse break;
        if (!matchingIndent(part.start, url_indent)) break;
        for (next_row[part.start..part.end]) |c| {
            if (n == out.len) break;
            out[n] = c;
            n += 1;
        }
        last += 1;
        if (part.end < next_row.len and next_row[part.end] != ' ') break;
    }
    n = trimEnd(out[0..n]);
    return if (n > 0) out[0..n] else null;
}

fn check(rows: []const []const u16, width: usize, row: usize, col: usize, expected: []const u8) !void {
    var out: [512]u16 = undefined;
    const url = at(rows, width, row, col, &out) orelse return error.NoUrl;
    try std.testing.expectEqual(expected.len, url.len);
    for (expected, url) |a, b| try std.testing.expectEqual(@as(u16, a), b);
}

test "single line and punctuation" {
    try check(&.{std.unicode.utf8ToUtf16LeStringLiteral("see https://example.com/path.")}, 32, 0, 15, "https://example.com/path");
    const text = std.unicode.utf8ToUtf16LeStringLiteral("https://example.com/a(b))");
    try std.testing.expectEqual(@as(usize, text.len - 1), (next(text, 0) orelse unreachable).end);
}

test "edge wrap and second row click" {
    const rows = [_][]const u16{ std.unicode.utf8ToUtf16LeStringLiteral("https://example.com/"), std.unicode.utf8ToUtf16LeStringLiteral("long-path") };
    try check(&rows, 20, 0, 10, "https://example.com/long-path");
    try check(&rows, 20, 1, 3, "https://example.com/long-path");
}

test "indented tmux continuation and unrelated prose" {
    const rows = [_][]const u16{ std.unicode.utf8ToUtf16LeStringLiteral("  https://example.com/"), std.unicode.utf8ToUtf16LeStringLiteral("  long-path"), std.unicode.utf8ToUtf16LeStringLiteral("not a continuation") };
    try check(&rows, 22, 1, 4, "https://example.com/long-path");
    var out: [512]u16 = undefined;
    try std.testing.expect(at(&rows, 20, 2, 2, &out) == null);
}

test "tmux pane edge and an unrelated next line" {
    const pane = [_][]const u16{ std.unicode.utf8ToUtf16LeStringLiteral("  https://example.com/│"), std.unicode.utf8ToUtf16LeStringLiteral("  long-path") };
    try check(&pane, 23, 1, 4, "https://example.com/long-path");
    const prose = [_][]const u16{ std.unicode.utf8ToUtf16LeStringLiteral("https://example.com/"), std.unicode.utf8ToUtf16LeStringLiteral("An unrelated sentence") };
    try check(&prose, 20, 0, 8, "https://example.com/");
}

test "Claude reply URL joins at the visible pane edge, not the buffer edge" {
    const rows = [_][]const u16{
        std.unicode.utf8ToUtf16LeStringLiteral("x" ** 81),
        std.unicode.utf8ToUtf16LeStringLiteral("  https://mail.google.com/mail/u/?authuser=reader1234@example.com#drafts/1a1016d1"),
        std.unicode.utf8ToUtf16LeStringLiteral("  9d0adccc"),
    };
    const full = "https://mail.google.com/mail/u/?authuser=reader1234@example.com#drafts/1a1016d19d0adccc";
    try std.testing.expect(!rowEndsAtEdge(rows[1], 120));
    try std.testing.expect(!rowEndsAtEdge(rows[1], 95));
    try std.testing.expect(rowEndsNearEdge(&rows, 95, 1));
    try check(&rows, 95, 1, 15, full);
    try check(&rows, 95, 2, 4, full);
    try check(&rows, 120, 1, 15, full);
}

test "visible right edge tolerates two empty cells and rejects nonmatching indent" {
    const rows = [_][]const u16{
        std.unicode.utf8ToUtf16LeStringLiteral("  https://example.com/longer-path"),
        std.unicode.utf8ToUtf16LeStringLiteral("  continuation"),
    };
    try check(&rows, rows[0].len + 2, 0, 10, "https://example.com/longer-pathcontinuation");
    const wrong_indent = [_][]const u16{ rows[0], std.unicode.utf8ToUtf16LeStringLiteral("    continuation") };
    try check(&wrong_indent, rows[0].len, 0, 10, "https://example.com/longer-path");
    var out: [512]u16 = undefined;
    try std.testing.expect(at(&wrong_indent, rows[0].len, 1, 6, &out) == null);
}

test "a link followed by prose does not consume the next line" {
    const rows = [_][]const u16{
        std.unicode.utf8ToUtf16LeStringLiteral("https://example.com/ at the edge"),
        std.unicode.utf8ToUtf16LeStringLiteral("continuation"),
    };
    try check(&rows, rows[0].len, 0, 10, "https://example.com/");
}

test "a click on the third wrapped row walks to the scheme" {
    const rows = [_][]const u16{
        std.unicode.utf8ToUtf16LeStringLiteral("https://example.com/"),
        std.unicode.utf8ToUtf16LeStringLiteral("abcdefghijklmnopqrst"),
        std.unicode.utf8ToUtf16LeStringLiteral("uvwxyz"),
    };
    try check(&rows, 20, 2, 2, "https://example.com/abcdefghijklmnopqrstuvwxyz");
}
