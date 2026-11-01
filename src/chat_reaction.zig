const std = @import("std");
const md = @import("chat_markdown.zig");
const reply = @import("chat_reply.zig");

pub const Emoji = enum(u2) {
    like,
    dislike,
    heart,

    pub fn text(self: Emoji) []const u16 {
        return switch (self) {
            .like => std.unicode.utf8ToUtf16LeStringLiteral("👍"),
            .dislike => std.unicode.utf8ToUtf16LeStringLiteral("👎"),
            .heart => std.unicode.utf8ToUtf16LeStringLiteral("❤️"),
        };
    }

    pub fn bit(self: Emoji) u8 {
        return @as(u8, 1) << @intFromEnum(self);
    }
};

pub const Reaction = struct { emoji: Emoji, reference: u64, quote: []const u16 };
pub const Pending = struct { id: u64, text: []const u16, allow_mixed: bool = false };

pub const Projection = struct {
    text: []u16,
    source: []usize,

    fn deinit(self: Projection, a: std.mem.Allocator) void {
        a.free(self.text);
        a.free(self.source);
    }
};

const ProjectedBlock = struct { index: usize, projection: Projection };
const ProjectedPending = struct { id: u64, projection: Projection };
const Range = struct { start: usize, end: usize };

pub fn reference(id: []const u8) u64 {
    return if (id.len == 0) 0 else std.hash.Fnv1a_64.hash(id);
}

fn whitespace(c: u16) bool {
    return switch (c) {
        9...13, 28...32, 0xa0, 0x1680, 0x2000...0x200a, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000 => true,
        else => false,
    };
}

fn normalized(text: []const u16, out: []u16) []const u16 {
    var n: usize = 0;
    var space = false;
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        if (whitespace(c)) {
            space = n > 0;
            i += 1;
            continue;
        }
        const units: usize = if (c >= 0xd800 and c <= 0xdbff and i + 1 < text.len) 2 else 1;
        if (n + units + @intFromBool(space) > out.len) break;
        if (space) {
            out[n] = ' ';
            n += 1;
        }
        @memcpy(out[n..][0..units], text[i..][0..units]);
        n += units;
        i += units;
        space = false;
    }
    return out[0..n];
}

pub fn format(emoji: Emoji, target: u64, text: []const u16, out: []u16) ?[]const u16 {
    var quote: [80]u16 = undefined;
    const shown = normalized(text, &quote);
    if (shown.len == 0) return null;
    var suffix: [32]u8 = undefined;
    const tail = std.fmt.bufPrint(&suffix, " [mp:{x:0>16}]", .{target}) catch unreachable;
    const glyph = emoji.text();
    const join = std.unicode.utf8ToUtf16LeStringLiteral(" to: ");
    const len = glyph.len + join.len + shown.len + tail.len;
    if (len > out.len) return null;
    var n: usize = 0;
    for ([_][]const u16{ glyph, join, shown }) |part| {
        @memcpy(out[n..][0..part.len], part);
        n += part.len;
    }
    for (tail) |c| {
        out[n] = c;
        n += 1;
    }
    return out[0..n];
}

pub fn parse(text: []const u16) ?Reaction {
    const join = std.unicode.utf8ToUtf16LeStringLiteral(" to: ");
    const marker = std.unicode.utf8ToUtf16LeStringLiteral(" [mp:");
    for (std.enums.values(Emoji)) |emoji| {
        const prefix = emoji.text();
        if (!std.mem.startsWith(u16, text, prefix)) continue;
        const rest = text[prefix.len..];
        if (!std.mem.startsWith(u16, rest, join)) return null;
        const body = rest[join.len..];
        if (body.len < marker.len + 18 or body[body.len - 1] != ']') return null;
        const at = body.len - marker.len - 17;
        if (at == 0 or !std.mem.eql(u16, marker, body[at..][0..marker.len])) return null;
        const quote = body[0..at];
        if (quote.len > 80 or whitespace(quote[0]) or whitespace(quote[quote.len - 1])) return null;
        var previous_space = false;
        for (quote) |c| {
            if ((whitespace(c) and c != ' ') or (c == ' ' and previous_space)) return null;
            previous_space = c == ' ';
        }
        var hex: [16]u8 = undefined;
        for (body[at + marker.len ..][0..16], 0..) |c, i| {
            if (!(c >= '0' and c <= '9') and !(c >= 'a' and c <= 'f')) return null;
            hex[i] = @intCast(c);
        }
        return .{ .emoji = emoji, .reference = std.fmt.parseInt(u64, &hex, 16) catch return null, .quote = quote };
    }
    return null;
}

