const std = @import("std");

pub const MAX_OPTIONS = 8;
pub const TITLE_MAX = 120;
pub const DETAIL_MAX = 200;
pub const HEADER_MAX = 48;
pub const QUESTION_MAX = 240;
pub const OTHER_TITLE = "Type something else";

pub const Option = struct {
    label: [2]u16 = @splat(0),
    label_len: u8 = 0,
    digit: u8 = 0,
    title: [TITLE_MAX]u16 = @splat(0),
    title_len: u8 = 0,
    detail: [DETAIL_MAX]u16 = @splat(0),
    detail_len: u8 = 0,

    pub fn labelSlice(self: *const Option) []const u16 {
        return self.label[0..self.label_len];
    }

    pub fn titleSlice(self: *const Option) []const u16 {
        return self.title[0..self.title_len];
    }

    pub fn detailSlice(self: *const Option) []const u16 {
        return self.detail[0..self.detail_len];
    }
};

pub const Group = struct {
    count: usize = 0,
    options: [MAX_OPTIONS]Option = @splat(.{}),
    header: [HEADER_MAX]u16 = @splat(0),
    header_len: u8 = 0,
    question: [QUESTION_MAX]u16 = @splat(0),
    question_len: u8 = 0,
    other: u8 = 0,

    pub fn headerSlice(self: *const Group) []const u16 {
        return self.header[0..self.header_len];
    }

    pub fn questionSlice(self: *const Group) []const u16 {
        return self.question[0..self.question_len];
    }

    pub fn hash(self: *const Group) u64 {
        var h: u64 = 0xcbf29ce484222325;
        for (self.options[0..self.count]) |*option| {
            for (option.labelSlice()) |c| h = (h ^ c) *% 0x100000001b3;
            for (option.titleSlice()) |c| h = (h ^ c) *% 0x100000001b3;
            h = (h ^ 0xFFFF) *% 0x100000001b3;
        }
        for (self.questionSlice()) |c| h = (h ^ c) *% 0x100000001b3;
        return h;
    }

    pub fn eql(self: *const Group, other: *const Group) bool {
        return self.count == other.count and self.other == other.other and self.hash() == other.hash();
    }
};

pub const Chunk = struct { text: []const u16, level: u8 = 0 };

fn trimSpace(s: []const u16) []const u16 {
    return std.mem.trim(u16, s, &.{ ' ', '\t', '\r', 0, 0xA0 });
}

