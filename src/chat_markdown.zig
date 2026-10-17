const std = @import("std");

pub const Role = enum(u8) { user, prose, code, injected };
pub const Kind = enum { paragraph, heading, list, table };
pub const Block = struct {
    start: usize,
    len: usize,
    role: Role,
    markdown: bool = false,
    kind: Kind = .paragraph,
    level: u3 = 0,
    prefix: usize = 0,
    columns: u5 = 0,
    first: bool = false,
    image_count: u8 = 0,
    time: [5]u16 = @splat(0),
    zone: [6]u16 = @splat(0),
    sender: [64]u16 = @splat(0),
    stamp_ms: i64 = 0,
};
pub const Range = struct { start: usize, end: usize };
pub const Style = struct { bold: bool = false, italic: bool = false, code: bool = false };
pub const Span = struct { text: Range, style: Style = .{}, target: ?Range = null };

fn trim(s: []const u16) []const u16 {
    return std.mem.trim(u16, s, &.{ ' ', '\t', '\r' });
}
fn fence(s: []const u16) usize {
    if (s.len < 3 or (s[0] != '`' and s[0] != '~')) return 0;
    var n: usize = 1;
    while (n < s.len and s[n] == s[0]) : (n += 1) {}
    return if (n >= 3) n else 0;
}
fn separator(s: []const u16) bool {
    var ranges: [16]Range = undefined;
    const n = cells(s, &ranges);
    if (n == 0 or std.mem.indexOfScalar(u16, s, '|') == null) return false;
    for (ranges[0..n]) |r| {
        const part = std.mem.trim(u16, s[r.start..r.end], &.{':'});
        if (part.len < 3) return false;
        for (part) |c| if (c != '-') return false;
    }
    return true;
}

pub fn tableLength(text: []const u16) ?usize {
    const header_end = std.mem.indexOfScalar(u16, text, '\n') orelse return null;
    const delimiter_end = std.mem.indexOfScalarPos(u16, text, header_end + 1, '\n') orelse text.len;
    var ranges: [16]Range = undefined;
    const header = trim(text[0..header_end]);
    if (std.mem.indexOfScalar(u16, header, '|') == null or !separator(trim(text[header_end + 1 .. delimiter_end]))) return null;
    const columns = cells(header, &ranges);
    if (columns == 0 or cells(trim(text[header_end + 1 .. delimiter_end]), &ranges) != columns) return null;
    var end = delimiter_end;
    var pos = @min(end + 1, text.len);
    while (pos < text.len) {
        const next = std.mem.indexOfScalarPos(u16, text, pos, '\n') orelse text.len;
        const line = trim(text[pos..next]);
        if (line.len == 0 or std.mem.indexOfScalar(u16, line, '|') == null) break;
        end = next;
        pos = @min(next + 1, text.len);
    }
    return end;
}

pub fn consoleTableRow(raw: []const u16) bool {
    const line = trim(raw);
    if (line.len < 3 or (line[0] != 0x2502 and line[0] != '|') or line[line.len - 1] != line[0]) return false;
    return std.mem.count(u16, line, line[0..1]) >= 2;
}

fn append(out: []Block, n: *usize, block: Block) void {
    if (n.* == out.len) {
        std.mem.copyForwards(Block, out[0 .. out.len - 1], out[1..]);
        n.* -= 1;
    }
    out[n.*] = block;
    n.* += 1;
}