pub const View = struct {
    hidden: std.ArrayList(bool) = .empty,
    badges: std.ArrayList(u8) = .empty,
    pending: std.ArrayList(u64) = .empty,
    projections: std.ArrayList(ProjectedBlock) = .empty,
    pending_projections: std.ArrayList(ProjectedPending) = .empty,
    hash: u64 = 0,
    context: u64 = 0,

    pub fn deinit(self: *View, a: std.mem.Allocator) void {
        self.hidden.deinit(a);
        self.badges.deinit(a);
        self.pending.deinit(a);
        for (self.projections.items) |item| item.projection.deinit(a);
        self.projections.deinit(a);
        for (self.pending_projections.items) |item| item.projection.deinit(a);
        self.pending_projections.deinit(a);
        self.* = .{};
    }

    const Target = struct { first: usize, last: usize, message_id: u64, ambiguous: bool = false };

    fn resolve(a: std.mem.Allocator, reaction: Reaction, targets: *const std.AutoHashMap(u64, Target), blocks: []const md.Block, text: []const u16, before: usize) !?usize {
        if (reaction.reference == 0) return null;
        const target = targets.get(reaction.reference) orelse return null;
        if (target.ambiguous or target.last >= before) return null;
        const from = blocks[target.first].start;
        const last = blocks[target.last];
        const body = text[from .. last.start + last.len];
        const buffer = try a.alloc(u16, body.len);
        defer a.free(buffer);
        if (std.mem.indexOf(u16, normalized(body, buffer), reaction.quote) == null) return null;
        return target.last;
    }

    const Match = struct { range: Range, target: usize, emoji: Emoji };

    fn project(self: *View, a: std.mem.Allocator, body: []const u16, scan_start: usize, targets: *const std.AutoHashMap(u64, Target), blocks: []const md.Block, text: []const u16, before: usize) !?Projection {
        var matches: std.ArrayList(Match) = .empty;
        defer matches.deinit(a);
        const start = @min(scan_start, body.len);
        const displayed = body[start..];
        const body_start = start + if (reply.reference(displayed)) |ref| ref.body_start else @as(usize, 0);
        var pos = body_start;
        var fence: u16 = 0;
        var fence_len: usize = 0;
        while (pos < body.len) {
            const line_start = pos;
            while (pos < body.len and body[pos] != '\r' and body[pos] != '\n') : (pos += 1) {}
            const line_end = pos;
            if (pos < body.len and body[pos] == '\r') pos += 1;
            if (pos < body.len and body[pos] == '\n') pos += 1;
            const line = body[line_start..line_end];
            var indent: usize = 0;
            while (indent < line.len and line[indent] == ' ') : (indent += 1) {}
            if (indent <= 3 and line.len - indent >= 3 and (line[indent] == '`' or line[indent] == '~') and line[indent + 1] == line[indent] and line[indent + 2] == line[indent]) {
                var end = indent;
                while (end < line.len and line[end] == line[indent]) : (end += 1) {}
                if (fence == 0) {
                    fence = line[indent];
                    fence_len = end - indent;
                } else if (fence == line[indent] and end - indent >= fence_len) {
                    var trailing = end;
                    while (trailing < line.len and (line[trailing] == ' ' or line[trailing] == '\t')) : (trailing += 1) {}
                    if (trailing == line.len) fence = 0;
                }
                continue;
            }
            if (fence != 0 or indent >= 4 or (line.len > 0 and line[0] == '\t')) continue;
            const reaction = parse(line) orelse continue;
            const target = try resolve(a, reaction, targets, blocks, text, before) orelse continue;
            var remove_start = line_start;
            if (line_end == body.len and line_start > body_start) {
                if (body[remove_start - 1] == '\n') remove_start -= 1;
                if (remove_start > body_start and body[remove_start - 1] == '\r') remove_start -= 1;
            }
            try matches.append(a, .{ .range = .{ .start = remove_start, .end = pos }, .target = target, .emoji = reaction.emoji });
        }
        if (matches.items.len == 0) return null;
        var visible: usize = 0;
        var cursor: usize = 0;
        for (matches.items) |match| {
            const from = @max(cursor, match.range.start);
            visible += from - cursor;
            cursor = @max(cursor, match.range.end);
        }
        visible += body.len - cursor;
        const display_text = try a.alloc(u16, visible);
        errdefer a.free(display_text);
        const source = try a.alloc(usize, visible);
        errdefer a.free(source);
        cursor = 0;
        var out: usize = 0;
        for (matches.items) |match| {
            while (cursor < match.range.start) : (cursor += 1) {
                display_text[out] = body[cursor];
                source[out] = cursor;
                out += 1;
            }
            cursor = @max(cursor, match.range.end);
        }
        while (cursor < body.len) : (cursor += 1) {
            display_text[out] = body[cursor];
            source[out] = cursor;
            out += 1;
        }
        for (matches.items) |match| self.badges.items[match.target] |= match.emoji.bit();
        return .{ .text = display_text, .source = source };
    }

    pub fn projected(self: *const View, index: usize) ?*const Projection {
        for (self.projections.items) |*item| if (item.index == index) return &item.projection;
        return null;
    }

    pub fn projectedPending(self: *const View, id: u64) ?*const Projection {
        for (self.pending_projections.items) |*item| if (item.id == id) return &item.projection;
        return null;
    }

    fn hideReplies(self: *View, blocks: []const md.Block, from: usize) void {
        var end = from;
        var count: usize = 0;
        while (end < blocks.len and blocks[end].role != .user and blocks[end].role != .injected) : (end += 1) {
            const block = blocks[end];
            if (block.role != .prose and block.role != .code) continue;
            if (block.first or count == 0) count += 1;
        }
        if (count != 1) return;
        for (blocks[from..end], from..) |block, index| {
            if (block.role == .prose or block.role == .code) self.hidden.items[index] = true;
        }
    }

    pub fn build(self: *View, a: std.mem.Allocator, blocks: []const md.Block, text: []const u16, pending: []const Pending) !bool {
        return self.buildDisplayed(a, blocks, text, pending, null);
    }

    pub fn buildDisplayed(self: *View, a: std.mem.Allocator, blocks: []const md.Block, text: []const u16, pending: []const Pending, display_starts: ?[]const usize) !bool {
        for (self.projections.items) |item| item.projection.deinit(a);
        self.projections.clearRetainingCapacity();
        for (self.pending_projections.items) |item| item.projection.deinit(a);
        self.pending_projections.clearRetainingCapacity();
        try self.hidden.resize(a, blocks.len);
        try self.badges.resize(a, blocks.len);
        @memset(self.hidden.items, false);
        @memset(self.badges.items, 0);
        self.pending.clearRetainingCapacity();
        var targets = std.AutoHashMap(u64, Target).init(a);
        defer targets.deinit();
        for (blocks, 0..) |block, i| {
            if ((block.role != .prose and block.role != .code) or block.reaction_reference == 0) continue;
            const entry = try targets.getOrPut(block.reaction_reference);
            if (entry.found_existing) {
                entry.value_ptr.ambiguous = entry.value_ptr.ambiguous or entry.value_ptr.message_id != block.message_id;
                entry.value_ptr.last = i;
            } else entry.value_ptr.* = .{ .first = i, .last = i, .message_id = block.message_id };
        }
        for (blocks, 0..) |block, i| {
            if (block.role != .user) continue;
            const body = text[block.start..][0..block.len];
            if (parse(body)) |reaction| {
                if (try resolve(a, reaction, &targets, blocks, text, i)) |target| {
                    self.hidden.items[i] = true;
                    self.badges.items[target] |= reaction.emoji.bit();
                    self.hideReplies(blocks, i + 1);
                    continue;
                }
            }
            const start = if (display_starts) |starts| @min(starts[i] -| block.start, body.len) else 0;
            const projection = try self.project(a, body, start, &targets, blocks, text, i) orelse continue;
            var content = false;
            for (projection.text, projection.source) |unit, source| {
                if (source >= start and !whitespace(unit)) {
                    content = true;
                    break;
                }
            }
            if (!content) {
                projection.deinit(a);
                self.hidden.items[i] = true;
                self.hideReplies(blocks, i + 1);
            } else {
                self.projections.append(a, .{ .index = i, .projection = projection }) catch |err| {
                    projection.deinit(a);
                    return err;
                };
            }
        }
        for (pending) |item| {
            if (parse(item.text)) |reaction| {
                if (try resolve(a, reaction, &targets, blocks, text, blocks.len)) |target| {
                    try self.pending.append(a, item.id);
                    self.badges.items[target] |= reaction.emoji.bit();
                    continue;
                }
            }
            if (!item.allow_mixed) continue;
            const projection = try self.project(a, item.text, 0, &targets, blocks, text, blocks.len) orelse continue;
            var content = false;
            for (projection.text) |unit| {
                if (!whitespace(unit)) {
                    content = true;
                    break;
                }
            }
            if (!content) {
                projection.deinit(a);
                try self.pending.append(a, item.id);
                continue;
            }
            self.pending_projections.append(a, .{ .id = item.id, .projection = projection }) catch |err| {
                projection.deinit(a);
                return err;
            };
        }
        var hash = std.hash.Wyhash.init(0);
        for (self.hidden.items, 0..) |hidden, index| {
            if (hidden) hash.update(std.mem.asBytes(&index));
        }
        for (self.badges.items, 0..) |mask_value, index| {
            if (mask_value == 0) continue;
            hash.update(std.mem.asBytes(&self.context));
            hash.update(std.mem.asBytes(&index));
            hash.update(std.mem.asBytes(&blocks[index].reaction_reference));
            hash.update(&.{mask_value});
        }
        hash.update(std.mem.sliceAsBytes(self.pending.items));
        for (self.projections.items) |item| {
            hash.update(std.mem.asBytes(&self.context));
            hash.update(std.mem.asBytes(&item.index));
            hash.update(std.mem.sliceAsBytes(item.projection.text));
            hash.update(std.mem.sliceAsBytes(item.projection.source));
        }
        for (self.pending_projections.items) |item| {
            hash.update(std.mem.asBytes(&self.context));
            hash.update(std.mem.asBytes(&item.id));
            hash.update(std.mem.sliceAsBytes(item.projection.text));
            hash.update(std.mem.sliceAsBytes(item.projection.source));
        }
        const next = hash.final();
        const changed = next != self.hash;
        self.hash = next;
        return changed;
    }

    pub fn hides(self: *const View, index: usize) bool {
        return index < self.hidden.items.len and self.hidden.items[index];
    }

    pub fn visibleFrom(self: *const View, blocks: []const md.Block, from: usize) bool {
        for (blocks[@min(from, blocks.len)..], from..) |block, index| {
            if (block.role != .tool and !self.hides(index)) return true;
        }
        return false;
    }

    pub fn mask(self: *const View, index: usize) u8 {
        return if (index < self.badges.items.len) self.badges.items[index] else 0;
    }

    pub fn hidesPending(self: *const View, id: u64) bool {
        return std.mem.indexOfScalar(u64, self.pending.items, id) != null;
    }
};

