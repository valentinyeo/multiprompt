const std = @import("std");
const link_detect = @import("link_detect.zig");
const unicode = @import("chat_markdown_unicode.zig");

pub const Role = enum(u8) { user, prose, code, injected, tool };
pub const ToolStatus = enum { running, ok, @"error" };
pub const Kind = enum { paragraph, heading, list, table };
pub const Block = struct {
    start: usize,
    len: usize,
    role: Role,
    markdown: bool = false,
    kind: Kind = .paragraph,
    level: u8 = 0,
    prefix: usize = 0,
    columns: u5 = 0,
    first: bool = false,
    image_count: u8 = 0,
    time: [5]u16 = @splat(0),
    zone: [6]u16 = @splat(0),
    sender: [64]u16 = @splat(0),
    stamp_ms: i64 = 0,
    tool_status: ToolStatus = .running,
    tool_id: u64 = 0,
    detail_start: usize = 0,
    detail_len: usize = 0,
    diff_start: usize = 0,
    diff_len: usize = 0,
    tool_open: bool = false,
    source_offset: u64 = 0,
    source_end: u64 = 0,
    segment: u64 = 0,
    result_offset: ?u64 = null,
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
    if (boxTableLength(text)) |len| return len;
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

pub fn boxBorder(raw: []const u16, left: u16, joint: u16, right: u16) usize {
    const line = trim(raw);
    if (line.len < 3 or line[0] != left or line[line.len - 1] != right) return 0;
    var columns: usize = 1;
    var dashes: usize = 0;
    for (line[1 .. line.len - 1]) |c| {
        if (c == 0x2500) {
            dashes += 1;
        } else if (c == joint and dashes > 0) {
            columns += 1;
            dashes = 0;
        } else return 0;
    }
    return if (dashes > 0 and columns <= 16) columns else 0;
}

pub fn consoleTableLine(raw: []const u16) bool {
    return consoleTableRow(raw) or boxBorder(raw, 0x250C, 0x252C, 0x2510) > 0 or
        boxBorder(raw, 0x251C, 0x253C, 0x2524) > 0 or boxBorder(raw, 0x2514, 0x2534, 0x2518) > 0;
}

pub fn boxTableLength(text: []const u16) ?usize {
    const first = std.mem.indexOfScalar(u16, text, '\n') orelse return null;
    const columns = boxBorder(text[0..first], 0x250C, 0x252C, 0x2510);
    if (columns == 0) return null;
    var pos = first + 1;
    var group: usize = 0;
    while (pos < text.len) {
        const end = std.mem.indexOfScalarPos(u16, text, pos, '\n') orelse text.len;
        const line = trim(text[pos..end]);
        if (boxBorder(line, 0x2514, 0x2534, 0x2518) == columns) return if (group > 0) end else null;
        if (boxBorder(line, 0x251C, 0x253C, 0x2524) == columns) {
            if (group == 0) return null;
            group = 0;
        } else if (line.len > 1 and line[0] == 0x2502 and line[line.len - 1] == 0x2502 and std.mem.count(u16, line, &.{0x2502}) == columns + 1) {
            group += 1;
        } else return null;
        pos = @min(end + 1, text.len);
    }
    return null;
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
    if (role == .user or role == .injected or role == .tool) {
        out[0] = .{ .start = offset, .len = text.len, .role = role, .markdown = true, .first = true };
        return 1;
    }
    var n: usize = 0;
    var pos: usize = 0;
    var code_start: ?usize = null;
    var code_char: u16 = 0;
    var code_fence: usize = 0;
    var separated = true;
    var indents: [256]usize = undefined;
    var depth: usize = 0;
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
            append(out, &n, .{ .start = offset + pos, .len = table_len, .role = .code, .kind = .table, .columns = @intCast(if (boxBorder(line, 0x250C, 0x252C, 0x2510) > 0) boxBorder(line, 0x250C, 0x252C, 0x2510) else cells(line, &ranges)), .markdown = true, .first = n == 0 });
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
            if (b.kind == .list) {
                var indent: usize = 0;
                for (text[pos..start]) |c| indent += if (c == '\t') @as(usize, 4) else 1;
                while (depth > 0 and indent < indents[depth - 1]) depth -= 1;
                if (depth == 0 or indent > indents[depth - 1]) {
                    if (depth < indents.len) {
                        indents[depth] = indent;
                        depth += 1;
                    }
                }
                b.level = @intCast(depth - 1);
            } else if (b.kind == .paragraph) depth = 0;
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

const InlineAtom = struct { span: Span, end: usize };

fn inlineAtom(text: []const u16, pos: usize) ?InlineAtom {
    if (text[pos] == '`') {
        var content = pos + 1;
        while (content < text.len and text[content] == '`') : (content += 1) {}
        var end = content;
        while (end < text.len) {
            if (text[end] != '`') {
                end += 1;
                continue;
            }
            var stop = end + 1;
            while (stop < text.len and text[stop] == '`') : (stop += 1) {}
            if (stop - end == content - pos) return .{ .span = .{ .text = .{ .start = content, .end = end }, .style = .{ .code = true } }, .end = stop };
            end = stop;
        }
    }
    if (text[pos] == '[') {
        if (std.mem.indexOfScalarPos(u16, text, pos + 1, ']')) |label_end| {
            if (label_end + 1 < text.len and text[label_end + 1] == '(') {
                if (std.mem.indexOfScalarPos(u16, text, label_end + 2, ')')) |url_end| {
                    const url = text[label_end + 2 .. url_end];
                    const http = std.unicode.utf8ToUtf16LeStringLiteral("http://");
                    const https = std.unicode.utf8ToUtf16LeStringLiteral("https://");
                    if (std.mem.startsWith(u16, url, http) or std.mem.startsWith(u16, url, https)) {
                        return .{ .span = .{ .text = .{ .start = pos + 1, .end = label_end }, .target = .{ .start = label_end + 2, .end = url_end } }, .end = url_end + 1 };
                    }
                }
            }
        }
    }
    if (text[pos] == '<') {
        if (std.mem.indexOfScalarPos(u16, text, pos + 1, '>')) |end| {
            const url = text[pos + 1 .. end];
            if (link_detect.scheme(url)) {
                for (url) |c| if (!link_detect.isUrlChar(c)) return null;
                return .{ .span = .{ .text = .{ .start = pos + 1, .end = end }, .target = .{ .start = pos + 1, .end = end } }, .end = end + 1 };
            }
        }
    }
    if (link_detect.scheme(text[pos..])) {
        if (link_detect.next(text, pos)) |url| {
            if (url.start == pos) return .{ .span = .{ .text = .{ .start = url.start, .end = url.end }, .target = .{ .start = url.start, .end = url.end } }, .end = url.end };
        }
    }
    return null;
}

fn underscoreFlanking(text: []const u16, start: usize, end: usize) struct { open: bool, close: bool } {
    var before: u21 = if (start == 0) ' ' else text[start - 1];
    if (start >= 2 and before >= 0xDC00 and before <= 0xDFFF) before = std.unicode.utf16DecodeSurrogatePair(text[start - 2 .. start]) catch before;
    var after: u21 = if (end == text.len) ' ' else text[end];
    if (end + 1 < text.len and after >= 0xD800 and after <= 0xDBFF) after = std.unicode.utf16DecodeSurrogatePair(text[end .. end + 2]) catch after;
    const before_space = unicode.whitespace(before);
    const after_space = unicode.whitespace(after);
    const before_punct = unicode.punctuation(before);
    const after_punct = unicode.punctuation(after);
    const left = !after_space and (!after_punct or before_space or before_punct);
    const right = !before_space and (!before_punct or after_space or after_punct);
    return .{ .open = left and (!right or before_punct), .close = right and (!left or after_punct) };
}

fn emphasisEnd(text: []const u16, start: usize, len: usize) ?usize {
    const c = text[start];
    var run_end = start + len;
    if (c == '_') {
        while (run_end < text.len and text[run_end] == c) : (run_end += 1) {}
        if (!underscoreFlanking(text, start, run_end).open) return null;
    }
    var pos = start + len;
    while (pos < text.len) {
        if (text[pos] == '\\' and pos + 1 < text.len) {
            pos += 2;
            continue;
        }
        if (inlineAtom(text, pos)) |atom| {
            pos = atom.end;
            continue;
        }
        if (text[pos] == c and std.mem.startsWith(u16, text[pos..], text[start .. start + len])) {
            if (c != '_') return pos;
            var end = pos + len;
            while (end < text.len and text[end] == c) : (end += 1) {}
            if (pos >= run_end and underscoreFlanking(text, pos, end).close) return pos;
            pos = end;
            continue;
        }
        if (text[pos] == '`') {
            while (pos < text.len and text[pos] == '`') : (pos += 1) {}
        } else pos += 1;
    }
    return null;
}

pub fn inlineSpans(text: []const u16, out: []Span) usize {
    var n: usize = 0;
    var pos: usize = 0;
    var style: Style = .{};
    var closes: [2]?usize = .{ null, null };
    while (pos < text.len) {
        var handled = false;
        for (0..2) |k| {
            if (closes[k] != null and closes[k].? == pos) {
                pos += if (k == 0) @as(usize, 2) else 1;
                if (k == 0) style.bold = false else style.italic = false;
                closes[k] = null;
                handled = true;
                break;
            }
        }
        if (handled) continue;
        if (!style.code and text[pos] == '\\' and pos + 1 < text.len and
            text[pos + 1] <= 0x7f and std.ascii.isPunctuation(@intCast(text[pos + 1])))
        {
            out[n] = .{ .text = .{ .start = pos + 1, .end = pos + 2 }, .style = style };
            n += 1;
            pos += 2;
            continue;
        }
        if (inlineAtom(text, pos)) |atom| {
            out[n] = atom.span;
            out[n].style.bold = style.bold;
            out[n].style.italic = style.italic;
            n += 1;
            pos = atom.end;
            continue;
        }
        const c = text[pos];
        if (c == '*' or c == '_') {
            const double = pos + 1 < text.len and text[pos + 1] == c;
            const k: usize = if (double) 0 else 1;
            const len: usize = if (double) 2 else 1;
            if (closes[k] == null) {
                if (emphasisEnd(text, pos, len)) |end| {
                    closes[k] = end;
                    if (k == 0) style.bold = true else style.italic = true;
                    pos += len;
                    continue;
                }
            }
        }
        const start = pos;
        pos += 1;
        if (c == '_' or c == '`') while (pos < text.len and text[pos] == c) : (pos += 1) {};
        while (pos < text.len and text[pos] != '*' and text[pos] != '_' and text[pos] != '`' and text[pos] != '[' and text[pos] != '\\' and
            (closes[0] == null or closes[0].? != pos) and (closes[1] == null or closes[1].? != pos) and inlineAtom(text, pos) == null) : (pos += 1)
        {}
        out[n] = .{ .text = .{ .start = start, .end = pos }, .style = style };
        n += 1;
    }
    if (pos < text.len and n > 0) out[n - 1].text.end = text.len;
    return n;
}

pub const Cell = struct {
    fragments: std.ArrayList(Range) = .empty,
};
pub const Row = struct {
    cells: []Cell,
    start: usize,
    end: usize,
};
pub const Table = struct {
    columns: usize,
    source: enum { pipe, box },
    rows: std.ArrayList(Row) = .empty,

    pub fn deinit(self: *Table, a: std.mem.Allocator) void {
        for (self.rows.items) |row| {
            for (row.cells) |*cell| cell.fragments.deinit(a);
            a.free(row.cells);
        }
        self.rows.deinit(a);
    }

    fn addRow(self: *Table, a: std.mem.Allocator, start: usize) !void {
        const row = try a.alloc(Cell, self.columns);
        errdefer a.free(row);
        @memset(row, .{});
        try self.rows.append(a, .{ .cells = row, .start = start, .end = start });
    }
};

pub fn parseTable(a: std.mem.Allocator, text: []const u16) !Table {
    const len = tableLength(text) orelse return error.InvalidTable;
    if (std.mem.trim(u16, text[len..], &.{ ' ', '\t', '\r', '\n' }).len != 0) return error.InvalidTable;
    const first = std.mem.indexOfScalar(u16, text, '\n').?;
    const box_columns = boxBorder(text[0..first], 0x250C, 0x252C, 0x2510);
    var ranges: [16]Range = undefined;
    var table = Table{ .columns = if (box_columns > 0) box_columns else cells(trim(text[0..first]), &ranges), .source = if (box_columns > 0) .box else .pipe };
    errdefer table.deinit(a);
    var separators: usize = 0;
    if (box_columns > 0) {
        var lines = std.mem.splitScalar(u16, text, '\n');
        while (lines.next()) |line| if (boxBorder(line, 0x251C, 0x253C, 0x2524) > 0) {
            separators += 1;
        };
    }
    var pos: usize = 0;
    var line_index: usize = 0;
    var group: usize = 0;
    var new_row = true;
    while (pos < len) : (line_index += 1) {
        const end = std.mem.indexOfScalarPos(u16, text, pos, '\n') orelse len;
        const line = trim(text[pos..end]);
        const base = @as(usize, @intCast((@intFromPtr(line.ptr) - @intFromPtr(text.ptr)) / 2));
        defer pos = @min(end + 1, text.len);
        if (table.source == .box) {
            if (boxBorder(line, 0x250C, 0x252C, 0x2510) > 0 or boxBorder(line, 0x2514, 0x2534, 0x2518) > 0) continue;
            if (boxBorder(line, 0x251C, 0x253C, 0x2524) > 0) {
                group += 1;
                new_row = true;
                continue;
            }
            if (new_row or (separators <= 1 and group > 0)) try table.addRow(a, pos);
            new_row = false;
            var start: usize = 1;
            for (table.rows.items[table.rows.items.len - 1].cells) |*cell| {
                const stop = std.mem.indexOfScalarPos(u16, line, start, 0x2502) orelse return error.InvalidTable;
                const part = trim(line[start..stop]);
                const at = base + @as(usize, @intCast((@intFromPtr(part.ptr) - @intFromPtr(line.ptr)) / 2));
                try cell.fragments.append(a, .{ .start = at, .end = at + part.len });
                start = stop + 1;
            }
        } else {
            if (line_index == 1) continue;
            const n = @min(cells(line, &ranges), table.columns);
            try table.addRow(a, pos);
            for (table.rows.items[table.rows.items.len - 1].cells[0..n], ranges[0..n]) |*cell, range| {
                try cell.fragments.append(a, .{ .start = base + range.start, .end = base + range.end });
            }
        }
        table.rows.items[table.rows.items.len - 1].end = end;
    }
    return table;
}

pub fn tableScroll(offset: i32, delta: i32, step: i32, content_w: i32, view_w: i32) i32 {
    const next = @as(i64, offset) + @divTrunc(@as(i64, delta) * step, 120);
    return @intCast(std.math.clamp(next, 0, @as(i64, @max(0, content_w - view_w))));
}

pub const TableScrollHit = enum { outside, body, thumb, track_before, track_after };
pub const TableScrollbar = struct {
    view_w: i32,
    body_h: i32,
    bar_h: i32,
    thumb_x: i32,
    thumb_w: i32,
    max_scroll: i32,

    pub fn init(content_w: i32, view_w: i32, body_h: i32, offset: i32, bar_h: i32, min_thumb: i32) ?TableScrollbar {
        if (view_w <= 0 or content_w <= view_w) return null;
        const thumb_w: i32 = @intCast(@min(view_w, @max(@min(min_thumb, @max(1, @divTrunc(view_w, 2))), @divTrunc(@as(i64, view_w) * view_w, content_w))));
        const max_scroll = content_w - view_w;
        return .{ .view_w = view_w, .body_h = body_h, .bar_h = bar_h, .thumb_x = @intCast(@divTrunc(@as(i64, std.math.clamp(offset, 0, max_scroll)) * (view_w - thumb_w), max_scroll)), .thumb_w = thumb_w, .max_scroll = max_scroll };
    }

    pub fn hit(self: TableScrollbar, x: i32, y: i32) TableScrollHit {
        if (x < 0 or x >= self.view_w or y < 0 or y >= self.body_h + self.bar_h) return .outside;
        if (y < self.body_h) return .body;
        if (x < self.thumb_x) return .track_before;
        if (x >= self.thumb_x + self.thumb_w) return .track_after;
        return .thumb;
    }

    pub fn drag(self: TableScrollbar, offset: i32, pointer_delta: i32) i32 {
        const travel = self.view_w - self.thumb_w;
        if (travel <= 0) return std.math.clamp(offset, 0, self.max_scroll);
        const next = @as(i64, offset) + @divTrunc(@as(i64, pointer_delta) * self.max_scroll, travel);
        return @intCast(std.math.clamp(next, 0, self.max_scroll));
    }

    pub fn page(self: TableScrollbar, offset: i32, target: TableScrollHit) i32 {
        const delta: i64 = switch (target) {
            .track_before => -@as(i64, self.view_w),
            .track_after => self.view_w,
            else => 0,
        };
        return @intCast(std.math.clamp(@as(i64, offset) + delta, 0, self.max_scroll));
    }

    pub fn wheel(self: TableScrollbar, x: i32, y: i32, horizontal: bool, shift: bool, delta: i32) ?i32 {
        if ((!horizontal and !shift) or self.hit(x, y) == .outside) return null;
        return if (horizontal) delta else -delta;
    }
};

pub const TableSize = struct { width: i32, height: i32 };
pub const TableKey = struct { view_w: i32, font_pt: i32, scale: i32, pad_x: i32, pad_y: i32 };
pub const TableLayout = struct {
    table: Table,
    widths: []i32,
    heights: []i32,
    lines: []i32,
    content_w: i32,
    view_w: i32,
    scroll: i32 = 0,

    fn deinit(self: *TableLayout, a: std.mem.Allocator) void {
        self.table.deinit(a);
        a.free(self.widths);
        a.free(self.heights);
        a.free(self.lines);
    }

    pub fn bodyHeight(self: *const TableLayout) i32 {
        var height: i32 = 1;
        for (self.heights) |h| height += h;
        return height;
    }

    pub fn scrollbar(self: *const TableLayout, bar_h: i32, min_thumb: i32) ?TableScrollbar {
        return TableScrollbar.init(self.content_w, self.view_w, self.bodyHeight(), self.scroll, bar_h, min_thumb);
    }

    pub fn rowY(self: *const TableLayout, position: usize) i32 {
        var y: i32 = 0;
        for (self.table.rows.items, self.heights, 0..) |row, h, i| {
            if (position < row.end or i + 1 == self.heights.len) return y;
            y += h;
        }
        return y;
    }
};

pub const TableCache = struct {
    const Entry = struct { hash: u64, key: TableKey, layout: TableLayout };
    entries: std.AutoHashMapUnmanaged(usize, Entry) = .empty,
    builds: usize = 0,
    lists: std.AutoHashMapUnmanaged(usize, u8) = .empty,

    pub fn clear(self: *TableCache, a: std.mem.Allocator) void {
        var values = self.entries.valueIterator();
        while (values.next()) |entry| entry.layout.deinit(a);
        self.entries.clearRetainingCapacity();
        self.lists.clearRetainingCapacity();
    }

    pub fn list(self: *TableCache, a: std.mem.Allocator, offset: usize, depth: u8) bool {
        const slot = self.lists.getOrPut(a, offset) catch return false;
        if (slot.found_existing and slot.value_ptr.* == depth) return false;
        slot.value_ptr.* = depth;
        return true;
    }

    pub fn clearFrom(self: *TableCache, a: std.mem.Allocator, offset: usize) void {
        var lists = self.lists.iterator();
        while (lists.next()) |entry| {
            if (entry.key_ptr.* >= offset) _ = self.lists.remove(entry.key_ptr.*);
        }
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            if (entry.key_ptr.* < offset) continue;
            const key = entry.key_ptr.*;
            entry.value_ptr.layout.deinit(a);
            _ = self.entries.remove(key);
        }
    }

    pub fn refresh(self: *TableCache, a: std.mem.Allocator, before: []const Block, after: []const Block) void {
        const Identity = struct { message: u64, segment: u64, table: usize };
        var identities: std.AutoHashMapUnmanaged(Identity, usize) = .empty;
        defer identities.deinit(a);
        identities.ensureTotalCapacity(a, self.entries.count()) catch {
            self.clear(a);
            return;
        };
        var retained: std.AutoHashMapUnmanaged(usize, Entry) = .empty;
        retained.ensureTotalCapacity(a, self.entries.count()) catch {
            self.clear(a);
            return;
        };
        var message: u64 = 0;
        var ordinal: usize = 0;
        for (before) |block| {
            const id = if (block.source_end != 0) block.source_offset else message;
            if (block.first or id != message) {
                message = if (block.source_end != 0) block.source_offset else @intCast(block.start);
                ordinal = 0;
            }
            if (block.kind != .table) continue;
            if (self.entries.contains(block.start)) identities.putAssumeCapacity(.{ .message = message, .segment = block.segment, .table = ordinal }, block.start);
            ordinal += 1;
        }
        message = 0;
        ordinal = 0;
        for (after) |block| {
            const id = if (block.source_end != 0) block.source_offset else message;
            if (block.first or id != message) {
                message = if (block.source_end != 0) block.source_offset else @intCast(block.start);
                ordinal = 0;
            }
            if (block.kind != .table) continue;
            if (identities.get(.{ .message = message, .segment = block.segment, .table = ordinal })) |old_offset| {
                if (self.entries.fetchRemove(old_offset)) |entry| retained.putAssumeCapacity(block.start, entry.value);
            }
            ordinal += 1;
        }
        self.clear(a);
        self.entries.deinit(a);
        self.entries = retained;
    }

    pub fn deinit(self: *TableCache, a: std.mem.Allocator) void {
        self.clear(a);
        self.entries.deinit(a);
        self.lists.deinit(a);
    }

    pub fn layout(self: *TableCache, a: std.mem.Allocator, text: []const u16, offset: usize, key: TableKey, context: anytype, comptime measure: fn (@TypeOf(context), []const u16, bool) TableSize) !*TableLayout {
        const hash = std.hash.Wyhash.hash(0, std.mem.sliceAsBytes(text));
        var scroll: i32 = 0;
        if (self.entries.getPtr(offset)) |entry| {
            if (entry.hash == hash and std.meta.eql(entry.key, key)) return &entry.layout;
            scroll = entry.layout.scroll;
        }
        var table = try parseTable(a, text);
        errdefer table.deinit(a);
        const widths = try a.alloc(i32, table.columns);
        errdefer a.free(widths);
        @memset(widths, 2 * key.pad_x + 1);
        const heights = try a.alloc(i32, table.rows.items.len);
        errdefer a.free(heights);
        const lines = try a.alloc(i32, table.rows.items.len);
        errdefer a.free(lines);
        for (table.rows.items, 0..) |row, ri| {
            var line_h: i32 = 1;
            var count: usize = 1;
            for (row.cells, 0..) |cell, ci| {
                count = @max(count, cell.fragments.items.len);
                for (cell.fragments.items) |fragment| {
                    const size = measure(context, text[fragment.start..fragment.end], ri == 0);
                    widths[ci] = @max(widths[ci], size.width + 2 * key.pad_x + 1);
                    line_h = @max(line_h, size.height);
                }
            }
            lines[ri] = line_h;
            heights[ri] = @as(i32, @intCast(count)) * line_h + 2 * key.pad_y + 1;
        }
        var content_w: i32 = 1;
        for (widths) |w| content_w += w;
        const slot = try self.entries.getOrPut(a, offset);
        if (slot.found_existing) slot.value_ptr.layout.deinit(a);
        slot.value_ptr.* = .{ .hash = hash, .key = key, .layout = .{ .table = table, .widths = widths, .heights = heights, .lines = lines, .content_w = content_w, .view_w = key.view_w, .scroll = tableScroll(scroll, 0, 0, content_w, key.view_w) } };
        self.builds += 1;
        return &slot.value_ptr.layout;
    }
};

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

test "table cells preserve code pipes and one-column console rows" {
    var ranges: [2]Range = undefined;
    try std.testing.expectEqual(@as(usize, 2), cells(std.unicode.utf8ToUtf16LeStringLiteral("| ``x|y`` | z |"), &ranges));
    try std.testing.expect(consoleTableRow(std.unicode.utf8ToUtf16LeStringLiteral("│ one column │")));
    try std.testing.expect(!consoleTableRow(std.unicode.utf8ToUtf16LeStringLiteral("│ tool output")));
}

test "ISSUE-421 shared pipe and terminal fixtures retain every cell and source fragment" {
    const a = std.testing.allocator;
    const expected = [_][]const u8{ "", "Flag on", "Flag off", "Desktop", "0.006 to 0.007 over 13 cold loads", "0.058 to 0.064 over 5 cold loads", "Phone, 4x CPU", "0 over 5 cold loads", "0 over 5 cold loads" };
    inline for (.{ @embedFile("testdata/chat-table-fixture.md"), @embedFile("testdata/chat-table-fixture.terminal.txt") }, 0..) |fixture, fi| {
        const text = try std.unicode.utf8ToUtf16LeAlloc(a, fixture);
        defer a.free(text);
        var out: [32]Block = undefined;
        const n = blocks(text, 17, .prose, &out);
        var found: usize = 0;
        for (out[0..n]) |block| {
            if (block.kind != .table) continue;
            found += 1;
            const source = text[block.start - 17 ..][0..block.len];
            var table = try parseTable(a, source);
            defer table.deinit(a);
            try std.testing.expectEqual(@as(usize, 3), table.columns);
            try std.testing.expectEqual(@as(usize, 3), table.rows.items.len);
            try std.testing.expectEqualStrings(if (fi == 0) "pipe" else "box", @tagName(table.source));
            for (table.rows.items, 0..) |row, ri| for (row.cells, 0..) |cell, ci| {
                var joined: std.ArrayList(u16) = .empty;
                defer joined.deinit(a);
                for (cell.fragments.items) |fragment| {
                    try std.testing.expect(fragment.start <= fragment.end and fragment.end <= source.len);
                    if (fragment.start == fragment.end) continue;
                    if (joined.items.len > 0) try joined.append(a, ' ');
                    try joined.appendSlice(a, source[fragment.start..fragment.end]);
                }
                const utf8 = try std.unicode.utf16LeToUtf8Alloc(a, joined.items);
                defer a.free(utf8);
                try std.testing.expectEqualStrings(expected[ri * 3 + ci], utf8);
                try std.testing.expectEqual(@as(usize, if (fi == 1 and ri == 2) 2 else 1), cell.fragments.items.len);
            };
        }
        try std.testing.expectEqual(@as(usize, 1), found);
    }
}

test "ISSUE-421 pipe rows with missing or extra cells stay in the table" {
    const a = std.testing.allocator;
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| A | B | C |\n|---|---|---|\n| x |\n| 1 | 2 | 3 | 4 |\nafter");
    var out: [8]Block = undefined;
    const n = blocks(text, 0, .prose, &out);
    try std.testing.expectEqual(@as(usize, 2), n);
    try std.testing.expectEqual(Kind.table, out[0].kind);
    var table = try parseTable(a, text[out[0].start..][0..out[0].len]);
    defer table.deinit(a);
    try std.testing.expectEqual(@as(usize, 3), table.rows.items.len);
    try std.testing.expectEqual(@as(usize, 0), table.rows.items[1].cells[1].fragments.items.len);
    try std.testing.expectEqual(@as(usize, 3), table.rows.items[2].cells.len);
}

test "ISSUE-421 nested list depth follows the parent indent stack" {
    const a = std.testing.allocator;
    const text = try std.unicode.utf8ToUtf16LeAlloc(a, @embedFile("testdata/chat-table-fixture.md"));
    defer a.free(text);
    var out: [32]Block = undefined;
    const n = blocks(text, 0, .prose, &out);
    var depths: std.ArrayList(u8) = .empty;
    defer depths.deinit(a);
    for (out[0..n]) |block| if (block.kind == .list) {
        try depths.append(a, block.level);
    };
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 1, 1, 0, 1, 2, 2, 1 }, depths.items);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 1 }, depths.items[2..5]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 2, 2, 1 }, depths.items[5..]);
}