pub fn blocks(text: []const u16, offset: usize, role: Role, out: []Block) usize {
    if (text.len == 0 or out.len == 0) return 0;
    if (role == .user or role == .injected) {
        out[0] = .{ .start = offset, .len = text.len, .role = role, .markdown = true, .first = true };
        return 1;
    }
    var n: usize = 0;
    var pos: usize = 0;
    var code_start: ?usize = null;
    var code_char: u16 = 0;
    var code_fence: usize = 0;
    var separated = true;
    while (pos < text.len) {
        const end = std.mem.indexOfScalarPos(u16, text, pos, '\n') orelse text.len;
        const line = trim(text[pos..end]);
        const f = fence(line);
        if (code_start) |start| {
            if (f >= code_fence and line[0] == code_char and trim(line[f..]).len == 0) {
                var stop = pos;
                if (stop > start and text[stop - 1] == '\n') stop -= 1;
                if (stop > start and text[stop - 1] == '\r') stop -= 1;
                append(out, &n, .{ .start = offset + start, .len = stop - start, .role = .code, .markdown = true, .first = n == 0 });
                code_start = null;
            }
        } else if (f > 0) {
            separated = true;
            code_start = @min(end + 1, text.len);
            code_char = line[0];
            code_fence = f;
        } else if (tableLength(text[pos..])) |table_len| {
            var ranges: [16]Range = undefined;
            append(out, &n, .{ .start = offset + pos, .len = table_len, .role = .code, .kind = .table, .columns = @intCast(cells(line, &ranges)), .markdown = true, .first = n == 0 });
            pos = @min(pos + table_len + 1, text.len);
            separated = true;
            continue;
        } else if (line.len > 0) {
            const start = @as(usize, @intCast((@intFromPtr(line.ptr) - @intFromPtr(text.ptr)) / 2));
            var b = Block{ .start = offset + start, .len = line.len, .role = .prose, .markdown = true, .first = n == 0 };
            var hashes: usize = 0;
            while (hashes < line.len and hashes < 6 and line[hashes] == '#') : (hashes += 1) {}
            if (hashes > 0 and hashes < line.len and line[hashes] == ' ') {
                b.kind = .heading;
                b.level = @intCast(hashes);
                b.start += hashes + 1;
                b.len -= hashes + 1;
            } else if (line.len > 2 and (line[0] == '-' or line[0] == '*' or line[0] == '+') and line[1] == ' ') {
                b.kind = .list;
                b.prefix = 2;
            } else if (line[0] >= '0' and line[0] <= '9') {
                var digits: usize = 0;
                while (digits < line.len and line[digits] >= '0' and line[digits] <= '9') : (digits += 1) {}
                if (digits + 1 < line.len and (line[digits] == '.' or line[digits] == ')') and line[digits + 1] == ' ') {
                    b.kind = .list;
                    b.prefix = digits + 2;
                }
            }
            if (!separated and b.kind == .paragraph and n > 0 and out[n - 1].role == .prose and out[n - 1].kind == .paragraph and
                out[n - 1].start + out[n - 1].len + 2 >= offset + pos)
            {
                out[n - 1].len = b.start + b.len - out[n - 1].start;
            } else {
                append(out, &n, b);
            }
            separated = false;
        } else {
            separated = line.len == 0;
        }
        pos = @min(end + 1, text.len);
    }
    if (code_start) |start| {
        append(out, &n, .{ .start = offset + start, .len = text.len - start, .role = .code, .markdown = true, .first = n == 0 });
    }
    if (n > 0) out[0].first = true;
    return n;
}

pub fn cells(text: []const u16, out: []Range) usize {
    var pos: usize = if (text.len > 0 and text[0] == '|') 1 else 0;
    var n: usize = 0;
    while (pos < text.len and n < out.len) {
        var end = pos;
        var code_ticks: usize = 0;
        while (end < text.len) : (end += 1) {
            if (text[end] == '\\' and end + 1 < text.len) {
                end += 1;
                continue;
            }
            if (text[end] == '`') {
                var stop = end + 1;
                while (stop < text.len and text[stop] == '`') : (stop += 1) {}
                const ticks = stop - end;
                if (code_ticks == 0) code_ticks = ticks else if (code_ticks == ticks) code_ticks = 0;
                end = stop - 1;
            }
            if (text[end] == '|' and code_ticks == 0) break;
        }
        const part = trim(text[pos..end]);
        const start = pos + @as(usize, @intCast((@intFromPtr(part.ptr) - @intFromPtr(text[pos..].ptr)) / 2));
        out[n] = .{ .start = start, .end = start + part.len };
        n += 1;
        pos = end + 1;
    }
    return n;
}