test "IGSH-1132 projection keeps words and original source coordinates" {
    const a = std.testing.allocator;
    const words = std.unicode.utf8ToUtf16LeStringLiteral("Answer");
    const id = reference("target");
    var line_buffer: [256]u16 = undefined;
    const line = format(.like, id, words, &line_buffer).?;
    const prefix = std.unicode.utf8ToUtf16LeStringLiteral("Before\r\n");
    const suffix = std.unicode.utf8ToUtf16LeStringLiteral("\r\nAfter");
    const body = try std.mem.concat(a, u16, &.{ prefix, line, suffix });
    defer a.free(body);
    const blocks = [_]md.Block{.{ .start = 0, .len = words.len, .role = .prose, .message_id = 1, .reaction_reference = id }};
    var targets = std.AutoHashMap(u64, View.Target).init(a);
    defer targets.deinit();
    try targets.put(id, .{ .first = 0, .last = 0, .message_id = 1 });
    var view: View = .{};
    defer view.deinit(a);
    try view.badges.resize(a, 1);
    view.badges.items[0] = 0;
    const projection = (try view.project(a, body, 0, &targets, &blocks, words, 1)).?;
    defer projection.deinit(a);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Before\r\nAfter"), projection.text);
    try std.testing.expectEqual(prefix.len + line.len + 2, projection.source[prefix.len]);
    try std.testing.expectEqual(Emoji.like.bit(), view.mask(0));
    try std.testing.expectEqualSlices(u16, line, body[prefix.len..][0..line.len]);
    const fenced = try std.mem.concat(a, u16, &.{ std.unicode.utf8ToUtf16LeStringLiteral("  ```\n"), line, std.unicode.utf8ToUtf16LeStringLiteral("\n  ```\n"), line });
    defer a.free(fenced);
    const kept = (try view.project(a, fenced, 0, &targets, &blocks, words, 1)).?;
    defer kept.deinit(a);
    const expected = try std.mem.concat(a, u16, &.{ std.unicode.utf8ToUtf16LeStringLiteral("  ```\n"), line, std.unicode.utf8ToUtf16LeStringLiteral("\n  ```") });
    defer a.free(expected);
    try std.testing.expectEqualSlices(u16, expected, kept.text);
    const wrapped = try std.mem.concat(a, u16, &.{ std.unicode.utf8ToUtf16LeStringLiteral("> "), line, std.unicode.utf8ToUtf16LeStringLiteral("\r\n\r\nWords\r\n"), line });
    defer a.free(wrapped);
    const projected_reply = (try view.project(a, wrapped, 0, &targets, &blocks, words, 1)).?;
    defer projected_reply.deinit(a);
    const expected_reply = try std.mem.concat(a, u16, &.{ std.unicode.utf8ToUtf16LeStringLiteral("> "), line, std.unicode.utf8ToUtf16LeStringLiteral("\r\n\r\nWords") });
    defer a.free(expected_reply);
    try std.testing.expectEqualSlices(u16, expected_reply, projected_reply.text);
    try std.testing.expect(reply.reference(projected_reply.text) != null);
}

