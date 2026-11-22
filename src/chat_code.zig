const std = @import("std");
const md = @import("chat_markdown.zig");

pub const Kind = enum { normal, keyword, string, number, comment };
pub const Token = struct { start: usize, end: usize, kind: Kind };
pub const Iterator = struct {
    text: []const u16,
    pos: usize = 0,

    pub fn next(self: *Iterator) ?Token {
        if (self.pos >= self.text.len) return null;
        const start = self.pos;
        const c = self.text[start];
        self.pos += 1;
        var kind: Kind = .normal;
        if (c == '#' or (c == '/' and self.pos < self.text.len and self.text[self.pos] == '/')) {
            kind = .comment;
            while (self.pos < self.text.len and self.text[self.pos] != '\n' and self.text[self.pos] != '\r') : (self.pos += 1) {}
        } else if (c == '/' and self.pos < self.text.len and self.text[self.pos] == '*') {
            kind = .comment;
            self.pos += 1;
            while (self.pos < self.text.len) : (self.pos += 1) {
                if (self.text[self.pos] == '*' and self.pos + 1 < self.text.len and self.text[self.pos + 1] == '/') {
                    self.pos += 2;
                    break;
                }
            }
        } else if (c == '"' or c == '\'' or c == '`') {
            kind = .string;
            while (self.pos < self.text.len) {
                const current = self.text[self.pos];
                self.pos += 1;
                if (current == '\\' and self.pos < self.text.len) self.pos += 1 else if (current == c) break;
            }
        } else if (c >= '0' and c <= '9') {
            kind = .number;
            while (self.pos < self.text.len and (word(self.text[self.pos]) or self.text[self.pos] == '.')) : (self.pos += 1) {}
        } else if (word(c)) {
            while (self.pos < self.text.len and word(self.text[self.pos])) : (self.pos += 1) {}
            const value = self.text[start..self.pos];
            const keywords = [_][]const u8{
                "const", "var",    "let",  "fn",     "function", "def",    "pub",   "return", "if",  "else",  "for",    "while", "try",    "catch",    "defer",
                "class", "struct", "enum", "import", "from",     "export", "async", "await",  "new", "throw", "switch", "case",  "break",  "continue", "true",
                "false", "null",   "None", "True",   "False",    "and",    "or",    "not",    "in",  "void",  "int",    "bool",  "string", "type",     "interface",
            };
            for (keywords) |keyword| if (equals(value, keyword)) {
                kind = .keyword;
                break;
            };
        }
        return .{ .start = start, .end = self.pos, .kind = kind };
    }
};
fn word(c: u16) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_' or c >= 128;
}
fn equals(value: []const u16, ascii: []const u8) bool {
    if (value.len != ascii.len) return false;
    for (value, ascii) |a, b| if (a != b) return false;
    return true;
}

pub fn fitCount(text: []const u16, fit: i32) usize {
    if (text.len == 0) return 0;
    var n = @min(text.len, @as(usize, @intCast(@max(1, fit))));
    if (n < text.len and text[n - 1] >= 0xD800 and text[n - 1] <= 0xDBFF) n = if (n > 1) n - 1 else @min(2, text.len);
    return n;
}

pub fn copyButton(area: anytype, pad: i32, button_w: i32, button_h: i32) @TypeOf(area) {
    return .{ .left = @max(area.left, area.right - pad - button_w), .top = area.top + pad, .right = @max(area.left, area.right - pad), .bottom = area.top + pad + button_h };
}
pub fn latest(blocks: []const md.Block) ?usize {
    var i = blocks.len;
    while (i > 0) {
        i -= 1;
        if (blocks[i].role == .code and blocks[i].len > 0) return i;
    }
    return null;
}
pub fn copyKey(vk: usize, ctrl: bool, shift: bool, alt: bool) bool {
    return vk == 0x44 and ctrl and shift and !alt;
}

test "code tokenizer keeps exact source and colors keywords strings numbers comments" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("const value = 42; // return is not a keyword here\nlet s = \"if 123\";");
    var it = Iterator{ .text = text };
    var end: usize = 0;
    var keywords: usize = 0;
    var strings: usize = 0;
    var numbers: usize = 0;
    var comments: usize = 0;
    while (it.next()) |token| {
        try std.testing.expectEqual(end, token.start);
        try std.testing.expect(token.end > token.start);
        end = token.end;
        switch (token.kind) {
            .keyword => keywords += 1,
            .string => strings += 1,
            .number => numbers += 1,
            .comment => comments += 1,
            else => {},
        }
    }
    try std.testing.expectEqual(text.len, end);
    try std.testing.expectEqual(@as(usize, 2), keywords);
    try std.testing.expectEqual(@as(usize, 1), strings);
    try std.testing.expectEqual(@as(usize, 1), numbers);
    try std.testing.expectEqual(@as(usize, 1), comments);
}
test "comments escaped quotes and unfinished strings cannot stall or recolor inner words" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("/*\nconst x\n*/ \"a\\\"b\" # if\n'unfinished");
    var it = Iterator{ .text = text };
    try std.testing.expectEqual(Kind.comment, it.next().?.kind);
    _ = it.next();
    try std.testing.expectEqual(Kind.string, it.next().?.kind);
    while (it.next()) |_| {}
    try std.testing.expectEqual(text.len, it.pos);
}
test "copy chooses newest nonempty code rather than prose and preserves blank lines" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("```zig\nconst x = 1;\n\nreturn x;\n```\nDone.");
    var blocks: [8]md.Block = undefined;
    const n = md.blocks(text, 0, .prose, &blocks);
    const index = latest(blocks[0..n]).?;
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("const x = 1;\n\nreturn x;"), text[blocks[index].start .. blocks[index].start + blocks[index].len]);
    try std.testing.expect(latest(&.{}) == null);
}
test "copy button remains inside narrow panels and respects scaled geometry" {
    const Rect = struct { left: i32, top: i32, right: i32, bottom: i32 };
    for ([_]i32{ 1, 2, 3 }) |scale| {
        const area = Rect{ .left = 10, .top = 50, .right = 410 * scale, .bottom = 500 * scale };
        const button = copyButton(area, 12 * scale, 64 * scale, 22 * scale);
        try std.testing.expect(button.left >= area.left and button.right <= area.right);
        try std.testing.expectEqual(area.top + 12 * scale, button.top);
    }
    const narrow = copyButton(Rect{ .left = 0, .top = 0, .right = 20, .bottom = 100 }, 12, 64, 22);
    try std.testing.expect(narrow.left >= 0 and narrow.right <= 20);
}
test "code copy shortcut is specific and never consumes AltGr" {
    try std.testing.expect(copyKey(0x44, true, true, false));
    try std.testing.expect(!copyKey(0x44, true, true, true));
    try std.testing.expect(!copyKey(0x44, true, false, false));
    try std.testing.expect(!copyKey(0x43, true, true, false));
}

test "narrow code wrapping never splits a UTF16 surrogate pair" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("a😀b");
    try std.testing.expectEqual(@as(usize, 1), fitCount(text, 2));
    try std.testing.expectEqual(@as(usize, 2), fitCount(text[1..], 1));
    try std.testing.expectEqual(text.len, fitCount(text, 100));
    try std.testing.expectEqual(@as(usize, 0), fitCount(&.{}, 0));
}