fn isLetter(c: u16) bool {
    return (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z');
}

fn isDigit(c: u16) bool {
    return c >= '0' and c <= '9';
}

fn startsWithAscii(s: []const u16, needle: []const u8) bool {
    if (s.len < needle.len) return false;
    for (needle, 0..) |ch, i| if (s[i] != ch) return false;
    return true;
}

fn containsFold(s: []const u16, needle: []const u8) bool {
    if (s.len < needle.len) return false;
    var i: usize = 0;
    while (i + needle.len <= s.len) : (i += 1) {
        var ok = true;
        for (needle, 0..) |ch, j| {
            const c = s[i + j];
            if (c > 127 or std.ascii.toLower(@as(u8, @intCast(c))) != ch) {
                ok = false;
                break;
            }
        }
        if (ok) return true;
    }
    return false;
}

fn indexOfAscii(s: []const u16, needle: []const u8) ?usize {
    if (s.len < needle.len) return null;
    var i: usize = 0;
    while (i + needle.len <= s.len) : (i += 1) {
        if (startsWithAscii(s[i..], needle)) return i;
    }
    return null;
}

fn plainInto(dst: []u16, src: []const u16) u8 {
    var n: usize = 0;
    var i: usize = 0;
    var gap = false;
    const body = trimSpace(src);
    while (i < body.len) {
        const c = body[i];
        if (c == '*' and i + 1 < body.len and body[i + 1] == '*') {
            i += 2;
            continue;
        }
        if (c == '`') {
            i += 1;
            continue;
        }
        if (c == ' ' or c == '\t' or c == '\r' or c == '\n') {
            gap = n > 0;
            i += 1;
            continue;
        }
        if (gap and n < dst.len) {
            dst[n] = ' ';
            n += 1;
        }
        gap = false;
        if (n >= dst.len) break;
        dst[n] = c;
        n += 1;
        i += 1;
    }
    if (n > 0 and n == dst.len and std.unicode.utf16IsHighSurrogate(dst[n - 1])) n -= 1;
    return @intCast(n);
}

fn trimTitleEnd(s: []const u16) []const u16 {
    return std.mem.trimEnd(u16, s, &.{ ' ', '.', ':', ',', ';', 0x2014, 0x2013, '-' });
}

const Item = struct {
    letter: bool,
    ordinal: u8,
    label: u16,
    label2: u16 = 0,
    title: []const u16,
    detail: []const u16,
};

fn parseItem(line: []const u16) ?Item {
    var i: usize = 0;
    if (line.len > 2 and (line[0] == '-' or line[0] == '*' or line[0] == '+') and line[1] == ' ') {
        i = 2;
        while (i < line.len and line[i] == ' ') i += 1;
    }
    var bold_open = false;
    if (startsWithAscii(line[i..], "**")) {
        bold_open = true;
        i += 2;
    }
    if (i >= line.len) return null;
    var letter = false;
    var ordinal: u8 = 0;
    var label: u16 = 0;
    var label2: u16 = 0;
    if (isLetter(line[i])) {
        if (i + 1 < line.len and isLetter(line[i + 1])) return null;
        letter = true;
        label = std.ascii.toUpper(@as(u8, @intCast(line[i])));
        ordinal = @intCast(label - 'A' + 1);
        i += 1;
    } else if (isDigit(line[i])) {
        var n: u32 = 0;
        const start = i;
        while (i < line.len and isDigit(line[i]) and i - start < 2) : (i += 1) n = n * 10 + (line[i] - '0');
        if (i < line.len and isDigit(line[i])) return null;
        if (n == 0 or n > 26) return null;
        ordinal = @intCast(n);
        label = line[start];
        if (i - start == 2) label2 = line[start + 1];
    } else return null;
    var punct: u16 = 0;
    if (i < line.len and (line[i] == '.' or line[i] == ')' or (line[i] == ':' and letter))) {
        punct = line[i];
        i += 1;
    }
    var closed = false;
    if (startsWithAscii(line[i..], "**")) {
        closed = true;
        i += 2;
    }
    if (punct == 0 and !(closed and bold_open)) return null;
    if (i >= line.len or (line[i] != ' ' and line[i] != '\t')) return null;
    const rest = trimSpace(line[i..]);
    if (rest.len == 0) return null;
    var title = rest;
    var detail: []const u16 = &.{};
    if (bold_open and !closed) {
        if (indexOfAscii(rest, "**")) |end| {
            title = rest[0..end];
            detail = rest[end + 2 ..];
        }
    } else if (startsWithAscii(rest, "**")) {
        if (indexOfAscii(rest[2..], "**")) |end| {
            title = rest[2 .. 2 + end];
            detail = rest[2 + end + 2 ..];
        }
    } else {
        var j: usize = 0;
        while (j < rest.len) : (j += 1) {
            if (rest[j] == '.' and j + 1 < rest.len and rest[j + 1] == ' ') {
                title = rest[0..j];
                detail = rest[j + 1 ..];
                break;
            }
            if (rest[j] == ' ' and j + 2 < rest.len and (rest[j + 1] == 0x2014 or rest[j + 1] == 0x2013 or rest[j + 1] == '-') and rest[j + 2] == ' ') {
                title = rest[0..j];
                detail = rest[j + 3 ..];
                break;
            }
        }
    }
    title = trimTitleEnd(trimSpace(title));
    if (title.len == 0) return null;
    return .{ .letter = letter, .ordinal = ordinal, .label = label, .label2 = label2, .title = title, .detail = trimSpace(detail) };
}

fn fillOption(option: *Option, item: Item) void {
    option.* = .{};
    option.label[0] = item.label;
    option.label_len = 1;
    if (item.label2 != 0) {
        option.label[1] = item.label2;
        option.label_len = 2;
    }
    option.title_len = plainInto(&option.title, item.title);
    option.detail_len = plainInto(&option.detail, item.detail);
}

fn appendDetail(option: *Option, line: []const u16) void {
    var tmp: [DETAIL_MAX]u16 = undefined;
    const n = plainInto(&tmp, line);
    if (n == 0) return;
    var len: usize = option.detail_len;
    if (len > 0 and len < option.detail.len) {
        option.detail[len] = ' ';
        len += 1;
    }
    const room = option.detail.len - len;
    const take = @min(room, n);
    @memcpy(option.detail[len..][0..take], tmp[0..take]);
    option.detail_len = @intCast(len + take);
}

pub fn parseReply(chunks: []const Chunk, out: *Group) bool {
    var found = false;
    var cur: Group = .{};
    var prev: u8 = 0;
    var letters = false;
    var last_chunk: usize = 0;
    for (chunks, 0..) |chunk, ci| {
        if (chunk.level != 0) {
            finish(&cur, out, &found, &prev);
            continue;
        }
        var lines = std.mem.tokenizeAny(u16, chunk.text, &.{ '\r', '\n' });
        while (lines.next()) |raw| {
            const line = trimSpace(raw);
            if (line.len == 0) continue;
            if (parseItem(line)) |item| {
                if (item.ordinal != prev + 1 or (cur.count > 0 and item.letter != letters)) finish(&cur, out, &found, &prev);
                if (item.ordinal == 1 or cur.count > 0) {
                    if (cur.count < MAX_OPTIONS) {
                        fillOption(&cur.options[cur.count], item);
                        cur.count += 1;
                        prev = item.ordinal;
                        letters = item.letter;
                        last_chunk = ci;
                    } else finish(&cur, out, &found, &prev);
                }
            } else if (cur.count > 0 and last_chunk == ci) {
                appendDetail(&cur.options[cur.count - 1], line);
            } else finish(&cur, out, &found, &prev);
        }
    }
    finish(&cur, out, &found, &prev);
    return found;
}

fn finish(cur: *Group, out: *Group, found: *bool, prev: *u8) void {
    if (cur.count >= 2) {
        out.* = cur.*;
        found.* = true;
    }
    cur.count = 0;
    prev.* = 0;
}

pub fn answerLen(option: *const Option, out: []u16) usize {
    var n: usize = 0;
    for (option.labelSlice()) |c| {
        if (n >= out.len) return n;
        out[n] = c;
        n += 1;
    }
    if (n + 2 > out.len) return n;
    out[n] = ':';
    out[n + 1] = ' ';
    n += 2;
    const take = @min(out.len - n, option.title_len);
    @memcpy(out[n..][0..take], option.titleSlice()[0..take]);
    return n + take;
}

fn separatorOnly(s: []const u16) bool {
    if (s.len == 0) return false;
    for (s) |c| if (c != 0x2500 and c != 0x2501 and c != '-') return false;
    return true;
}

fn cursorMark(c: u16) bool {
    return c == 0x276F or c == 0x203A or c == '>';
}

const Row = struct { index: usize, number: u8, selected: bool, text: []const u16 };

fn parseRow(line: []const u16, index: usize) ?Row {
    var i: usize = 0;
    var selected = false;
    if (line.len > 0 and cursorMark(line[0])) {
        selected = true;
        i = 1;
    }
    while (i < line.len and (line[i] == ' ' or line[i] == '\t')) i += 1;
    if (i + 2 >= line.len or line[i] < '1' or line[i] > '9') return null;
    if (line[i + 1] != '.' and line[i + 1] != ')') return null;
    if (line[i + 2] != ' ' and line[i + 2] != '\t') return null;
    const text = trimSpace(line[i + 3 ..]);
    if (text.len == 0) return null;
    return .{ .index = index, .number = @intCast(line[i] - '0'), .selected = selected, .text = text };
}

fn textEquals(s: []const u16, ascii: []const u8) bool {
    if (s.len != ascii.len) return false;
    for (ascii, 0..) |ch, i| if (s[i] != ch) return false;
    return true;
}

pub fn parseQuestion(raw: []const []const u16, out: *Group) bool {
    if (raw.len == 0 or raw.len > 200) return false;
    var lines: [200][]const u16 = undefined;
    for (raw, 0..) |row, i| lines[i] = trimSpace(row);
    const rows = lines[0..raw.len];
    var end: ?usize = null;
    for (rows, 0..) |row, i| {
        if (containsFold(row, "enter to select") and (containsFold(row, "navigate") or containsFold(row, "esc to cancel"))) end = i;
    }
    const footer = end orelse return false;
    for (rows[footer + 1 ..]) |row| if (row.len > 0 and !separatorOnly(row)) return false;
    var other_line: ?usize = null;
    var i: usize = 0;
    while (i < footer) : (i += 1) {
        if (parseRow(rows[i], i)) |r| {
            if (textEquals(r.text, "Type something.")) other_line = i;
        }
    }
    const other_at = other_line orelse return false;
    var start = other_at;
    while (start > 0 and !separatorOnly(rows[start - 1])) start -= 1;
    var parsed: [10]Row = undefined;
    var n: usize = 0;
    var idx = start;
    while (idx < footer) : (idx += 1) {
        if (parseRow(rows[idx], idx)) |r| {
            if (n >= parsed.len) return false;
            parsed[n] = r;
            n += 1;
        }
    }
    if (n < 3) return false;
    for (parsed[0..n], 0..) |r, k| if (r.number != k + 1) return false;
    var other_idx: ?usize = null;
    for (parsed[0..n], 0..) |r, k| {
        if (textEquals(r.text, "Type something.")) other_idx = k;
        if (std.mem.indexOfScalar(u16, r.text, 0x2610) != null or std.mem.indexOfScalar(u16, r.text, 0x2612) != null) return false;
    }
    const other = other_idx orelse return false;
    if (other < 2 or other > MAX_OPTIONS) return false;
    var any_selected = false;
    for (parsed[0..other]) |r| any_selected = any_selected or r.selected;
    if (!any_selected) return false;
    var g: Group = .{};
    var head_len: usize = 0;
    var question_len: usize = 0;
    var header_done = false;
    var q_tmp: [QUESTION_MAX]u16 = undefined;
    for (rows[start..parsed[0].index]) |line| {
        if (line.len == 0) continue;
        if (!header_done and line[0] == 0x2610) {
            header_done = true;
            const body = trimSpace(line[1..]);
            g.header_len = plainInto(&g.header, body);
            head_len = g.header_len;
            continue;
        }
        header_done = true;
        var part: [QUESTION_MAX]u16 = undefined;
        const pn = plainInto(&part, line);
        if (pn == 0) continue;
        if (question_len > 0 and question_len < q_tmp.len) {
            q_tmp[question_len] = ' ';
            question_len += 1;
        }
        const take = @min(q_tmp.len - question_len, pn);
        @memcpy(q_tmp[question_len..][0..take], part[0..take]);
        question_len += take;
    }
    if (question_len == 0 and head_len == 0) return false;
    @memcpy(g.question[0..question_len], q_tmp[0..question_len]);
    g.question_len = @intCast(question_len);
    for (parsed[0..other], 0..) |r, k| {
        var option: Option = .{};
        option.digit = '0' + r.number;
        option.label[0] = '0' + r.number;
        option.label_len = 1;
        option.title_len = plainInto(&option.title, r.text);
        const next_index = parsed[k + 1].index;
        for (rows[r.index + 1 .. next_index]) |line| {
            if (line.len == 0 or separatorOnly(line)) continue;
            appendDetail(&option, line);
        }
        g.options[k] = option;
    }
    g.count = other;
    g.other = '0' + parsed[other].number;
    out.* = g;
    return true;
}

fn w(comptime s: []const u8) []const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(s);
}