test "IGSH-1132 build preserves mixed answers and confirms pending eligibility" {
    const a = std.testing.allocator;
    const words = std.unicode.utf8ToUtf16LeStringLiteral("Answer");
    const id = reference("target");
    var line_buffer: [256]u16 = undefined;
    const line = format(.heart, id, words, &line_buffer).?;
    const before = std.unicode.utf8ToUtf16LeStringLiteral("Hello\n");
    const after = std.unicode.utf8ToUtf16LeStringLiteral("\nWorld");
    const body = try std.mem.concat(a, u16, &.{ before, line, after });
    defer a.free(body);
    const capture = try std.mem.concat(a, u16, &.{ words, body, words });
    defer a.free(capture);
    const blocks = [_]md.Block{
        .{ .start = 0, .len = words.len, .role = .prose, .message_id = 1, .reaction_reference = id },
        .{ .start = words.len, .len = body.len, .role = .user },
        .{ .start = words.len + body.len, .len = words.len, .role = .prose, .first = true },
    };
    var view: View = .{};
    defer view.deinit(a);
    _ = try view.build(a, &blocks, capture, &.{.{ .id = 1, .text = body }});
    try std.testing.expect(!view.hides(1));
    try std.testing.expect(!view.hides(2));
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Hello\nWorld"), view.projected(1).?.text);
    try std.testing.expect(view.projectedPending(1) == null);
    try std.testing.expectEqual(Emoji.heart.bit(), view.mask(0));
    _ = try view.build(a, &blocks, capture, &.{.{ .id = 1, .text = body, .allow_mixed = true }});
    try std.testing.expect(view.projectedPending(1) != null);
    try std.testing.expect(!view.hidesPending(1));
    _ = try view.build(a, &blocks, capture, &.{.{ .id = 1, .text = body }});
    try std.testing.expect(view.projectedPending(1) == null);
    const only = try std.mem.concat(a, u16, &.{ line, std.unicode.utf8ToUtf16LeStringLiteral("\r\n"), line });
    defer a.free(only);
    _ = try view.build(a, &blocks, capture, &.{.{ .id = 2, .text = only, .allow_mixed = true }});
    try std.testing.expect(view.hidesPending(2));
    try std.testing.expect(view.projectedPending(2) == null);
    var invalid_buffer: [256]u16 = undefined;
    const invalid = format(.like, id, std.unicode.utf8ToUtf16LeStringLiteral("Wrong quote"), &invalid_buffer).?;
    const mixed = try std.mem.concat(a, u16, &.{ before, line, after, std.unicode.utf8ToUtf16LeStringLiteral("\n"), invalid });
    defer a.free(mixed);
    const mixed_capture = try std.mem.concat(a, u16, &.{ words, mixed, words });
    defer a.free(mixed_capture);
    const mixed_blocks = [_]md.Block{
        blocks[0],
        .{ .start = words.len, .len = mixed.len, .role = .user },
        .{ .start = words.len + mixed.len, .len = words.len, .role = .prose, .first = true },
    };
    _ = try view.build(a, &mixed_blocks, mixed_capture, &.{.{ .id = 3, .text = mixed }});
    const expected = try std.mem.concat(a, u16, &.{ before, std.unicode.utf8ToUtf16LeStringLiteral("World\n"), invalid });
    defer a.free(expected);
    try std.testing.expectEqualSlices(u16, expected, view.projected(1).?.text);
    try std.testing.expectEqualSlices(u16, mixed, mixed_capture[words.len..][0..mixed.len]);
    try std.testing.expect(!view.hides(2));
    try std.testing.expect(view.projectedPending(3) == null);
    try std.testing.expect(!view.hidesPending(3));
}