test "ISSUE-421 malformed grids are not tables and unseparated body lines are rows" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    for ([_][]const u16{
        w("┌─┬─┐\n│ a │ b │\n└─┘"),
        w("┌─┬─┐\n│ a │\n└─┴─┘"),
        w("┌─┬─┐\n├─┼─┤\n│ a │ b │\n└─┴─┘"),
        w("┌─┬─┐\n│ a │ b │"),
        w("┌─┬─┐\n│ a │ b │\n├oops┤\n└─┴─┘"),
    }) |text| {
        try std.testing.expect(boxTableLength(text) == null);
        var out: [8]Block = undefined;
        const n = blocks(text, 0, .prose, &out);
        for (out[0..n]) |block| try std.testing.expect(block.kind != .table);
    }
    const text = w("┌─┬─┐\n│ h │ h │\n├─┼─┤\n│ a │ b │\n│ c │ d │\n└─┴─┘");
    var table = try parseTable(std.testing.allocator, text);
    defer table.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), table.rows.items.len);
    var spans: [8]Span = undefined;
    const rich = w("| **head** | [site](https://example.test) |\n|---|---|\n| `x` | y |");
    var pipe = try parseTable(std.testing.allocator, rich);
    defer pipe.deinit(std.testing.allocator);
    const fragment = pipe.rows.items[0].cells[1].fragments.items[0];
    const count = inlineSpans(rich[fragment.start..fragment.end], &spans);
    try std.testing.expectEqual(@as(usize, 1), count);
    const target = spans[0].target.?;
    try std.testing.expectEqualSlices(u16, w("https://example.test"), rich[fragment.start + target.start .. fragment.start + target.end]);
}