fn expectUtf16(expected: []const u8, actual: []const u16) !void {
    var buf: [256]u8 = undefined;
    const n = try std.unicode.utf16LeToUtf8(&buf, actual);
    try std.testing.expectEqualStrings(expected, buf[0..n]);
}

test "IGSH-984 lettered bold list items become options with title and detail" {
    const chunks = [_]Chunk{
        .{ .text = w("Two ways forward, both your call:") },
        .{ .text = w("**A. Create an OpenRouter account for inne.** Add credits and make one key."), .level = 0 },
        .{ .text = w("**B. Use your own account for now.** Save a capped key.") },
        .{ .text = w("I'd go with A.") },
    };
    var g: Group = .{};
    try std.testing.expect(parseReply(&chunks, &g));
    try std.testing.expectEqual(@as(usize, 2), g.count);
    try expectUtf16("A", g.options[0].labelSlice());
    try expectUtf16("Create an OpenRouter account for inne", g.options[0].titleSlice());
    try expectUtf16("Add credits and make one key.", g.options[0].detailSlice());
    try expectUtf16("Use your own account for now", g.options[1].titleSlice());
    var out: [64]u16 = undefined;
    const n = answerLen(&g.options[1], &out);
    try expectUtf16("B: Use your own account for now", out[0..n]);
}

