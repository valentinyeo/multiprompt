const std = @import("std");
const md = @import("chat_markdown.zig");
const link_detect = @import("link_detect.zig");
const chat_style = @import("chat_style.zig");

pub const FOLD_LINES: usize = 3;
pub const BAR_PX: i32 = 3;
pub const INSET_PAD_X: i32 = 10;
pub const INSET_PAD_Y: i32 = 8;
pub const INSET_RADIUS: i32 = 8;
pub const SECTION_GAP: i32 = 8;
pub const PARA_GAP: i32 = 6;
pub const TOGGLE_GAP: i32 = 4;
pub const LIST_INDENT_STEP: i32 = 22;
pub const LIST_MARKER_W: i32 = 26;

pub const SHOW_MORE = std.unicode.utf8ToUtf16LeStringLiteral("Show more");
pub const SHOW_LESS = std.unicode.utf8ToUtf16LeStringLiteral("Show less");
pub const ELLIPSIS = std.unicode.utf8ToUtf16LeStringLiteral("\u{2026}");
pub const BULLET = std.unicode.utf8ToUtf16LeStringLiteral("\u{2022}");

pub const Range = md.Range;
pub const Box = struct { left: i32 = 0, top: i32 = 0, right: i32 = 0, bottom: i32 = 0 };
pub const Size = struct { width: i32, height: i32 };

pub const Parts = struct {
    prefix: Range,
    quote: Range,
    suffix: Range,
};

pub const Unquoted = struct {
    text: []u16,
    map: []usize,

    pub fn deinit(self: *Unquoted, a: std.mem.Allocator) void {
        a.free(self.text);
        a.free(self.map);
    }
};

pub const Metrics = struct {
    line_h: i32,
    toggle_h: i32,
    para_gap: i32,
    list_indent: i32,
    list_marker_w: i32,
    toggle_gap: i32,
    toggle_more_w: i32 = 0,
    toggle_less_w: i32 = 0,
};

pub const Marker = struct {
    x: i32,
    width: i32,
    bullet: bool,
    text: Range,
};

pub const Run = struct {
    text: Range,
    x: i32,
    width: i32,
    style: md.Style,
    level: u3,
    target: ?Range = null,
};

pub const VisualLine = struct {
    y: i32,
    height: i32,
    indent_x: i32,
    first_run: usize,
    run_count: usize,
    marker: ?Marker = null,
    ellipsis_x: ?i32 = null,
};

pub const Layout = struct {
    lines: []VisualLine,
    runs: []Run,
    visible_lines: usize,
    total_lines: usize,
    foldable: bool,
    expanded: bool,
    natural_w: i32,
    content_h: i32,
    total_h: i32,
    toggle_rect: ?Box,

    pub fn deinit(self: *Layout, a: std.mem.Allocator) void {
        a.free(self.lines);
        a.free(self.runs);
    }
};

pub const Colors = struct {
    inset_bg: u32,
    bar: u32,
    text: u32,
    bold_text: u32,
    link: u32,
    toggle: u32,
};

fn blendChannel(a: u32, b: u32, alpha: u32) u32 {
    return (a * (255 - alpha) + b * alpha + 127) / 255;
}

pub fn blend(a: u32, b: u32, alpha: u32) u32 {
    return blendChannel(a & 0xFF, b & 0xFF, alpha) |
        (blendChannel((a >> 8) & 0xFF, (b >> 8) & 0xFF, alpha) << 8) |
        (blendChannel((a >> 16) & 0xFF, (b >> 16) & 0xFF, alpha) << 16);
}

pub fn colors(user_bg: u32, fg: u32, accent: u32, light_theme: bool) Colors {
    const inset_bg = chat_style.shift(user_bg, 10);
    return .{
        .inset_bg = inset_bg,
        .bar = blend(inset_bg, accent, if (light_theme) 200 else 190),
        .text = blend(inset_bg, fg, 168),
        .bold_text = blend(inset_bg, fg, if (light_theme) 210 else 215),
        .link = accent,
        .toggle = blend(inset_bg, accent, if (light_theme) 210 else 215),
    };
}