test "ISSUE-421 horizontal table scrolling clamps and steps in both directions" {
    try std.testing.expectEqual(@as(i32, 54), tableScroll(0, 120, 54, 800, 320));
    try std.testing.expectEqual(@as(i32, 27), tableScroll(0, 60, 54, 800, 320));
    try std.testing.expectEqual(@as(i32, 0), tableScroll(27, -120, 54, 800, 320));
    try std.testing.expectEqual(@as(i32, 480), tableScroll(470, 120, 54, 800, 320));
    try std.testing.expectEqual(@as(i32, 0), tableScroll(100, 120, 54, 100, 320));
    try std.testing.expectEqual(@as(i32, 0), tableScroll(100, 0, 54, 100, 320));
    try std.testing.expectEqual(@as(i32, 480), tableScroll(0, std.math.maxInt(i32), std.math.maxInt(i32), 800, 320));
}

test "ISSUE-458 scrollbar geometry sizes and positions the thumb for real overflowing widths only" {
    const bar = TableScrollbar.init(1447, 434, 100, 0, 16, 24).?;
    try std.testing.expectEqual(@as(i32, 130), bar.thumb_w);
    try std.testing.expectEqual(@as(i32, 0), bar.thumb_x);
    try std.testing.expectEqual(@as(i32, 1013), bar.max_scroll);
    const middle = TableScrollbar.init(1447, 434, 100, 506, 16, 24).?;
    try std.testing.expectEqual(@as(i32, 151), middle.thumb_x);
    const end = TableScrollbar.init(1447, 434, 100, 1013, 16, 24).?;
    try std.testing.expectEqual(@as(i32, 434), end.thumb_x + end.thumb_w);
    try std.testing.expectEqual(@as(i32, 173), TableScrollbar.init(1087, 434, 100, 0, 16, 24).?.thumb_w);
    try std.testing.expect(TableScrollbar.init(400, 434, 100, 0, 16, 24) == null);
    try std.testing.expect(TableScrollbar.init(434, 434, 100, 0, 16, 24) == null);
    try std.testing.expect(TableScrollbar.init(1447, 0, 100, 0, 16, 24) == null);
}