pub fn inlineSpans(text: []const u16, out: []Span) usize {
    var n: usize = 0;
    var pos: usize = 0;
    var style: Style = .{};
    var closes: [3]?usize = .{ null, null, null };
    while (pos < text.len) {
        var handled = false;
        for (0..3) |k| {
            if (closes[k] != null and closes[k].? == pos) {
                pos += if (k == 0) @as(usize, 2) else 1;
                if (k == 0) style.bold = false else if (k == 1) style.italic = false else style.code = false;
                closes[k] = null;
                handled = true;
                break;
            }
        }
        if (handled) continue;
        if (text[pos] == '\\' and pos + 1 < text.len) {
            out[n] = .{ .text = .{ .start = pos + 1, .end = pos + 2 }, .style = style };
            n += 1;
            pos += 2;
            continue;
        }
        if (!style.code and text[pos] == '[') {
            if (std.mem.indexOfScalarPos(u16, text, pos + 1, ']')) |label_end| {
                if (label_end + 1 < text.len and text[label_end + 1] == '(') {
                    if (std.mem.indexOfScalarPos(u16, text, label_end + 2, ')')) |url_end| {
                        const url = text[label_end + 2 .. url_end];
                        const http = std.unicode.utf8ToUtf16LeStringLiteral("http://");
                        const https = std.unicode.utf8ToUtf16LeStringLiteral("https://");
                        if (std.mem.startsWith(u16, url, http) or std.mem.startsWith(u16, url, https)) {
                            out[n] = .{ .text = .{ .start = pos + 1, .end = label_end }, .style = style, .target = .{ .start = label_end + 2, .end = url_end } };
                            n += 1;
                            pos = url_end + 1;
                            continue;
                        }
                    }
                }
            }
        }
        const c = text[pos];
        if (c == '`' or (!style.code and (c == '*' or c == '_'))) {
            const double = c != '`' and pos + 1 < text.len and text[pos + 1] == c;
            const k: usize = if (c == '`') 2 else if (double) 0 else 1;
            const len: usize = if (double) 2 else 1;
            if (closes[k] == null) {
                if (std.mem.indexOfPos(u16, text, pos + len, text[pos .. pos + len])) |end| {
                    closes[k] = end;
                    if (k == 0) style.bold = true else if (k == 1) style.italic = true else style.code = true;
                    pos += len;
                    continue;
                }
            }
        }
        const start = pos;
        pos += 1;
        while (pos < text.len and text[pos] != '*' and text[pos] != '_' and text[pos] != '`' and text[pos] != '[' and text[pos] != '\\' and
            (closes[0] == null or closes[0].? != pos) and (closes[1] == null or closes[1].? != pos) and (closes[2] == null or closes[2].? != pos)) : (pos += 1)
        {}
        out[n] = .{ .text = .{ .start = start, .end = pos }, .style = style };
        n += 1;
    }
    if (pos < text.len and n > 0) out[n - 1].text.end = text.len;
    return n;
}

pub const TableText = struct {
    text: std.ArrayList(u16) = .empty,
    source: std.ArrayList(usize) = .empty,

    pub fn deinit(self: *TableText, a: std.mem.Allocator) void {
        self.text.deinit(a);
        self.source.deinit(a);
    }

    fn append(self: *TableText, a: std.mem.Allocator, c: u16, source: usize) !void {
        try self.text.append(a, c);
        try self.source.append(a, source);
    }
};

pub const TableCache = struct {
    const Entry = struct { columns: usize, len: usize, table: TableText };
    entries: std.AutoHashMapUnmanaged(usize, Entry) = .empty,
    builds: usize = 0,

    pub fn clear(self: *TableCache, a: std.mem.Allocator) void {
        var values = self.entries.valueIterator();
        while (values.next()) |entry| entry.table.deinit(a);
        self.entries.clearRetainingCapacity();
    }

    pub fn clearFrom(self: *TableCache, a: std.mem.Allocator, offset: usize) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            if (entry.key_ptr.* < offset) continue;
            const key = entry.key_ptr.*;
            entry.value_ptr.table.deinit(a);
            _ = self.entries.remove(key);
        }
    }

    pub fn deinit(self: *TableCache, a: std.mem.Allocator) void {
        self.clear(a);
        self.entries.deinit(a);
    }

    pub fn formatTable(self: *TableCache, a: std.mem.Allocator, text: []const u16, offset: usize, columns: usize) !*const TableText {
        if (self.entries.getPtr(offset)) |entry| {
            if (entry.columns == columns and entry.len == text.len) return &entry.table;
        }
        var table = try @import("chat_markdown.zig").formatTable(a, text, columns);
        errdefer table.deinit(a);
        const slot = try self.entries.getOrPut(a, offset);
        if (slot.found_existing) slot.value_ptr.table.deinit(a);
        slot.value_ptr.* = .{ .columns = columns, .len = text.len, .table = table };
        self.builds += 1;
        return &slot.value_ptr.table;
    }
};