test "IGSH-975 wire format preserves quote and stable provider identity for all reactions" {
    try std.testing.expectEqual(@as(u64, 0xa430d84680aabd0b), reference("hello"));
    try std.testing.expectEqual(@as(u64, 0), reference(""));
    var out: [256]u16 = undefined;
    for (std.enums.values(Emoji)) |emoji| {
        const line = format(emoji, 0x123, std.unicode.utf8ToUtf16LeStringLiteral("  First\n  words  "), &out).?;
        const result = parse(line).?;
        try std.testing.expectEqual(emoji, result.emoji);
        try std.testing.expectEqual(@as(u64, 0x123), result.reference);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("First words"), result.quote);
    }
    try std.testing.expect(parse(std.unicode.utf8ToUtf16LeStringLiteral("👍 to: First words")) == null);
    try std.testing.expect(parse(std.unicode.utf8ToUtf16LeStringLiteral("ordinary message")) == null);
    try std.testing.expect(format(.like, 1, std.unicode.utf8ToUtf16LeStringLiteral(" \n "), &out) == null);
}

test "IGSH-975 shared Android wire fixtures" {
    const Case = struct { emoji: []const u8, id: []const u8, text: []const u8, expected: []const u8 };
    const a = std.testing.allocator;
    const cases = try std.json.parseFromSlice([]Case, a, @embedFile("testdata/reaction-fixture.json"), .{});
    defer cases.deinit();
    for (cases.value) |case| {
        const body = try std.unicode.utf8ToUtf16LeAlloc(a, case.text);
        defer a.free(body);
        const expected = try std.unicode.utf8ToUtf16LeAlloc(a, case.expected);
        defer a.free(expected);
        const emoji = parse(expected).?.emoji;
        var out: [256]u16 = undefined;
        try std.testing.expectEqualSlices(u16, expected, format(emoji, reference(case.id), body, &out).?);
    }
}