test "ISSUE-458 hit testing distinguishes the thumb track and body including boundaries" {
    const bar = TableScrollbar.init(1447, 434, 100, 506, 16, 24).?;
    try std.testing.expectEqual(TableScrollHit.body, bar.hit(200, 99));
    try std.testing.expectEqual(TableScrollHit.track_before, bar.hit(150, 100));
    try std.testing.expectEqual(TableScrollHit.thumb, bar.hit(151, 100));
    try std.testing.expectEqual(TableScrollHit.thumb, bar.hit(280, 115));
    try std.testing.expectEqual(TableScrollHit.track_after, bar.hit(281, 100));
    try std.testing.expectEqual(TableScrollHit.outside, bar.hit(434, 100));
    try std.testing.expectEqual(TableScrollHit.outside, bar.hit(-1, 100));
    try std.testing.expectEqual(TableScrollHit.outside, bar.hit(200, 116));
    try std.testing.expectEqual(TableScrollHit.outside, bar.hit(200, -1));
}

test "ISSUE-458 dragging maps pointer travel to content and reaches the last column at both clamps" {
    const bar = TableScrollbar.init(1447, 434, 100, 0, 16, 24).?;
    try std.testing.expectEqual(@as(i32, 506), bar.drag(0, 152));
    try std.testing.expectEqual(@as(i32, 1013), bar.drag(0, 304));
    try std.testing.expectEqual(@as(i32, 0), bar.drag(1013, -304));
    try std.testing.expectEqual(@as(i32, 0), bar.drag(506, -10000));
    try std.testing.expectEqual(@as(i32, 1013), bar.drag(506, 10000));
    try std.testing.expectEqual(@as(i32, 1013), bar.drag(0, std.math.maxInt(i32)));
    try std.testing.expectEqual(@as(i32, 0), bar.drag(1013, std.math.minInt(i32)));
    const tiny = TableScrollbar.init(1447, 1, 100, 500, 16, 24).?;
    try std.testing.expectEqual(@as(i32, 500), tiny.drag(500, 200));
}

