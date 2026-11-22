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

pub const Reference = struct {
    quote_end: usize,
    body_start: usize,
    preview_start: usize,
    preview_end: usize,
};

pub fn reference(text: []const u16) ?Reference {
    var pos: usize = 0;
    var first: ?Reference = null;
    while (pos < text.len and text[pos] == '>') {
        var start = pos + 1;
        if (start < text.len and text[start] == ' ') start += 1;
        var end = start;
        while (end < text.len and text[end] != '\r' and text[end] != '\n') : (end += 1) {}
        if (first == null and end > start) first = .{ .quote_end = 0, .body_start = 0, .preview_start = start, .preview_end = end };
        pos = end;
        if (pos < text.len and text[pos] == '\r') pos += 1;
        if (pos < text.len and text[pos] == '\n') pos += 1;
    }
    var result = first orelse return null;
    result.quote_end = pos;
    while (pos < text.len and (text[pos] == '\r' or text[pos] == '\n')) : (pos += 1) {}
    if (pos == result.quote_end or pos == text.len) return null;
    result.body_start = pos;
    return result;
}

pub fn source(a: std.mem.Allocator, text: []const u16, ref: Reference) ![]u16 {
    var out: std.ArrayList(u16) = .empty;
    errdefer out.deinit(a);
    var pos: usize = 0;
    while (pos < ref.quote_end) {
        pos += 1;
        if (pos < ref.quote_end and text[pos] == ' ') pos += 1;
        const start = pos;
        while (pos < ref.quote_end and text[pos] != '\r' and text[pos] != '\n') : (pos += 1) {}
        const line = text[start..pos];
        if (!std.mem.eql(u16, line, &.{0x2026})) {
            if (out.items.len > 0) try out.append(a, '\n');
            try out.appendSlice(a, line);
        }
        if (pos < ref.quote_end and text[pos] == '\r') pos += 1;
        if (pos < ref.quote_end and text[pos] == '\n') pos += 1;
    }
    return out.toOwnedSlice(a);
}

pub fn sourceMatches(candidate: []const u16, quoted: []const u16) bool {
    var a: usize = 0;
    var b: usize = 0;
    while (a < candidate.len and whitespace(candidate[a])) : (a += 1) {}
    while (b < quoted.len and whitespace(quoted[b])) : (b += 1) {}
    if (b == quoted.len) return false;
    while (b < quoted.len) {
        if (whitespace(quoted[b])) {
            while (b < quoted.len and whitespace(quoted[b])) : (b += 1) {}
            if (b == quoted.len) break;
            if (a == candidate.len or !whitespace(candidate[a])) return false;
            while (a < candidate.len and whitespace(candidate[a])) : (a += 1) {}
        }
        if (a == candidate.len or candidate[a] != quoted[b]) return false;
        a += 1;
        b += 1;
    }
    return a == candidate.len or whitespace(candidate[a]);
}

test "IGSH-990 compact references preserve quoted wire text and locate original text" {
    const a = std.testing.allocator;
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const wire = w("> First line\r\n> second line\r\n>\r\n> fourth line\r\n\r\nMy answer");
    const ref = reference(wire) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, w("First line"), wire[ref.preview_start..ref.preview_end]);
    try std.testing.expectEqualSlices(u16, w("My answer"), wire[ref.body_start..]);
    const quoted = try source(a, wire, ref);
    defer a.free(quoted);
    try std.testing.expect(sourceMatches(w("First line\nsecond line\n\nfourth line"), quoted));
    try std.testing.expect(!sourceMatches(w("First line but different"), quoted));
    for ([_][]const u16{ w("ordinary reply"), w("> only a blockquote"), w("> quote\nnot a reply"), w("> quote\n\n") }) |text| try std.testing.expect(reference(text) == null);
    const nested = w("> > older quote\n> second\n\nanswer");
    const nested_ref = reference(nested).?;
    const nested_source = try source(a, nested, nested_ref);
    defer a.free(nested_source);
    try std.testing.expectEqualSlices(u16, w("> older quote\nsecond"), nested_source);
    const truncated = w("> Original first line\n> …\n\nAnswer");
    const truncated_source = try source(a, truncated, reference(truncated).?);
    defer a.free(truncated_source);
    try std.testing.expect(sourceMatches(w("Original first line\nmore original lines"), truncated_source));
}