pub const ToggleStore = struct {
    keys: [64]u64 = @splat(0),
    len: usize = 0,

    pub fn isOpen(self: *const ToggleStore, key: u64) bool {
        if (key == 0) return false;
        for (self.keys[0..self.len]) |entry| {
            if (entry == key) return true;
        }
        return false;
    }

    pub fn setOpen(self: *ToggleStore, key: u64, open: bool) void {
        if (key == 0) return;
        for (self.keys[0..self.len], 0..) |entry, i| {
            if (entry != key) continue;
            if (!open) {
                if (i + 1 < self.len) std.mem.copyForwards(u64, self.keys[i .. self.len - 1], self.keys[i + 1 .. self.len]);
                self.len -= 1;
            }
            return;
        }
        if (!open) return;
        if (self.len == self.keys.len) {
            std.mem.copyForwards(u64, self.keys[0 .. self.keys.len - 1], self.keys[1..]);
            self.len -= 1;
        }
        self.keys[self.len] = key;
        self.len += 1;
    }

    pub fn toggle(self: *ToggleStore, key: u64) bool {
        const next = !self.isOpen(key);
        self.setOpen(key, next);
        return next;
    }

    pub fn clear(self: *ToggleStore) void {
        self.len = 0;
    }
};

var g_open: ToggleStore = .{};

pub fn blockKey(block: md.Block, text: []const u16) u64 {
    var hasher = std.hash.Wyhash.init(0x9E3779B97F4A7C15);
    hasher.update(std.mem.asBytes(&block.message_id));
    hasher.update(std.mem.asBytes(&block.source_offset));
    hasher.update(std.mem.asBytes(&block.source_end));
    hasher.update(std.mem.sliceAsBytes(text));
    const h = hasher.final();
    return if (h == 0) 1 else h;
}

pub fn isOpen(key: u64) bool {
    return g_open.isOpen(key);
}

pub fn setOpen(key: u64, open: bool) void {
    g_open.setOpen(key, open);
}

pub fn toggle(key: u64) bool {
    return g_open.toggle(key);
}

pub fn clearOpen() void {
    g_open.clear();
}

const LineSlice = struct { start: usize, end: usize, next: usize };

fn nextLine(text: []const u16, pos: usize) LineSlice {
    var end = pos;
    while (end < text.len and text[end] != '\r' and text[end] != '\n') : (end += 1) {}
    var next = end;
    if (next < text.len and text[next] == '\r') next += 1;
    if (next < text.len and text[next] == '\n') next += 1;
    return .{ .start = pos, .end = end, .next = next };
}

fn hasNonSpace(text: []const u16) bool {
    for (text) |c| {
        if (c != ' ' and c != '\t' and c != '\r' and c != '\n') return true;
    }
    return false;
}

fn quoteMarkerOffset(line: []const u16) ?usize {
    var p: usize = 0;
    while (p < line.len and p < 3 and line[p] == ' ') : (p += 1) {}
    if (p < line.len and line[p] == '>') {
        if (p + 1 == line.len or line[p + 1] == ' ' or line[p + 1] == '\t' or line[p + 1] == '>') return p;
    }
    return null;
}

fn leadingSkillQuoteOffset(line: []const u16) ?struct { skill_end: usize, quote_pos: usize } {
    if (line.len < 4 or (line[0] != '/' and line[0] != '$')) return null;
    var i: usize = 1;
    while (i < line.len and line[i] != ' ' and line[i] != '\t') : (i += 1) {}
    if (i == 1 or i >= line.len) return null;
    const skill_end = i;
    while (i < line.len and (line[i] == ' ' or line[i] == '\t')) : (i += 1) {}
    if (i < line.len and line[i] == '>' and (i + 1 == line.len or line[i + 1] == ' ' or line[i + 1] == '\t' or line[i + 1] == '>')) {
        return .{ .skill_end = skill_end, .quote_pos = i };
    }
    return null;
}

fn markerContentStart(line: []const u16, gt: usize) usize {
    const after = gt + 1;
    if (after < line.len and line[after] == ' ') return after + 1;
    return after;
}

fn trailingEllipsisSuffix(content: []const u16) ?usize {
    var i: usize = 0;
    while (i < content.len and (content[i] == ' ' or content[i] == '\t')) : (i += 1) {}
    if (i < content.len and content[i] == 0x2026) {
        i += 1;
    } else if (i + 3 <= content.len and content[i] == '.' and content[i + 1] == '.' and content[i + 2] == '.') {
        i += 3;
    } else return null;
    if (i >= content.len or (content[i] != ' ' and content[i] != '\t')) return null;
    while (i < content.len and (content[i] == ' ' or content[i] == '\t')) : (i += 1) {}
    if (i < content.len and hasNonSpace(content[i..])) return i;
    return null;
}

fn trimRightLineBreaks(text: []const u16, end: usize) usize {
    var e = end;
    while (e > 0 and (text[e - 1] == '\r' or text[e - 1] == '\n')) : (e -= 1) {}
    return e;
}

fn skipBlankLines(text: []const u16, start: usize) usize {
    var pos = start;
    while (pos < text.len) {
        const line = nextLine(text, pos);
        if (hasNonSpace(text[line.start..line.end])) return pos;
        if (line.next <= pos) break;
        pos = line.next;
    }
    return text.len;
}