test "ISSUE-458 clicking either side of the track pages by the viewport and clamps" {
    const bar = TableScrollbar.init(1447, 434, 100, 506, 16, 24).?;
    try std.testing.expectEqual(@as(i32, 940), bar.page(506, bar.hit(433, 100)));
    try std.testing.expectEqual(@as(i32, 72), bar.page(506, bar.hit(0, 100)));
    try std.testing.expectEqual(@as(i32, 1013), bar.page(940, .track_after));
    try std.testing.expectEqual(@as(i32, 0), bar.page(72, .track_before));
    try std.testing.expectEqual(@as(i32, 506), bar.page(506, .thumb));
    try std.testing.expectEqual(@as(i32, 506), bar.page(506, .body));
}

test "ISSUE-458 wheel routes only sideways input to the overflowing table under the pointer" {
    const bar = TableScrollbar.init(1447, 434, 100, 0, 16, 24).?;
    try std.testing.expectEqual(@as(?i32, -120), bar.wheel(30, 40, false, true, 120));
    try std.testing.expectEqual(@as(?i32, 120), bar.wheel(30, 40, true, false, 120));
    try std.testing.expectEqual(@as(?i32, -60), bar.wheel(30, 115, true, true, -60));
    try std.testing.expect(bar.wheel(30, 40, false, false, 120) == null);
    try std.testing.expect(bar.wheel(434, 40, true, false, 120) == null);
    try std.testing.expect(bar.wheel(30, 116, false, true, 120) == null);
    try std.testing.expect(bar.wheel(-1, 40, true, false, 120) == null);
}