test "IGSH-984 plain lettered lines and numbered bullets are options" {
    var g: Group = .{};
    const lines = [_]Chunk{.{ .text = w("Pick one:\nA. Reuse the Yeo UX key for now. Fastest.\nB) Make a new key - Slower but clean.") }};
    try std.testing.expect(parseReply(&lines, &g));
    try std.testing.expectEqual(@as(usize, 2), g.count);
    try expectUtf16("Reuse the Yeo UX key for now", g.options[0].titleSlice());
    try expectUtf16("Fastest.", g.options[0].detailSlice());
    try expectUtf16("Make a new key", g.options[1].titleSlice());
    const numbered = [_]Chunk{ .{ .text = w("- 1. First choice") }, .{ .text = w("- 2. Second choice") } };
    var n: Group = .{};
    try std.testing.expect(parseReply(&numbered, &n));
    try expectUtf16("2", n.options[1].labelSlice());
    try expectUtf16("Second choice", n.options[1].titleSlice());
}

test "IGSH-984 a single item, a skipped letter, nested items and plain words are not options" {
    var g: Group = .{};
    try std.testing.expect(!parseReply(&[_]Chunk{.{ .text = w("A. Only one") }}, &g));
    try std.testing.expect(!parseReply(&[_]Chunk{ .{ .text = w("A. First") }, .{ .text = w("C. Third") } }, &g));
    try std.testing.expect(!parseReply(&[_]Chunk{ .{ .text = w("A. First") }, .{ .text = w("B. Second"), .level = 1 } }, &g));
    try std.testing.expect(!parseReply(&[_]Chunk{.{ .text = w("Apple pie\nBanana split") }}, &g));
    try std.testing.expect(!parseReply(&[_]Chunk{ .{ .text = w("1. Install") }, .{ .text = w("Then run it.") }, .{ .text = w("2. Run") } }, &g));
    try std.testing.expect(!parseReply(&[_]Chunk{ .{ .text = w("A. First") }, .{ .text = w("1. Second") } }, &g));
}