pub fn parse(text: []const u16) ?Parts {
    if (text.len == 0) return null;
    var pos: usize = 0;
    var prefix = Range{ .start = 0, .end = 0 };
    var quote_start: ?usize = null;
    var quote_end: usize = 0;
    var prev_quote_end: usize = 0;
    var has_content = false;
    while (pos < text.len) {
        const line = nextLine(text, pos);
        const slice = text[line.start..line.end];
        if (line.start == 0) {
            if (leadingSkillQuoteOffset(slice)) |found| {
                prefix = .{ .start = 0, .end = found.skill_end };
                quote_start = found.quote_pos;
                const cstart = markerContentStart(slice, found.quote_pos);
                has_content = hasNonSpace(slice[cstart..]);
                quote_end = line.end;
                prev_quote_end = line.end;
                pos = line.next;
                break;
            }
        }
        if (quoteMarkerOffset(slice)) |gt| {
            const p_end = trimRightLineBreaks(text, line.start);
            prefix = if (hasNonSpace(text[0..p_end])) Range{ .start = 0, .end = p_end } else Range{ .start = 0, .end = 0 };
            quote_start = line.start;
            const cstart = markerContentStart(slice, gt);
            has_content = hasNonSpace(slice[cstart..]);
            quote_end = line.end;
            prev_quote_end = line.end;
            pos = line.next;
            break;
        }
        if (line.next <= pos) break;
        pos = line.next;
    }
    const q_start = quote_start orelse return null;
    while (pos < text.len) {
        const line = nextLine(text, pos);
        const slice = text[line.start..line.end];
        const gt = quoteMarkerOffset(slice) orelse break;
        const cstart = markerContentStart(slice, gt);
        const content = slice[cstart..];
        if (has_content) {
            if (trailingEllipsisSuffix(content)) |rel| {
                const more_quotes = if (line.next < text.len) blk: {
                    const peek = nextLine(text, line.next);
                    break :blk quoteMarkerOffset(text[peek.start..peek.end]) != null;
                } else false;
                if (!more_quotes) {
                    const suffix_start = line.start + cstart + rel;
                    return .{
                        .prefix = prefix,
                        .quote = .{ .start = q_start, .end = prev_quote_end },
                        .suffix = .{ .start = suffix_start, .end = text.len },
                    };
                }
            }
        }
        if (hasNonSpace(content)) has_content = true;
        prev_quote_end = line.end;
        quote_end = line.end;
        if (line.next <= pos) break;
        pos = line.next;
    }
    if (!has_content) return null;
    const suffix_start = skipBlankLines(text, pos);
    const suffix = if (suffix_start < text.len) Range{ .start = suffix_start, .end = text.len } else Range{ .start = text.len, .end = text.len };
    return .{
        .prefix = prefix,
        .quote = .{ .start = q_start, .end = quote_end },
        .suffix = suffix,
    };
}

pub fn unquote(a: std.mem.Allocator, text: []const u16, quote: Range) !Unquoted {
    var out_text: std.ArrayList(u16) = .empty;
    errdefer out_text.deinit(a);
    var out_map: std.ArrayList(usize) = .empty;
    errdefer out_map.deinit(a);
    var pos = quote.start;
    var first = true;
    while (pos <= quote.end and pos < text.len) {
        const line = nextLine(text, pos);
        const line_end = @min(line.end, quote.end);
        const slice = text[line.start..line_end];
        if (!first) {
            try out_text.append(a, '\n');
            try out_map.append(a, if (line.start > 0) line.start - 1 else quote.start);
        }
        first = false;
        const cstart = if (quoteMarkerOffset(slice)) |gt| markerContentStart(slice, gt) else 0;
        for (slice[cstart..], 0..) |c, i| {
            try out_text.append(a, c);
            try out_map.append(a, line.start + cstart + i);
        }
        if (line.end >= quote.end or line.next <= pos) break;
        pos = line.next;
    }
    return .{
        .text = try out_text.toOwnedSlice(a),
        .map = try out_map.toOwnedSlice(a),
    };
}

fn stripPreviewLinePrefix(text: []const u16) []const u16 {
    var pos: usize = 0;
    while (pos < text.len and (text[pos] == ' ' or text[pos] == '\t')) : (pos += 1) {}
    while (pos < text.len and text[pos] == '>') {
        pos += 1;
        while (pos < text.len and (text[pos] == ' ' or text[pos] == '\t')) : (pos += 1) {}
    }
    var hashes: usize = 0;
    while (pos + hashes < text.len and hashes < 6 and text[pos + hashes] == '#') : (hashes += 1) {}
    if (hashes > 0 and pos + hashes < text.len and text[pos + hashes] == ' ') {
        pos += hashes + 1;
        while (pos < text.len and (text[pos] == ' ' or text[pos] == '\t')) : (pos += 1) {}
    }
    if (pos + 2 <= text.len and (text[pos] == '-' or text[pos] == '*' or text[pos] == '+') and text[pos + 1] == ' ') {
        pos += 2;
    }
    return text[pos..];
}