test "ISSUE-458 table offsets survive refresh prepend and resize without mixing messages or tables" {
    const a = std.testing.allocator;
    var cache: TableCache = .{};
    defer cache.deinit(a);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| Long heading | Other heading |\n|---|---|\n| cell | value |");
    const Measure = struct {
        fn cell(_: void, part: []const u16, _: bool) TableSize {
            return .{ .width = @as(i32, @intCast(part.len)) * 20, .height = 20 };
        }
    };
    var key = TableKey{ .view_w = 100, .font_pt = 13, .scale = 1024, .pad_x = 10, .pad_y = 6 };
    const before = [_]Block{
        .{ .start = 10, .len = text.len, .role = .code, .kind = .table, .first = true, .source_offset = 900, .source_end = 1000 },
        .{ .start = 100, .len = text.len, .role = .code, .kind = .table, .source_offset = 900, .source_end = 1000 },
        .{ .start = 200, .len = text.len, .role = .code, .kind = .table, .first = true, .source_offset = 1000, .source_end = 1100 },
        .{ .start = 300, .len = text.len, .role = .code, .kind = .table, .first = true, .source_offset = 1000, .source_end = 1100, .segment = 2 },
        .{ .start = 400, .len = text.len, .role = .code, .kind = .table, .source_offset = 1000, .source_end = 1100, .segment = 2 },
    };
    for (before, 0..) |block, i| {
        const layout = try cache.layout(a, text, block.start, key, {}, Measure.cell);
        layout.scroll = @intCast(100 + i * 50);
    }
    cache.refresh(a, &before, &before);
    try std.testing.expectEqual(@as(i32, 100), cache.entries.getPtr(10).?.layout.scroll);
    var after = before;
    for (&after) |*block| block.start += 300;
    cache.refresh(a, &before, &after);
    for (after, 0..) |block, i| {
        const layout = try cache.layout(a, text, block.start, key, {}, Measure.cell);
        try std.testing.expectEqual(@as(i32, @intCast(100 + i * 50)), layout.scroll);
    }
    try std.testing.expect(!cache.entries.contains(10));
    const layout = cache.entries.getPtr(310).?.layout;
    key.view_w = layout.content_w - 25;
    const resized = try cache.layout(a, text, 310, key, {}, Measure.cell);
    try std.testing.expectEqual(@as(i32, 25), resized.scroll);
    key.view_w = resized.content_w + 1;
    const narrow = try cache.layout(a, text, 310, key, {}, Measure.cell);
    try std.testing.expectEqual(@as(i32, 0), narrow.scroll);
    try std.testing.expect(narrow.scrollbar(16, 24) == null);
    cache.refresh(a, &after, &.{});
    try std.testing.expectEqual(@as(u32, 0), cache.entries.count());
}