test "IGSH-984 the latest group in a reply wins" {
    var g: Group = .{};
    const chunks = [_]Chunk{ .{ .text = w("1. Old one") }, .{ .text = w("2. Old two") }, .{ .text = w("Now choose:") }, .{ .text = w("A. New one") }, .{ .text = w("B. New two") }, .{ .text = w("C. New three") } };
    try std.testing.expect(parseReply(&chunks, &g));
    try std.testing.expectEqual(@as(usize, 3), g.count);
    try expectUtf16("New one", g.options[0].titleSlice());
}

const prompt_screen =
    "Previous chat\n" ++
    "\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\n" ++
    "\u{2610} Account\n" ++
    "Which account should we use?\n" ++
    "\n" ++
    "\u{276f} 1. Create a new account\n" ++
    "     Keep work separate.\n" ++
    "  2. Use the current account\n" ++
    "     Keep the current setup.\n" ++
    "  3. Type something.\n" ++
    "\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\n" ++
    "Enter to select \u{b7} Tab/Arrow keys to navigate \u{b7} Esc to cancel";

fn promptRows(comptime text: []const u8, rows: *[40][]const u16) usize {
    var n: usize = 0;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| {
        rows[n] = std.unicode.utf8ToUtf16LeAlloc(std.testing.allocator, line) catch return 0;
        n += 1;
    }
    return n;
}

fn freeRows(rows: *[40][]const u16, n: usize) void {
    for (rows[0..n]) |r| std.testing.allocator.free(r);
}

test "IGSH-984 Claude Code single select prompt yields digits, titles and details" {
    var rows: [40][]const u16 = undefined;
    const n = promptRows(prompt_screen, &rows);
    defer freeRows(&rows, n);
    var g: Group = .{};
    try std.testing.expect(parseQuestion(rows[0..n], &g));
    try std.testing.expectEqual(@as(usize, 2), g.count);
    try expectUtf16("Account", g.headerSlice());
    try expectUtf16("Which account should we use?", g.questionSlice());
    try expectUtf16("Create a new account", g.options[0].titleSlice());
    try expectUtf16("Keep work separate.", g.options[0].detailSlice());
    try std.testing.expectEqual(@as(u8, '2'), g.options[1].digit);
    try std.testing.expectEqual(@as(u8, '3'), g.other);
}

test "IGSH-984 prose, permission menus, multi select and old prompts are not questions" {
    var rows: [40][]const u16 = undefined;
    var g: Group = .{};
    const cases = [_][]const u8{
        "1. First choice\n2. Second choice",
        "\u{276f} 1. Yes\n  2. No\n  3. Type something.\nEsc to cancel",
        "\u{2610} Account\nWhich?\n\u{276f} 1. A\n  2. B\n  3. Type something.\nSpace to toggle \u{b7} Esc to cancel",
        prompt_screen ++ "\n\u{276f} Next request",
        "\u{2610} Account\nWhich?\n  1. A\n  2. B\n  3. Type something.\nEnter to select \u{b7} Esc to cancel",
    };
    inline for (cases) |case| {
        const n = promptRows(case, &rows);
        defer freeRows(&rows, n);
        try std.testing.expect(!parseQuestion(rows[0..n], &g));
    }
}