const StripResult = struct { len: usize, truncated: bool };

fn stripInlineMarkdownInner(text: []const u16, out: []u16) StripResult {
    const body = stripPreviewLinePrefix(text);
    if (body.len == 0 or out.len == 0) return .{ .len = 0, .truncated = body.len > 0 };
    var span_buf: [512]md.Span = undefined;
    var heap_spans: ?[]md.Span = null;
    defer if (heap_spans) |buf| std.heap.page_allocator.free(buf);
    const spans = if (body.len <= span_buf.len) span_buf[0..] else blk: {
        const allocated = std.heap.page_allocator.alloc(md.Span, body.len) catch {
            var n = @min(body.len, out.len);
            if (n > 0 and std.unicode.utf16IsHighSurrogate(body[n - 1])) n -= 1;
            @memcpy(out[0..n], body[0..n]);
            return .{ .len = n, .truncated = n < body.len };
        };
        heap_spans = allocated;
        break :blk allocated;
    };
    const count = md.inlineSpans(body, spans);
    var n: usize = 0;
    var prev_space = false;
    var truncated = false;
    for (spans[0..count]) |span| {
        var i = span.text.start;
        while (i < span.text.end) : (i += 1) {
            const c = body[i];
            if (c == '\r') continue;
            const is_space = c == ' ' or c == '\t' or c == '\n';
            if (is_space) {
                if (n == 0 or prev_space) continue;
                prev_space = true;
                if (n >= out.len) {
                    truncated = true;
                    break;
                }
                out[n] = ' ';
                n += 1;
                continue;
            }
            prev_space = false;
            const pair = std.unicode.utf16IsHighSurrogate(c) and i + 1 < span.text.end;
            const need: usize = if (pair) 2 else 1;
            if (n + need > out.len) {
                truncated = true;
                break;
            }
            out[n] = c;
            n += 1;
            if (pair) {
                i += 1;
                out[n] = body[i];
                n += 1;
            }
        }
        if (truncated) break;
    }
    while (n > 0 and out[n - 1] == ' ') n -= 1;
    return .{ .len = n, .truncated = truncated };
}

pub fn stripInlineMarkdown(text: []const u16, out: []u16) usize {
    return stripInlineMarkdownInner(text, out).len;
}

pub fn formatReplyPreview(text: []const u16, out: []u16) usize {
    if (out.len < 4) return 0;
    out[0] = 0x21a9;
    out[1] = ' ';
    const stripped = stripInlineMarkdownInner(text, out[2 .. out.len - 1]);
    var len = 2 + stripped.len;
    if (stripped.truncated) {
        out[len] = 0x2026;
        len += 1;
    }
    return len;
}

fn fitPrefixLen(
    text: []const u16,
    max_w: i32,
    style: md.Style,
    level: u3,
    ctx: anytype,
    comptime measure: fn (@TypeOf(ctx), []const u16, md.Style, u3) Size,
) usize {
    if (text.len == 0) return 0;
    if (measure(ctx, text, style, level).width <= max_w) return text.len;
    var lo: usize = 0;
    var hi: usize = text.len;
    while (lo < hi) {
        const mid = lo + (hi - lo + 1) / 2;
        if (measure(ctx, text[0..mid], style, level).width <= max_w) {
            lo = mid;
        } else {
            hi = mid - 1;
        }
    }
    var count = @max(@as(usize, 1), lo);
    if (count < text.len and std.unicode.utf16IsHighSurrogate(text[count - 1])) {
        count = if (count > 1) count - 1 else @min(text.len, 2);
    }
    return count;
}