test "ISSUE-421 rich cells retain Unicode code pipes empty cells and separator-like data" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const text = w("| Name | Value |\n|---|---|\n| 中文😀 | café |\n| ``x|y`` | |\n|---|---|");
    var table = try parseTable(std.testing.allocator, text);
    defer table.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 4), table.rows.items.len);
    for ([_][]const u16{ w("中文😀"), w("café"), w("``x|y``"), w(""), w("---"), w("---") }, 0..) |expected, i| {
        const fragment = table.rows.items[1 + i / 2].cells[i % 2].fragments.items[0];
        try std.testing.expectEqualSlices(u16, expected, text[fragment.start..fragment.end]);
    }
}

test "IGSH-537 exact reply preserves the full link target and literal code" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const text = w("Your link had a slash where an underscore belongs. The working link is https://claude.ai/code/session_01N1njvWuiAc1XNXRSYaUTCv (with `session_`, not `session/`).");
    const url = w("https://claude.ai/code/session_01N1njvWuiAc1XNXRSYaUTCv");
    var out: [80]Span = undefined;
    const n = inlineSpans(text, &out);
    var links: usize = 0;
    var codes: usize = 0;
    for (out[0..n]) |span| {
        try std.testing.expect(!span.style.italic);
        if (span.target) |target| {
            links += 1;
            try std.testing.expectEqualSlices(u16, url, text[target.start..target.end]);
            try std.testing.expectEqualSlices(u16, url, text[span.text.start..span.text.end]);
        }
        if (span.style.code) {
            try std.testing.expectEqualSlices(u16, if (codes == 0) w("session_") else w("session/"), text[span.text.start..span.text.end]);
            codes += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 1), links);
    try std.testing.expectEqual(@as(usize, 2), codes);
}

