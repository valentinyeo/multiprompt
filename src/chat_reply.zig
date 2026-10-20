const std = @import("std");

fn whitespace(c: u21) bool {
    return switch (c) {
        0x09...0x0d, 0x1c...0x20, 0xa0, 0x1680, 0x2000...0x200a, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000 => true,
        else => false,
    };
}

fn trimEnd(text: []const u8) []const u8 {
    const view = std.unicode.Utf8View.init(text) catch return text;
    var it = view.iterator();
    var end: usize = 0;
    while (it.nextCodepoint()) |c| {
        if (!whitespace(c)) end = it.i;
    }
    return text[0..end];
}

fn nextLine(text: []const u8, pos: *usize) ?[]const u8 {
    if (pos.* > text.len) return null;
    const start = pos.*;
    var end = start;
    while (end < text.len and text[end] != '\r' and text[end] != '\n') : (end += 1) {}
    pos.* = end + 1;
    if (end < text.len and text[end] == '\r' and pos.* < text.len and text[pos.*] == '\n') pos.* += 1;
    return text[start..end];
}

pub fn quote(a: std.mem.Allocator, message: []const u8) ![]u8 {
    var pos: usize = 0;
    var first: ?usize = null;
    var last: usize = 0;
    while (true) {
        const start = pos;
        const line = nextLine(message, &pos) orelse break;
        if (trimEnd(line).len > 0) {
            if (first == null) first = start;
            last = start + line.len;
        }
    }
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    pos = first orelse return a.dupe(u8, "");
    var count: usize = 0;
    while (nextLine(message[0..last], &pos)) |line| {
        if (count > 0) try out.append(a, '\n');
        if (count == 10) {
            try out.appendSlice(a, "> …");
            break;
        }
        const trimmed = trimEnd(line);
        try out.appendSlice(a, if (trimmed.len == 0) ">" else "> ");
        try out.appendSlice(a, trimmed);
        count += 1;
    }
    return out.toOwnedSlice(a);
}

pub fn compose(a: std.mem.Allocator, quoted: ?[]const u8, message: []const u8) ![]u8 {
    const text = quoted orelse return a.dupe(u8, message);
    if (trimEnd(text).len == 0) return a.dupe(u8, message);
    if (trimEnd(message).len == 0) return a.dupe(u8, "");
    const quoted_text = try quote(a, text);
    defer a.free(quoted_text);
    return std.fmt.allocPrint(a, "{s}\n\n{s}", .{ quoted_text, message });
}

pub fn preview(a: std.mem.Allocator, message: []const u8) ![]u8 {
    var pos: usize = 0;
    var count: usize = 0;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    while (nextLine(message, &pos)) |line| {
        if (trimEnd(line).len == 0) continue;
        if (count > 0) try out.append(a, ' ');
        try out.appendSlice(a, line);
        count += 1;
        if (count == 2) break;
    }
    return out.toOwnedSlice(a);
}

test "Android ReplyQuote fixture" {
    const Case = struct { name: []const u8, quoted: ?[]const u8, reply: []const u8, expected: []const u8 };
    const a = std.testing.allocator;
    const parsed = try std.json.parseFromSlice([]Case, a, @embedFile("testdata/reply-quote-fixture.json"), .{});
    defer parsed.deinit();
    for (parsed.value) |case| {
        const result = try compose(a, case.quoted, case.reply);
        defer a.free(result);
        try std.testing.expectEqualStrings(case.expected, result);
    }
}

test "Android previews and Unicode whitespace with CR line endings" {
    const a = std.testing.allocator;
    for ([_][2][]const u8{
        .{ "\nFirst\n\nSecond\nThird", "First Second" },
        .{ "\n \n", "" },
        .{ "\r\n First \r\nSecond\rThird", " First  Second" },
        .{ "\u{a0}\n\u{2003}", "" },
    }) |case| {
        const result = try preview(a, case[0]);
        defer a.free(result);
        try std.testing.expectEqualStrings(case[1], result);
    }
    const result = try compose(a, "\r\u{2003}\rHello\t\u{a0}\rWorld\r", "yes");
    defer a.free(result);
    try std.testing.expectEqualStrings("> Hello\n> World\n\nyes", result);
}