pub fn layout(
    a: std.mem.Allocator,
    unquoted: []const u16,
    max_w: i32,
    metrics: Metrics,
    expanded: bool,
    ctx: anytype,
    comptime measure: fn (@TypeOf(ctx), []const u16, md.Style, u3) Size,
) !Layout {
    const safe_max_w = @max(1, max_w);
    const line_cap = std.mem.count(u16, unquoted, &.{'\n'}) + 1;
    const block_storage = try a.alloc(md.Block, line_cap);
    defer a.free(block_storage);
    const block_count = md.blocks(unquoted, 0, .prose, block_storage);
    var lines_list: std.ArrayList(VisualLine) = .empty;
    errdefer lines_list.deinit(a);
    var runs_list: std.ArrayList(Run) = .empty;
    errdefer runs_list.deinit(a);

    var y: i32 = 0;
    var natural_w: i32 = 0;

    for (block_storage[0..block_count], 0..) |block, bi| {
        if (bi > 0) y += metrics.para_gap;
        const is_list = block.kind == .list;
        const indent_x: i32 = if (is_list) @as(i32, block.level) * metrics.list_indent + metrics.list_marker_w else 0;
        const eff_indent = if (indent_x < safe_max_w - 1) indent_x else 0;
        const content_w = @max(1, safe_max_w - eff_indent);
        const level: u3 = if (block.kind == .heading) @intCast(@min(block.level, 6)) else 0;
        const body_start = if (is_list) block.start + block.prefix else block.start;
        const body_end = block.start + block.len;
        const body = unquoted[body_start..body_end];
        const base_line_h = @max(metrics.line_h, measure(ctx, std.unicode.utf8ToUtf16LeStringLiteral("Ag"), .{ .code = block.role == .code }, level).height);

        const list_marker: ?Marker = if (is_list and eff_indent > 0) .{
            .x = @as(i32, block.level) * metrics.list_indent,
            .width = metrics.list_marker_w,
            .bullet = block.prefix == 2,
            .text = .{ .start = block.start, .end = block.start + block.prefix },
        } else null;

        if (block.role == .code) {
            var pos: usize = 0;
            var line_i: usize = 0;
            while (pos <= body.len) : (line_i += 1) {
                const seg = nextLine(body, pos);
                const line_text = body[seg.start..seg.end];
                var lpos: usize = 0;
                if (line_text.len == 0) {
                    try lines_list.append(a, .{
                        .y = y,
                        .height = base_line_h,
                        .indent_x = eff_indent,
                        .first_run = runs_list.items.len,
                        .run_count = 0,
                        .marker = if (line_i == 0) list_marker else null,
                    });
                    y += base_line_h;
                } else {
                    while (lpos < line_text.len) {
                        const take = fitPrefixLen(line_text[lpos..], content_w, .{ .code = true }, 0, ctx, measure);
                        const w = measure(ctx, line_text[lpos .. lpos + take], .{ .code = true }, 0).width;
                        const first_run = runs_list.items.len;
                        try runs_list.append(a, .{
                            .text = .{ .start = body_start + seg.start + lpos, .end = body_start + seg.start + lpos + take },
                            .x = eff_indent,
                            .width = w,
                            .style = .{ .code = true },
                            .level = 0,
                        });
                        try lines_list.append(a, .{
                            .y = y,
                            .height = base_line_h,
                            .indent_x = eff_indent,
                            .first_run = first_run,
                            .run_count = 1,
                            .marker = if (line_i == 0 and lpos == 0) list_marker else null,
                        });
                        natural_w = @max(natural_w, @min(safe_max_w, eff_indent + w));
                        y += base_line_h;
                        lpos += take;
                    }
                }
                if (seg.end == body.len or seg.next <= pos) break;
                pos = seg.next;
            }
            continue;
        }

        const spans = try a.alloc(md.Span, @max(@as(usize, 1), body.len));
        defer a.free(spans);
        const span_count = md.inlineSpans(body, spans);

        var cur_x: i32 = 0;
        var cur_first_run = runs_list.items.len;
        var cur_run_count: usize = 0;
        var cur_line_h = base_line_h;
        var first_visual_in_block = true;
        var raw_link = link_detect.next(body, 0);

        for (spans[0..span_count]) |span| {
            const space_w = measure(ctx, &.{' '}, span.style, level).width;
            var pos = span.text.start;
            while (pos < span.text.end) {
                if (body[pos] == '\r') {
                    pos += 1;
                    continue;
                }
                if (body[pos] == '\n') {
                    try lines_list.append(a, .{
                        .y = y,
                        .height = cur_line_h,
                        .indent_x = eff_indent,
                        .first_run = cur_first_run,
                        .run_count = cur_run_count,
                        .marker = if (first_visual_in_block) list_marker else null,
                    });
                    natural_w = @max(natural_w, @min(safe_max_w, eff_indent + cur_x));
                    y += cur_line_h;
                    cur_x = 0;
                    cur_first_run = runs_list.items.len;
                    cur_run_count = 0;
                    cur_line_h = base_line_h;
                    first_visual_in_block = false;
                    pos += 1;
                    continue;
                }
                if (body[pos] == ' ' or body[pos] == '\t') {
                    if (cur_x > 0) cur_x += space_w;
                    pos += 1;
                    continue;
                }
                var end = pos + 1;
                while (end < span.text.end and body[end] != ' ' and body[end] != '\t' and body[end] != '\r' and body[end] != '\n') : (end += 1) {}
                var target: ?Range = if (span.target) |t| .{ .start = body_start + t.start, .end = body_start + t.end } else null;
                if (raw_link != null and raw_link.?.end <= pos) raw_link = link_detect.next(body, pos);
                if (target == null and !span.style.code) {
                    if (raw_link) |link| {
                        if (link.start == pos) {
                            target = .{ .start = body_start + link.start, .end = body_start + link.end };
                            end = @min(end, link.end);
                        } else if (link.start > pos and link.start < end) {
                            end = link.start;
                        }
                    }
                }
                const word_size = measure(ctx, body[pos..end], span.style, level);
                if (cur_x > 0 and cur_x + word_size.width > content_w) {
                    try lines_list.append(a, .{
                        .y = y,
                        .height = cur_line_h,
                        .indent_x = eff_indent,
                        .first_run = cur_first_run,
                        .run_count = cur_run_count,
                        .marker = if (first_visual_in_block) list_marker else null,
                    });
                    natural_w = @max(natural_w, @min(safe_max_w, eff_indent + cur_x));
                    y += cur_line_h;
                    cur_x = 0;
                    cur_first_run = runs_list.items.len;
                    cur_run_count = 0;
                    cur_line_h = base_line_h;
                    first_visual_in_block = false;
                }
                while (pos < end) {
                    const avail = @max(1, content_w - cur_x);
                    const take = fitPrefixLen(body[pos..end], avail, span.style, level, ctx, measure);
                    const seg_size = measure(ctx, body[pos .. pos + take], span.style, level);
                    cur_line_h = @max(cur_line_h, seg_size.height);
                    try runs_list.append(a, .{
                        .text = .{ .start = body_start + pos, .end = body_start + pos + take },
                        .x = eff_indent + cur_x,
                        .width = seg_size.width,
                        .style = span.style,
                        .level = level,
                        .target = target,
                    });
                    cur_run_count += 1;
                    cur_x += seg_size.width;
                    pos += take;
                    if (pos < end) {
                        try lines_list.append(a, .{
                            .y = y,
                            .height = cur_line_h,
                            .indent_x = eff_indent,
                            .first_run = cur_first_run,
                            .run_count = cur_run_count,
                            .marker = if (first_visual_in_block) list_marker else null,
                        });
                        natural_w = @max(natural_w, @min(safe_max_w, eff_indent + cur_x));
                        y += cur_line_h;
                        cur_x = 0;
                        cur_first_run = runs_list.items.len;
                        cur_run_count = 0;
                        cur_line_h = base_line_h;
                        first_visual_in_block = false;
                    }
                }
            }
        }

        if (cur_run_count > 0 or first_visual_in_block) {
            try lines_list.append(a, .{
                .y = y,
                .height = cur_line_h,
                .indent_x = eff_indent,
                .first_run = cur_first_run,
                .run_count = cur_run_count,
                .marker = if (first_visual_in_block) list_marker else null,
            });
            natural_w = @max(natural_w, @min(safe_max_w, eff_indent + cur_x));
            y += cur_line_h;
        }
    }

    const total_lines = lines_list.items.len;
    const foldable = total_lines > FOLD_LINES;
    const visible_lines = if (!expanded and foldable) FOLD_LINES else total_lines;

    if (!expanded and foldable) {
        const last = &lines_list.items[visible_lines - 1];
        const ellipsis_w = measure(ctx, ELLIPSIS, .{}, 0).width;
        const limit_x = @max(last.indent_x, safe_max_w - ellipsis_w);
        var end_run = last.first_run + last.run_count;
        while (end_run > last.first_run) {
            const r = &runs_list.items[end_run - 1];
            if (r.x + r.width <= limit_x) {
                last.ellipsis_x = r.x + r.width;
                break;
            }
            if (r.x < limit_x) {
                const avail = limit_x - r.x;
                const slice = unquoted[r.text.start..r.text.end];
                var take = fitPrefixLen(slice, avail, r.style, r.level, ctx, measure);
                var w = measure(ctx, slice[0..take], r.style, r.level).width;
                if (w > avail and take > 0) {
                    take = 0;
                    w = 0;
                }
                if (take > 0) {
                    r.text.end = r.text.start + take;
                    r.width = w;
                    last.ellipsis_x = r.x + w;
                    break;
                }
            }
            end_run -= 1;
        }
        last.run_count = end_run - last.first_run;
        if (last.ellipsis_x == null) last.ellipsis_x = last.indent_x;
        natural_w = @max(natural_w, @min(safe_max_w, last.ellipsis_x.? + ellipsis_w));
    }

    const content_h: i32 = if (visible_lines > 0)
        lines_list.items[visible_lines - 1].y + lines_list.items[visible_lines - 1].height
    else
        0;

    var toggle_rect: ?Box = null;
    var total_h = content_h;
    if (foldable) {
        const label = if (expanded) SHOW_LESS else SHOW_MORE;
        const measured_w = if (expanded) metrics.toggle_less_w else metrics.toggle_more_w;
        const raw_w = if (measured_w > 0) measured_w else measure(ctx, label, .{}, 0).width;
        const tw = @min(safe_max_w, raw_w);
        const top = content_h + metrics.toggle_gap;
        toggle_rect = .{ .left = 0, .top = top, .right = tw, .bottom = top + metrics.toggle_h };
        total_h = top + metrics.toggle_h;
        natural_w = @max(natural_w, tw);
    }

    return .{
        .lines = try lines_list.toOwnedSlice(a),
        .runs = try runs_list.toOwnedSlice(a),
        .visible_lines = visible_lines,
        .total_lines = total_lines,
        .foldable = foldable,
        .expanded = expanded,
        .natural_w = natural_w,
        .content_h = content_h,
        .total_h = total_h,
        .toggle_rect = toggle_rect,
    };
}