test "IGSH-537 code spans bind before emphasis and retain session_ and escapes" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const cases = [_]struct { text: []const u16, code: []const u16 }{
        .{ .text = w("`session_`"), .code = w("session_") },
        .{ .text = w("_before `session_` after_"), .code = w("session_") },
        .{ .text = w("`a\\*b_`"), .code = w("a\\*b_") },
        .{ .text = w("``session_`_*``"), .code = w("session_`_*") },
        .{ .text = w("`https://example.test/a_b_c`"), .code = w("https://example.test/a_b_c") },
    };
    for (cases) |case| {
        var out: [32]Span = undefined;
        const n = inlineSpans(case.text, &out);
        var codes: usize = 0;
        for (out[0..n]) |span| {
            if (!span.style.code) continue;
            codes += 1;
            try std.testing.expect(span.target == null);
            try std.testing.expectEqualSlices(u16, case.code, case.text[span.text.start..span.text.end]);
        }
        try std.testing.expectEqual(@as(usize, 1), codes);
    }
}

test "IGSH-537 snake_case_word stays plain while real underscore emphasis stays italic" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const cases = [_]struct { text: []const u16, visible: []const u16, italic: bool }{
        .{ .text = w("snake_case_word"), .visible = w("snake_case_word"), .italic = false },
        .{ .text = w("foo_bar"), .visible = w("foo_bar"), .italic = false },
        .{ .text = w("foo__bar__baz"), .visible = w("foo__bar__baz"), .italic = false },
        .{ .text = w("_real emphasis_"), .visible = w("real emphasis"), .italic = true },
        .{ .text = w("_foo_bar_baz_"), .visible = w("foo_bar_baz"), .italic = true },
        .{ .text = w("_ two_"), .visible = w("_ two_"), .italic = false },
        .{ .text = w("_two _"), .visible = w("_two _"), .italic = false },
        .{ .text = w("a_!b!_c"), .visible = w("a_!b!_c"), .italic = false },
        .{ .text = w("中文_词_中文"), .visible = w("中文_词_中文"), .italic = false },
        .{ .text = w("_\u{A0}word_"), .visible = w("_\u{A0}word_"), .italic = false },
    };
    for (cases) |case| {
        var out: [32]Span = undefined;
        const n = inlineSpans(case.text, &out);
        var visible: [64]u16 = undefined;
        var len: usize = 0;
        for (out[0..n]) |span| {
            try std.testing.expectEqual(case.italic, span.style.italic);
            try std.testing.expect(!span.style.bold and !span.style.code and span.target == null);
            const part = case.text[span.text.start..span.text.end];
            @memcpy(visible[len..][0..part.len], part);
            len += part.len;
        }
        try std.testing.expectEqualSlices(u16, case.visible, visible[0..len]);
    }
}

test "IGSH-537 atomic URLs retain two underscores and trim trailing punctuation" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const url = w("https://example.test/a_b_c");
    for ([_][]const u16{
        w("https://example.test/a_b_c)"),
        w("https://example.test/a_b_c."),
        w("(https://example.test/a_b_c)."),
        w("<https://example.test/a_b_c>"),
        w("www.example.test/a_b_c."),
    }, 0..) |text, i| {
        var out: [32]Span = undefined;
        const n = inlineSpans(text, &out);
        var links: usize = 0;
        for (out[0..n]) |span| {
            try std.testing.expect(!span.style.italic);
            if (span.target) |target| {
                links += 1;
                const expected = if (i == 4) w("www.example.test/a_b_c") else url;
                try std.testing.expectEqualSlices(u16, expected, text[target.start..target.end]);
                try std.testing.expectEqualSlices(u16, expected, text[span.text.start..span.text.end]);
            }
        }
        try std.testing.expectEqual(@as(usize, 1), links);
    }
    const angle = w("<https://example.test/a_b_c.>");
    var out: [8]Span = undefined;
    try std.testing.expectEqual(@as(usize, 1), inlineSpans(angle, &out));
    const target = out[0].target.?;
    try std.testing.expectEqualSlices(u16, w("https://example.test/a_b_c."), angle[target.start..target.end]);
}

test "IGSH-537 emphasis searches skip atomic code and links without changing stars" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    for ([_][]const u16{ w("*before `*` after*"), w("_before `session_` after_") }) |text| {
        var out: [32]Span = undefined;
        const n = inlineSpans(text, &out);
        for (out[0..n]) |span| try std.testing.expect(span.style.italic);
        try std.testing.expect(out[n - 1].text.end == text.len - 1);
    }
    const text = w("_before https://example.test/a_b_c after_");
    var out: [32]Span = undefined;
    const n = inlineSpans(text, &out);
    var links: usize = 0;
    for (out[0..n]) |span| {
        try std.testing.expect(span.style.italic);
        if (span.target) |target| {
            links += 1;
            try std.testing.expectEqualSlices(u16, w("https://example.test/a_b_c"), text[target.start..target.end]);
        }
    }
    try std.testing.expectEqual(@as(usize, 1), links);
    const stars = w("*italic* **bold** a*b*c");
    const count = inlineSpans(stars, &out);
    try std.testing.expectEqual(@as(usize, 6), count);
    try std.testing.expect(out[0].style.italic);
    try std.testing.expect(out[2].style.bold);
    try std.testing.expect(out[4].style.italic);
    const bold = w("__real emphasis__");
    try std.testing.expectEqual(@as(usize, 1), inlineSpans(bold, &out));
    try std.testing.expect(out[0].style.bold);
}

test "IGSH-537 underscore flanking recognizes Unicode punctuation and symbols" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    for ([_][]const u16{ w("«_word_»"), w("😀_word_😀"), w("_word_。") }) |text| {
        var out: [16]Span = undefined;
        const n = inlineSpans(text, &out);
        var italics: usize = 0;
        for (out[0..n]) |span| {
            if (!span.style.italic) continue;
            italics += 1;
            try std.testing.expectEqualSlices(u16, w("word"), text[span.text.start..span.text.end]);
        }
        try std.testing.expectEqual(@as(usize, 1), italics);
    }
    const text = w("word_词_word");
    var out: [16]Span = undefined;
    const n = inlineSpans(text, &out);
    for (out[0..n]) |span| try std.testing.expect(!span.style.italic);
}