test "IGSH-975 repeated prefixes keep their provider target through rebuild and pending confirmation" {
    const a = std.testing.allocator;
    const words = std.unicode.utf8ToUtf16LeStringLiteral("Same first words");
    var line: [256]u16 = undefined;
    const reaction = format(.like, reference("msg_second"), words, &line).?;
    const capture = try a.alloc(u16, words.len * 2 + reaction.len);
    defer a.free(capture);
    @memcpy(capture[0..words.len], words);
    @memcpy(capture[words.len..][0..words.len], words);
    @memcpy(capture[words.len * 2 ..], reaction);
    const blocks = [_]md.Block{
        .{ .start = 0, .len = words.len, .role = .prose, .first = true, .message_id = 1, .reaction_reference = reference("msg_first") },
        .{ .start = words.len, .len = words.len, .role = .prose, .first = true, .message_id = 2, .reaction_reference = reference("msg_second") },
        .{ .start = words.len * 2, .len = reaction.len, .role = .user, .first = true },
    };
    var view: View = .{};
    defer view.deinit(a);
    _ = try view.build(a, blocks[0..2], capture, &.{.{ .id = 123, .text = reaction }});
    try std.testing.expect(view.hidesPending(123));
    try std.testing.expectEqual(@as(u8, 0), view.mask(0));
    try std.testing.expectEqual(Emoji.like.bit(), view.mask(1));
    _ = try view.build(a, &blocks, capture, &.{.{ .id = 123, .text = reaction }});
    try std.testing.expect(view.hides(2));
    try std.testing.expectEqual(Emoji.like.bit(), view.mask(1));
    var restarted: View = .{};
    defer restarted.deinit(a);
    _ = try restarted.build(a, &blocks, capture, &.{});
    try std.testing.expectEqualSlices(bool, view.hidden.items, restarted.hidden.items);
    try std.testing.expectEqualSlices(u8, view.badges.items, restarted.badges.items);
    var unknown: [256]u16 = undefined;
    const missing = format(.heart, reference("not-loaded"), words, &unknown).?;
    _ = try view.build(a, blocks[0..2], capture, &.{.{ .id = 456, .text = missing }});
    try std.testing.expect(!view.hidesPending(456));
    const wrong = format(.dislike, reference("msg_second"), std.unicode.utf8ToUtf16LeStringLiteral("Wrong quote"), &unknown).?;
    _ = try view.build(a, blocks[0..2], capture, &.{.{ .id = 456, .text = wrong }});
    try std.testing.expect(!view.hidesPending(456));
}