pub fn boxInsetX(bar_w: i32, pad_x: i32) i32 {
    return bar_w + pad_x;
}

const FixedMeasure = struct {
    char_w: i32 = 8,
    line_h: i32 = 20,

    fn cell(self: *const FixedMeasure, text: []const u16, _: md.Style, level: u3) Size {
        return .{
            .width = @as(i32, @intCast(text.len)) * self.char_w,
            .height = self.line_h + (if (level > 0) @as(i32, 4) else 0),
        };
    }
};

test "MUBO-237 parses skill-prefixed quote with trailing ellipsis reply into prefix quote and suffix" {
    const a = std.testing.allocator;
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const message = try std.unicode.utf8ToUtf16LeAlloc(
        a,
        "/pstack:poteto-help > **The fix itself is small. The time goes into waiting and checks around it.**\n" ++
            ">\n" ++
            "> How the hours went:\n" ++
            ">\n" ++
            "> 1. **Waiting in line (about 4 hours):** the fix was ready this afternoon. But the system that checks every change was itself broken, so nothing could merge until that was repaired, and that repair failed twice.\n" ++
            ">\n" ++
            "> 2. **Checks (about 1.5 hours):** every change runs the full test set on Windows machines in the cloud, even a small one.\n" ++
            ">\n" ++
            "> 3. **A build error (about 1 hour):** the fix broke the build once, so it had to be corrected and checked again.\n" ++
            ">\n" ++
            "> \u{2026} i thoughtwith pstack thinks speed up now we wait 7  hours for a very  urgent bug fix emergenyc or not?",
    );
    defer a.free(message);
    const parts = parse(message) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, w("/pstack:poteto-help"), message[parts.prefix.start..parts.prefix.end]);
    try std.testing.expectEqualSlices(u16, w("i thoughtwith pstack thinks speed up now we wait 7  hours for a very  urgent bug fix emergenyc or not?"), message[parts.suffix.start..parts.suffix.end]);

    var unq = try unquote(a, message, parts.quote);
    defer unq.deinit(a);

    const m = FixedMeasure{ .char_w = 8, .line_h = 20 };
    const metrics = Metrics{ .line_h = 20, .toggle_h = 18, .para_gap = 6, .list_indent = 22, .list_marker_w = 26, .toggle_gap = 4 };

    var folded = try layout(a, unq.text, 480, metrics, false, &m, FixedMeasure.cell);
    defer folded.deinit(a);
    try std.testing.expect(folded.foldable);
    try std.testing.expectEqual(@as(usize, 3), folded.visible_lines);
    try std.testing.expect(folded.total_lines > 3);
    try std.testing.expect(folded.toggle_rect != null);
    try std.testing.expect(folded.lines[2].ellipsis_x != null);
    const expected_folded_content_h = folded.lines[2].y + folded.lines[2].height;
    try std.testing.expectEqual(expected_folded_content_h, folded.content_h);
    try std.testing.expectEqual(expected_folded_content_h + metrics.toggle_gap + metrics.toggle_h, folded.total_h);

    var bold_runs: usize = 0;
    for (folded.lines[0..folded.visible_lines]) |line| {
        for (folded.runs[line.first_run..][0..line.run_count]) |run| {
            const slice = unq.text[run.text.start..run.text.end];
            try std.testing.expect(std.mem.indexOf(u16, slice, w("**")) == null);
            try std.testing.expect(slice.len == 0 or slice[0] != '>');
            if (run.style.bold) bold_runs += 1;
        }
    }
    try std.testing.expect(bold_runs > 0);

    var expanded = try layout(a, unq.text, 480, metrics, true, &m, FixedMeasure.cell);
    defer expanded.deinit(a);
    try std.testing.expect(expanded.foldable);
    try std.testing.expectEqual(expanded.total_lines, expanded.visible_lines);
    try std.testing.expect(expanded.total_h > folded.total_h);
    try std.testing.expect(expanded.toggle_rect != null);

    var list_markers: usize = 0;
    for (expanded.lines[0..expanded.visible_lines]) |line| {
        if (line.marker != null) list_markers += 1;
        for (expanded.runs[line.first_run..][0..line.run_count]) |run| {
            const slice = unq.text[run.text.start..run.text.end];
            try std.testing.expect(std.mem.indexOf(u16, slice, w("**")) == null);
            try std.testing.expect(slice.len == 0 or slice[0] != '>');
        }
    }
    try std.testing.expectEqual(@as(usize, 3), list_markers);
}