fn charColumns(text: []const u16, pos: usize) usize {
    const c = text[pos];
    if ((c >= 0xDC00 and c <= 0xDFFF) or (c >= 0x0300 and c <= 0x036F) or (c >= 0xFE00 and c <= 0xFE0F)) return 0;
    if ((c >= 0xD800 and c <= 0xDBFF) or (c >= 0x1100 and c <= 0x115F) or
        (c >= 0x2E80 and c <= 0xA4CF) or (c >= 0xAC00 and c <= 0xD7A3) or
        (c >= 0xF900 and c <= 0xFAFF) or (c >= 0xFF01 and c <= 0xFF60)) return 2;
    return 1;
}

pub fn columnWidth(text: []const u16) usize {
    var width: usize = 0;
    for (0..text.len) |i| width += charColumns(text, i);
    return width;
}

pub fn formatTable(a: std.mem.Allocator, text: []const u16, max_columns: usize) !TableText {
    var plain = TableText{};
    defer plain.deinit(a);
    var rows: std.ArrayList([16]Range) = .empty;
    defer rows.deinit(a);
    var widths = [_]usize{2} ** 16;
    var columns: usize = 0;
    const delimiter_start = if (std.mem.indexOfScalar(u16, text, '\n')) |i| i + 1 else text.len;
    var pos: usize = 0;
    while (pos < text.len) {
        const end = std.mem.indexOfScalarPos(u16, text, pos, '\n') orelse text.len;
        const raw = text[pos..end];
        const line = trim(raw);
        const line_offset = pos + @as(usize, @intCast((@intFromPtr(line.ptr) - @intFromPtr(raw.ptr)) / 2));
        if (pos != delimiter_start or !separator(line)) {
            var ranges: [16]Range = undefined;
            const n = cells(line, &ranges);
            if (columns == 0) columns = n;
            var row: [16]Range = @splat(.{ .start = plain.text.items.len, .end = plain.text.items.len });
            for (ranges[0..@min(n, columns)], 0..) |r, ci| {
                const cell = line[r.start..r.end];
                const spans = try a.alloc(Span, cell.len + 1);
                defer a.free(spans);
                const count = inlineSpans(cell, spans);
                row[ci].start = plain.text.items.len;
                for (spans[0..count]) |span| for (span.text.start..span.text.end) |i| {
                    try plain.append(a, cell[i], line_offset + r.start + i);
                };
                row[ci].end = plain.text.items.len;
                widths[ci] = @max(widths[ci], @min(@max(2, max_columns), columnWidth(plain.text.items[row[ci].start..row[ci].end])));
            }
            try rows.append(a, row);
        }
        pos = @min(end + 1, text.len);
    }
    var total: usize = 3 * columns + 1;
    for (widths[0..columns]) |width| total += width;
    while (total > max_columns and columns > 0) {
        const widest = std.mem.indexOfMax(usize, widths[0..columns]);
        if (widths[widest] <= 2) break;
        widths[widest] -= 1;
        total -= 1;
    }
    var result = TableText{};
    errdefer result.deinit(a);
    for (rows.items, 0..) |row, ri| {
        var at: [16]usize = undefined;
        for (row[0..columns], 0..) |r, ci| at[ci] = r.start;
        var more = true;
        while (more) {
            more = false;
            if (result.text.items.len > 0) try result.append(a, '\n', row[0].start);
            try result.append(a, '|', 0);
            for (row[0..columns], 0..) |r, ci| {
                const source = if (at[ci] < plain.source.items.len) plain.source.items[at[ci]] else text.len;
                try result.append(a, ' ', source);
                var used: usize = 0;
                while (at[ci] < r.end) {
                    const width = charColumns(plain.text.items, at[ci]);
                    if (used + width > widths[ci]) break;
                    const i = at[ci];
                    try result.append(a, plain.text.items[i], plain.source.items[i]);
                    used += width;
                    at[ci] += 1;
                }
                more = more or at[ci] < r.end;
                while (used < widths[ci]) : (used += 1) try result.append(a, ' ', source);
                try result.append(a, ' ', source);
                try result.append(a, '|', source);
            }
            if (!more and ri == 0) {
                try result.append(a, '\n', 0);
                try result.append(a, '|', 0);
                for (widths[0..columns]) |width| {
                    for (0..width + 2) |_| try result.append(a, '-', 0);
                    try result.append(a, '|', 0);
                }
            }
        }
    }
    return result;
}