test "IGSH-975 ordinary history changes do not invalidate an unchanged reaction presentation" {
    const a = std.testing.allocator;
    var view: View = .{};
    defer view.deinit(a);
    const blocks = [_]md.Block{
        .{ .start = 0, .len = 1, .role = .prose },
        .{ .start = 0, .len = 1, .role = .prose },
    };
    _ = try view.build(a, blocks[0..1], &.{'x'}, &.{});
    view.context = 999;
    try std.testing.expect(!try view.build(a, &blocks, &.{'x'}, &.{}));
}

test "IGSH-1012 a lone session reply to a reaction is hidden and other replies stay" {
    const a = std.testing.allocator;
    const words = std.unicode.utf8ToUtf16LeStringLiteral("Everything is done");
    var line: [256]u16 = undefined;
    const reaction = format(.like, reference("msg_target"), words, &line).?;
    const ack = std.unicode.utf8ToUtf16LeStringLiteral("Noted, thanks.");
    const more = std.unicode.utf8ToUtf16LeStringLiteral("Finished the follow-up");
    const capture = try a.alloc(u16, words.len + reaction.len + ack.len + more.len);
    defer a.free(capture);
    @memcpy(capture[0..words.len], words);
    @memcpy(capture[words.len..][0..reaction.len], reaction);
    @memcpy(capture[words.len + reaction.len ..][0..ack.len], ack);
    @memcpy(capture[words.len + reaction.len + ack.len ..], more);
    const reply_start = words.len + reaction.len;
    const target: md.Block = .{ .start = 0, .len = words.len, .role = .prose, .first = true, .message_id = 1, .reaction_reference = reference("msg_target") };
    const react: md.Block = .{ .start = words.len, .len = reaction.len, .role = .user, .first = true };
    const ack_block: md.Block = .{ .start = reply_start, .len = ack.len, .role = .prose, .first = true, .message_id = 2 };
    const more_block: md.Block = .{ .start = reply_start + ack.len, .len = more.len, .role = .prose, .first = true, .message_id = 3 };
    var view: View = .{};
    defer view.deinit(a);
    _ = try view.build(a, &[_]md.Block{ target, react, ack_block }, capture, &.{});
    try std.testing.expect(!view.hides(0));
    try std.testing.expect(view.hides(1));
    try std.testing.expect(view.hides(2));
    try std.testing.expectEqual(Emoji.like.bit(), view.mask(0));
    _ = try view.build(a, &[_]md.Block{ target, react, ack_block, more_block }, capture, &.{});
    try std.testing.expect(view.hides(1));
    try std.testing.expect(!view.hides(2));
    try std.testing.expect(!view.hides(3));
    const ordinary: md.Block = .{ .start = words.len, .len = 1, .role = .user, .first = true };
    _ = try view.build(a, &[_]md.Block{ target, ordinary, ack_block }, capture, &.{});
    try std.testing.expect(!view.hides(1));
    try std.testing.expect(!view.hides(2));
    const next: md.Block = .{ .start = reply_start + ack.len, .len = more.len, .role = .user, .first = true };
    const answer: md.Block = .{ .start = reply_start + ack.len, .len = more.len, .role = .prose, .first = true, .message_id = 4 };
    _ = try view.build(a, &[_]md.Block{ target, react, ack_block, next, answer }, capture, &.{});
    try std.testing.expect(view.hides(2));
    try std.testing.expect(!view.hides(3));
    try std.testing.expect(!view.hides(4));
    const note: md.Block = .{ .start = reply_start + ack.len, .len = more.len, .role = .injected, .first = true };
    _ = try view.build(a, &[_]md.Block{ target, react, note, answer }, capture, &.{});
    try std.testing.expect(!view.hides(2));
    try std.testing.expect(!view.hides(3));
    _ = try view.build(a, &[_]md.Block{ target, react, ack_block }, capture, &.{});
    try std.testing.expect(!view.visibleFrom(&[_]md.Block{ target, react, ack_block }, 1));
    try std.testing.expect(view.visibleFrom(&[_]md.Block{ target, react, ack_block }, 0));
}