test "MUBO-237 short quotes do not fold and render bullets bold and links cleanly" {
    const a = std.testing.allocator;
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const message = w("> - **Item** with [docs](https://example.test)\n> - Second item\n\nLooks good");
    const parts = parse(message) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 0), parts.prefix.end - parts.prefix.start);
    try std.testing.expectEqualSlices(u16, w("Looks good"), message[parts.suffix.start..parts.suffix.end]);

    var unq = try unquote(a, message, parts.quote);
    defer unq.deinit(a);
    const m = FixedMeasure{ .char_w = 8, .line_h = 20 };
    const metrics = Metrics{ .line_h = 20, .toggle_h = 18, .para_gap = 6, .list_indent = 22, .list_marker_w = 26, .toggle_gap = 4 };
    var lay = try layout(a, unq.text, 600, metrics, false, &m, FixedMeasure.cell);
    defer lay.deinit(a);
    try std.testing.expect(!lay.foldable);
    try std.testing.expect(lay.toggle_rect == null);
    try std.testing.expectEqual(@as(usize, 2), lay.visible_lines);
    try std.testing.expect(lay.lines[0].marker.?.bullet);
    var saw_link = false;
    var saw_bold = false;
    for (lay.runs) |run| {
        const slice = unq.text[run.text.start..run.text.end];
        try std.testing.expect(std.mem.indexOf(u16, slice, w("**")) == null);
        if (run.style.bold) saw_bold = true;
        if (run.target) |t| {
            saw_link = true;
            try std.testing.expectEqualSlices(u16, w("docs"), slice);
            try std.testing.expectEqualSlices(u16, w("https://example.test"), unq.text[t.start..t.end]);
        }
    }
    try std.testing.expect(saw_link and saw_bold);
}