test "headings lists tables and fenced code retain exact offsets" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("# Title\n\n- one\n2. two\n\n| A | B |\n| --- | --- |\n| x | y |\n\n```zig\nconst x = 1;\n\n// blank stays\n```\nDone");
    var out: [20]Block = undefined;
    const n = blocks(text, 0, .prose, &out);
    try std.testing.expectEqual(@as(usize, 6), n);
    try std.testing.expectEqual(Kind.heading, out[0].kind);
    try std.testing.expectEqual(Kind.list, out[2].kind);
    try std.testing.expectEqual(Kind.table, out[3].kind);
    try std.testing.expectEqual(Role.code, out[3].role);
    try std.testing.expectEqual(Role.code, out[4].role);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("const x = 1;\n\n// blank stays"), text[out[4].start .. out[4].start + out[4].len]);
}
test "user content is not interpreted as assistant markup" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("# question\n```\ntext");
    var out: [4]Block = undefined;
    try std.testing.expectEqual(@as(usize, 1), blocks(text, 8, .user, &out));
    try std.testing.expectEqual(@as(usize, 8), out[0].start);
    try std.testing.expectEqual(Kind.paragraph, out[0].kind);
}
test "inline bold italic code links escapes and unfinished syntax" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("**bold** *italic* `x` [site](https://example.test) \\*literal **unfinished");
    var out: [40]Span = undefined;
    const n = inlineSpans(text, &out);
    try std.testing.expect(out[0].style.bold);
    try std.testing.expect(out[2].style.italic);
    try std.testing.expect(out[4].style.code);
    try std.testing.expect(out[6].target != null);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("site"), text[out[6].text.start..out[6].text.end]);
    try std.testing.expect(!out[n - 1].style.bold);
}
test "unclosed and mismatched fences stay code while streaming" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("````python\nprint(1)\n```\n");
    var out: [4]Block = undefined;
    try std.testing.expectEqual(@as(usize, 1), blocks(text, 0, .prose, &out));
    try std.testing.expectEqual(Role.code, out[0].role);
    try std.testing.expectEqual(@as(usize, 11), out[0].start);
}
test "table cells ignore escaped pipes and inline code pipes" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| a\\|b | `x|y` | c |");
    var out: [8]Range = undefined;
    try std.testing.expectEqual(@as(usize, 3), cells(text, &out));
}
test "blank lines keep paragraphs separate and unsupported links literal" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("one\ncontinued\n\ntwo");
    var out: [4]Block = undefined;
    try std.testing.expectEqual(@as(usize, 2), blocks(text, 0, .prose, &out));
    var spans: [8]Span = undefined;
    const bad = std.unicode.utf8ToUtf16LeStringLiteral("[run](javascript:alert)");
    const n = inlineSpans(bad, &spans);
    for (spans[0..n]) |span| try std.testing.expect(span.target == null);
}

test "bounded blocks retain the newest paragraphs" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("one\n\ntwo\n\nthree");
    var out: [2]Block = undefined;
    try std.testing.expectEqual(@as(usize, 2), blocks(text, 0, .prose, &out));
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("three"), text[out[1].start .. out[1].start + out[1].len]);
}