test "MUBO-237 reply preview strips raw markdown without altering plain text" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    var out: [256]u16 = undefined;
    var n = formatReplyPreview(w("**The fix itself is small. The time goes into waiting and checks around it.**"), &out);
    try std.testing.expectEqualSlices(u16, w("\u{21a9} The fix itself is small. The time goes into waiting and checks around it."), out[0..n]);
    n = formatReplyPreview(w("Original message"), &out);
    try std.testing.expectEqualSlices(u16, w("\u{21a9} Original message"), out[0..n]);
    n = formatReplyPreview(w("### **Bold** and [link](https://example.test) and `code`"), &out);
    try std.testing.expectEqualSlices(u16, w("\u{21a9} Bold and link and code"), out[0..n]);
    var tiny: [12]u16 = undefined;
    n = formatReplyPreview(w("**The fix itself is small**"), &tiny);
    try std.testing.expectEqual(@as(u16, 0x2026), tiny[n - 1]);
    try std.testing.expect(std.mem.indexOf(u16, tiny[0..n], w("**")) == null);
}

test "MUBO-237 ordinary user messages without quotes return null and toggle store flips state" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    for ([_][]const u16{
        w("plain message"),
        w("if a > b then ok"),
        w(">500ms latency"),
        w(">="),
        w(">"),
        w(">   "),
    }) |msg| {
        try std.testing.expect(parse(msg) == null);
    }
    var store: ToggleStore = .{};
    try std.testing.expect(!store.isOpen(42));
    try std.testing.expect(store.toggle(42));
    try std.testing.expect(store.isOpen(42));
    try std.testing.expect(!store.toggle(42));
    try std.testing.expect(!store.isOpen(42));
    const dark = colors(0x3A3A3A, 0xF2F2F2, 0xF5AF6E, false);
    try std.testing.expect(dark.inset_bg > 0x3A3A3A);
    try std.testing.expect(dark.text != 0xF2F2F2);
    try std.testing.expect(dark.bold_text != dark.text);
}