test "table detection requires a matching delimiter and retains the complete table as one code block" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("Before\n\n| a | b |\n|:---|---:|\n| one | two |\n| three | four |\n\nAfter");
    var out: [8]Block = undefined;
    try std.testing.expectEqual(@as(usize, 3), blocks(text, 10, .prose, &out));
    try std.testing.expectEqual(Role.code, out[1].role);
    try std.testing.expectEqual(Kind.table, out[1].kind);
    try std.testing.expectEqual(@as(u5, 2), out[1].columns);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("| a | b |\n|:---|---:|\n| one | two |\n| three | four |"), text[out[1].start - 10 .. out[1].start - 10 + out[1].len]);
    try std.testing.expect(tableLength(std.unicode.utf8ToUtf16LeStringLiteral("a | b\n---|---\nx | y")) != null);
    try std.testing.expect(tableLength(std.unicode.utf8ToUtf16LeStringLiteral("| a | b |\n|---|--|\n|x|y|")) == null);
    try std.testing.expect(tableLength(std.unicode.utf8ToUtf16LeStringLiteral("| a | b |\n|---|\n|x|y|")) == null);
    const lone = std.unicode.utf8ToUtf16LeStringLiteral("|---|---|");
    try std.testing.expectEqual(@as(usize, 1), blocks(lone, 0, .prose, &out));
    try std.testing.expectEqualSlices(u16, lone, lone[out[0].start .. out[0].start + out[0].len]);
}

test "table column alignment strips inline code and link markup and counts unicode display columns" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| Name | Value |\n|---|---|\n| `x|y` | [site](https://example.test) |\n| 中文😀 | café |");
    var table = try formatTable(std.testing.allocator, text, 80);
    defer table.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("| Name   | Value |\n|--------|-------|\n| x|y    | site  |\n| 中文😀 | café  |"), table.text.items);
    try std.testing.expectEqual(table.text.items.len, table.source.items.len);
    const site = std.unicode.utf8ToUtf16LeStringLiteral("site");
    const at = std.mem.indexOf(u16, table.text.items, site).?;
    try std.testing.expectEqualSlices(u16, site, text[table.source.items[at] .. table.source.items[at] + site.len]);
    var lines = std.mem.splitScalar(u16, table.text.items, '\n');
    while (lines.next()) |line| try std.testing.expectEqual(@as(usize, 18), columnWidth(line));
}

test "table long cells wrap inside aligned columns without splitting unicode or dropping empty cells" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| Name | Value |\n|---|---|\n| 中文😀 | abcdefghijklmnop |\n| x | |");
    var table = try formatTable(std.testing.allocator, text, 14);
    defer table.deinit(std.testing.allocator);
    var lines = std.mem.splitScalar(u16, table.text.items, '\n');
    var count: usize = 0;
    while (lines.next()) |line| {
        count += 1;
        try std.testing.expectEqual(@as(usize, 14), columnWidth(line));
        const utf8 = try std.unicode.utf16LeToUtf8Alloc(std.testing.allocator, line);
        std.testing.allocator.free(utf8);
    }
    try std.testing.expect(count > 4);
    var ranges: [2]Range = undefined;
    try std.testing.expectEqual(@as(usize, 2), cells(std.unicode.utf8ToUtf16LeStringLiteral("| ``x|y`` | z |"), &ranges));
    try std.testing.expectEqual(@as(usize, 2), cells(std.unicode.utf8ToUtf16LeStringLiteral("| a | b | c |"), &ranges));
    try std.testing.expect(consoleTableRow(std.unicode.utf8ToUtf16LeStringLiteral("│ Event │ Status │")));
    try std.testing.expect(!consoleTableRow(std.unicode.utf8ToUtf16LeStringLiteral("│ tool output")));
}

test "table formatting retains separator-like data rows and one-column console tables" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| a | b |\n|---|---|\n|---|---|");
    var table = try formatTable(std.testing.allocator, text, 80);
    defer table.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("| a   | b   |\n|-----|-----|\n| --- | --- |"), table.text.items);
    try std.testing.expect(consoleTableRow(std.unicode.utf8ToUtf16LeStringLiteral("│ one column │")));
}
