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
const QUOTE_MAX: usize = 80;
const ELLIPSIS: u16 = 0x2026;
const LikeWish = enum(u8) { show, hide };
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

fn quoteText(text: []const u16, out: []u16) []const u16 {
    const cap = @min(out.len, QUOTE_MAX);
    const room = if (cap > 0) cap - 1 else 0;
    var n: usize = 0;
    var boundary: usize = 0;
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
        if (space) boundary = n;
        if (n + units + @intFromBool(space) > room) break;
        if (space) {
            out[n] = ' ';
            n += 1;
        }
        @memcpy(out[n..][0..units], text[i..][0..units]);
        n += units;
        i += units;
        space = false;
    }
    var more = false;
    var rest = i;
    while (rest < text.len) : (rest += 1) {
        if (whitespace(text[rest])) continue;
        more = true;
        break;
    }
    if (!more) return out[0..n];
    if (boundary == 0) {
        var cut: usize = 0;
        rest = 0;
        while (rest < text.len and cut < room) {
            const c = text[rest];
            const units: usize = if (c >= 0xd800 and c <= 0xdbff and rest + 1 < text.len) 2 else 1;
            if (cut + units > room) break;
            @memcpy(out[cut..][0..units], text[rest..][0..units]);
            cut += units;
            rest += units;
        }
        if (cut == 0) return out[0..0];
        out[cut] = ELLIPSIS;
        return out[0 .. cut + 1];
    }
    out[boundary] = ELLIPSIS;
    return out[0 .. boundary + 1];
}

fn writeQuote(emoji: Emoji, text: []const u16, out: []u16) ?usize {
    var buffer: [QUOTE_MAX + 1]u16 = undefined;
    const shown = quoteText(text, &buffer);
    if (shown.len == 0) return null;
    const glyph = emoji.text();
    const join = std.unicode.utf8ToUtf16LeStringLiteral(" to: ");
    if (glyph.len + join.len + shown.len > out.len) return null;
    var n: usize = 0;
    for ([_][]const u16{ glyph, join, shown }) |part| {
        @memcpy(out[n..][0..part.len], part);
        n += part.len;
    }
    return n;
}

pub fn spoken(emoji: Emoji, text: []const u16, out: []u16) ?[]const u16 {
    const n = writeQuote(emoji, text, out) orelse return null;
    return out[0..n];
}

pub fn format(emoji: Emoji, target: u64, text: []const u16, out: []u16) ?[]const u16 {
    var n = writeQuote(emoji, text, out) orelse return null;
    var suffix: [32]u8 = undefined;
    const tail = std.fmt.bufPrint(&suffix, " [mp:{x:0>16}]", .{target}) catch unreachable;
    if (n + tail.len > out.len) return null;
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
        if (!cleanQuote(quote)) return null;
        var hex: [16]u8 = undefined;
        for (body[at + marker.len ..][0..16], 0..) |c, i| {
            if (!(c >= '0' and c <= '9') and !(c >= 'a' and c <= 'f')) return null;
            hex[i] = @intCast(c);
        }
        return .{ .emoji = emoji, .reference = std.fmt.parseInt(u64, &hex, 16) catch return null, .quote = quote };
    }
    return null;
}

pub fn parseSpoken(text: []const u16) ?Reaction {
    if (std.mem.indexOfScalar(u16, text, '\n') != null or std.mem.indexOfScalar(u16, text, '\r') != null) return null;
    const join = std.unicode.utf8ToUtf16LeStringLiteral(" to: ");
    for (std.enums.values(Emoji)) |emoji| {
        const prefix = emoji.text();
        if (!std.mem.startsWith(u16, text, prefix)) continue;
        const rest = text[prefix.len..];
        if (!std.mem.startsWith(u16, rest, join)) return null;
        const quote = rest[join.len..];
        if (!cleanQuote(quote)) return null;
        return .{ .emoji = emoji, .reference = 0, .quote = quote };
    }
    return null;
}

fn readReaction(text: []const u16) ?Reaction {
    return parse(text) orelse parseSpoken(text);
}

fn cleanQuote(quote: []const u16) bool {
    if (quote.len == 0 or quote.len > QUOTE_MAX or whitespace(quote[0]) or whitespace(quote[quote.len - 1])) return false;
    var previous_space = false;
    for (quote) |c| {
        if ((whitespace(c) and c != ' ') or (c == ' ' and previous_space)) return false;
        previous_space = c == ' ';
    }
    return true;
}

pub const View = struct {
    hidden: std.ArrayList(bool) = .empty,
    badges: std.ArrayList(u8) = .empty,
    pending: std.ArrayList(u64) = .empty,
    projections: std.ArrayList(ProjectedBlock) = .empty,
    pending_projections: std.ArrayList(ProjectedPending) = .empty,
    hash: u64 = 0,
    context: u64 = 0,
    like_counts: []u16 = &.{},
    wish_refs: [24]u64 = @splat(0),
    wish_kind: [24]LikeWish = @splat(.hide),
    wish_len: usize = 0,
    wish_context: u64 = 0,

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

    fn quoteNeedle(quote: []const u16) []const u16 {
        if (quote.len > 0 and quote[quote.len - 1] == ELLIPSIS) return quote[0 .. quote.len - 1];
        return quote;
    }

    fn resolveQuote(a: std.mem.Allocator, quote: []const u16, targets: *const std.AutoHashMap(u64, Target), blocks: []const md.Block, text: []const u16, before: usize) !?usize {
        const needle = quoteNeedle(quote);
        if (needle.len == 0) return null;
        var found: ?usize = null;
        var seen = std.AutoHashMap(u64, void).init(a);
        defer seen.deinit();
        const limit = @min(before, blocks.len);
        for (blocks[0..limit], 0..) |block, i| {
            if ((block.role != .prose and block.role != .code) or block.reaction_reference == 0) continue;
            const target = targets.get(block.reaction_reference) orelse continue;
            if (i != target.first) continue;
            if ((try seen.getOrPut(block.reaction_reference)).found_existing) continue;
            if (target.ambiguous or target.last >= before) continue;
            const from = blocks[target.first].start;
            const last = blocks[target.last];
            const body = text[from .. last.start + last.len];
            const buffer = try a.alloc(u16, body.len);
            defer a.free(buffer);
            if (std.mem.indexOf(u16, normalized(body, buffer), needle) == null) continue;
            if (found != null) break;
            found = target.last;
        }
        return found;
    }

    fn resolve(a: std.mem.Allocator, reaction: Reaction, targets: *const std.AutoHashMap(u64, Target), blocks: []const md.Block, text: []const u16, before: usize) !?usize {
        if (reaction.reference == 0) return try resolveQuote(a, reaction.quote, targets, blocks, text, before);
        const target = targets.get(reaction.reference) orelse return null;
        if (target.ambiguous or target.last >= before) return null;
        const from = blocks[target.first].start;
        const last = blocks[target.last];
        const body = text[from .. last.start + last.len];
        const buffer = try a.alloc(u16, body.len);
        defer a.free(buffer);
        const needle = quoteNeedle(reaction.quote);
        if (needle.len == 0 or std.mem.indexOf(u16, normalized(body, buffer), needle) == null) return null;
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
            const reaction = readReaction(line) orelse continue;
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
        for (matches.items) |match| self.noteLike(match.target, match.emoji, false);
        return .{ .text = display_text, .source = source };
    }

    fn noteLike(self: *View, target: usize, emoji: Emoji, pending: bool) void {
        if (emoji != .like) {
            self.badges.items[target] |= emoji.bit();
            return;
        }
        const counted = target < self.like_counts.len and self.like_counts[target] != 0;
        if (pending and counted) return;
        if (!pending and target < self.like_counts.len) self.like_counts[target] += 1;
        self.badges.items[target] ^= emoji.bit();
    }

    pub fn wishLike(self: *View, message: u64, show: bool) void {
        if (message == 0) return;
        self.wish_context = self.context;
        const kind: LikeWish = if (show) .show else .hide;
        for (self.wish_refs[0..self.wish_len], 0..) |existing, i| {
            if (existing != message) continue;
            self.wish_kind[i] = kind;
            return;
        }
        if (self.wish_len == self.wish_refs.len) {
            self.wish_refs[0] = message;
            self.wish_kind[0] = kind;
            return;
        }
        self.wish_refs[self.wish_len] = message;
        self.wish_kind[self.wish_len] = kind;
        self.wish_len += 1;
    }

    pub fn wishedLike(self: *const View, message: u64) ?bool {
        if (message == 0 or self.wish_context != self.context) return null;
        for (self.wish_refs[0..self.wish_len], 0..) |existing, i| {
            if (existing != message) continue;
            return self.wish_kind[i] == .show;
        }
        return null;
    }

    fn foldLikes(self: *View, blocks: []const md.Block) void {
        var i: usize = 0;
        while (i < self.wish_len) {
            const message = self.wish_refs[i];
            const wish = self.wish_kind[i];
            var raw = false;
            var last: ?usize = null;
            for (blocks, 0..) |block, index| {
                if (block.reaction_reference != message or (block.role != .prose and block.role != .code)) continue;
                last = index;
                if ((self.badges.items[index] & Emoji.like.bit()) != 0) raw = true;
            }
            if ((wish == .hide and !raw) or (wish == .show and raw)) {
                self.wish_len -= 1;
                self.wish_refs[i] = self.wish_refs[self.wish_len];
                self.wish_kind[i] = self.wish_kind[self.wish_len];
                continue;
            }
            if (wish == .hide) {
                for (blocks, 0..) |block, index| {
                    if (block.reaction_reference == message) self.badges.items[index] &= ~Emoji.like.bit();
                }
            } else if (last) |index| self.badges.items[index] |= Emoji.like.bit();
            i += 1;
        }
    }

    fn anchorBadges(self: *View, blocks: []const md.Block, targets: *const std.AutoHashMap(u64, Target)) void {
        for (blocks, 0..) |block, i| {
            const badge = self.badges.items[i];
            if (badge == 0 or block.reaction_reference == 0) continue;
            const target = targets.get(block.reaction_reference) orelse continue;
            if (target.ambiguous or i == target.last) continue;
            self.badges.items[target.last] |= badge;
            self.badges.items[i] = 0;
        }
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
        if (self.wish_context != self.context) {
            self.wish_len = 0;
            self.wish_context = self.context;
        }
        const like_counts = try a.alloc(u16, blocks.len);
        defer a.free(like_counts);
        @memset(like_counts, 0);
        self.like_counts = like_counts;
        defer self.like_counts = &.{};
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
            if (readReaction(body)) |reaction| {
                if (try resolve(a, reaction, &targets, blocks, text, i)) |target| {
                    self.hidden.items[i] = true;
                    self.noteLike(target, reaction.emoji, false);
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
            if (readReaction(item.text)) |reaction| {
                if (try resolve(a, reaction, &targets, blocks, text, blocks.len)) |target| {
                    try self.pending.append(a, item.id);
                    self.noteLike(target, reaction.emoji, true);
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
        self.foldLikes(blocks);
        self.anchorBadges(blocks, &targets);
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

test "SOFT-2442 a second thumbs up removes the badge and one pending copy does not" {
    const a = std.testing.allocator;
    const words = std.unicode.utf8ToUtf16LeStringLiteral("Answer");
    const id = reference("msg_target");
    var line: [256]u16 = undefined;
    const reaction = format(.like, id, words, &line).?;
    const capture = try a.alloc(u16, words.len + reaction.len * 2);
    defer a.free(capture);
    @memcpy(capture[0..words.len], words);
    @memcpy(capture[words.len..][0..reaction.len], reaction);
    @memcpy(capture[words.len + reaction.len ..], reaction);
    const target: md.Block = .{ .start = 0, .len = words.len, .role = .prose, .first = true, .message_id = 1, .reaction_reference = id };
    const first: md.Block = .{ .start = words.len, .len = reaction.len, .role = .user, .first = true };
    const second: md.Block = .{ .start = words.len + reaction.len, .len = reaction.len, .role = .user, .first = true };
    var view: View = .{};
    defer view.deinit(a);
    _ = try view.build(a, &.{ target }, words, &.{.{ .id = 1, .text = reaction }});
    try std.testing.expectEqual(Emoji.like.bit(), view.mask(0));
    _ = try view.build(a, &.{ target }, words, &.{ .{ .id = 1, .text = reaction }, .{ .id = 2, .text = reaction } });
    try std.testing.expectEqual(@as(u8, 0), view.mask(0));
    _ = try view.build(a, &.{ target, first }, capture, &.{});
    try std.testing.expectEqual(Emoji.like.bit(), view.mask(0));
    _ = try view.build(a, &.{ target, first }, capture, &.{.{ .id = 7, .text = reaction }});
    try std.testing.expectEqual(Emoji.like.bit(), view.mask(0));
    _ = try view.build(a, &.{ target, first, second }, capture, &.{});
    try std.testing.expectEqual(@as(u8, 0), view.mask(0));
    view.wishLike(id, true);
    try std.testing.expectEqual(@as(?bool, true), view.wishedLike(id));
    _ = try view.build(a, &.{ target, first, second }, capture, &.{});
    try std.testing.expectEqual(Emoji.like.bit(), view.mask(0));
    view.wishLike(id, false);
    try std.testing.expectEqual(@as(?bool, false), view.wishedLike(id));
    view.context = view.context +% 1;
    try std.testing.expect(view.wishedLike(id) == null);
    view.context = view.wish_context;
    _ = try view.build(a, &.{ target, first }, capture, &.{});
    try std.testing.expectEqual(@as(u8, 0), view.mask(0));
    _ = try view.build(a, &.{ target, first, second }, capture, &.{});
    try std.testing.expectEqual(@as(u8, 0), view.mask(0));
}

test "SOFT-2448 a long thumbs-up quote ends on a whole word and both replies match" {
    const a = std.testing.allocator;
    const source = std.unicode.utf8ToUtf16LeStringLiteral("Same first words for this example for this example for this example for this example");
    var line: [256]u16 = undefined;
    const reaction = spoken(.like, source, &line).?;
    try std.testing.expect(std.mem.indexOfScalar(u16, reaction, '[') == null);
    try std.testing.expectEqual(ELLIPSIS, reaction[reaction.len - 1]);
    try std.testing.expect(reaction[reaction.len - 2] != ' ');
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("👍 to: Same first words for this example for this example for this example for this…"), reaction);
    const parsed = parseSpoken(reaction).?;
    try std.testing.expectEqual(Emoji.like, parsed.emoji);
    try std.testing.expectEqual(@as(u64, 0), parsed.reference);
    var short_buffer: [256]u16 = undefined;
    const short = spoken(.heart, std.unicode.utf8ToUtf16LeStringLiteral("  Everything\n  is done  "), &short_buffer).?;
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("❤️ to: Everything is done"), short);
    const target: md.Block = .{ .start = 0, .len = source.len, .role = .prose, .first = true, .message_id = 1, .reaction_reference = reference("msg_target") };
    const first: md.Block = .{ .start = source.len, .len = reaction.len, .role = .user, .first = true };
    const second: md.Block = .{ .start = source.len + reaction.len, .len = reaction.len, .role = .user, .first = true };
    const capture = try a.alloc(u16, source.len + reaction.len * 2);
    defer a.free(capture);
    @memcpy(capture[0..source.len], source);
    @memcpy(capture[source.len..][0..reaction.len], reaction);
    @memcpy(capture[source.len + reaction.len ..], reaction);
    const pending = [_]Pending{ .{ .id = 1, .text = reaction }, .{ .id = 2, .text = reaction } };
    var view: View = .{};
    defer view.deinit(a);
    _ = try view.build(a, &.{ target, first }, capture, pending[0..1]);
    try std.testing.expect(view.hides(1));
    try std.testing.expect(view.hidesPending(1));
    _ = try view.build(a, &.{ target, first, second }, capture, &pending);
    try std.testing.expect(view.hides(1));
    try std.testing.expect(view.hides(2));
    try std.testing.expect(view.hidesPending(1));
    try std.testing.expect(view.hidesPending(2));
}

test "SOFT-2887 a code-free reaction lands on the first of two same-prefix replies" {
    const a = std.testing.allocator;
    const opening = std.unicode.utf8ToUtf16LeStringLiteral("Same first words for this example for this example for this example for this example");
    const sep = std.unicode.utf8ToUtf16LeStringLiteral("\r\n\r\n");
    const first_reply = std.unicode.utf8ToUtf16LeStringLiteral("FIRST REPLY");
    const second_reply = std.unicode.utf8ToUtf16LeStringLiteral("SECOND REPLY");
    const capture = try std.mem.concat(a, u16, &.{ opening, sep, first_reply, sep, opening, sep, second_reply });
    defer a.free(capture);
    const first_start = 0;
    const first_len = opening.len + sep.len + first_reply.len;
    const second_start = first_len + sep.len;
    const second_len = opening.len + sep.len + second_reply.len;
    const blocks = [_]md.Block{
        .{ .start = first_start, .len = first_len, .role = .prose, .first = true, .message_id = 1, .reaction_reference = reference("msg_first") },
        .{ .start = second_start, .len = second_len, .role = .prose, .first = true, .message_id = 2, .reaction_reference = reference("msg_second") },
    };
    var line: [256]u16 = undefined;
    const reaction = spoken(.like, opening, &line).?;
    var view: View = .{};
    defer view.deinit(a);
    _ = try view.build(a, &blocks, capture, &.{.{ .id = 7, .text = reaction }});
    try std.testing.expect(view.hidesPending(7));
    try std.testing.expect(view.projectedPending(7) == null);
    try std.testing.expectEqual(Emoji.like.bit(), view.mask(0));
    try std.testing.expectEqual(@as(u8, 0), view.mask(1));
}

test "SOFT-2441 a code-free reaction anchors on the last paragraph block" {
    const a = std.testing.allocator;
    const p1 = std.unicode.utf8ToUtf16LeStringLiteral("First paragraph.\r\n\r\n");
    const p2 = std.unicode.utf8ToUtf16LeStringLiteral("Second paragraph.\r\n\r\n");
    const p3 = std.unicode.utf8ToUtf16LeStringLiteral("Third paragraph.");
    const capture = try std.mem.concat(a, u16, &.{ p1, p2, p3 });
    defer a.free(capture);
    const id = reference("msg_target");
    const blocks = [_]md.Block{
        .{ .start = 0, .len = p1.len, .role = .prose, .first = true, .message_id = 1, .reaction_reference = id },
        .{ .start = p1.len, .len = p2.len, .role = .prose, .message_id = 1, .reaction_reference = id },
        .{ .start = p1.len + p2.len, .len = p3.len, .role = .prose, .message_id = 1, .reaction_reference = id },
    };
    var line: [256]u16 = undefined;
    const reaction = spoken(.like, p1, &line).?;
    const react: md.Block = .{ .start = capture.len, .len = reaction.len, .role = .user, .first = true };
    var body = try a.alloc(u16, capture.len + reaction.len);
    defer a.free(body);
    @memcpy(body[0..capture.len], capture);
    @memcpy(body[capture.len..], reaction);
    var view: View = .{};
    defer view.deinit(a);
    _ = try view.build(a, &blocks, body, &.{.{ .id = 1, .text = reaction }});
    try std.testing.expectEqual(@as(u8, 0), view.mask(0));
    try std.testing.expectEqual(@as(u8, 0), view.mask(1));
    try std.testing.expectEqual(Emoji.like.bit(), view.mask(2));
    const with_reply = [_]md.Block{ blocks[0], blocks[1], blocks[2], react };
    _ = try view.build(a, &with_reply, body, &.{});
    try std.testing.expect(view.hides(3));
    try std.testing.expectEqual(@as(u8, 0), view.mask(0));
    try std.testing.expectEqual(@as(u8, 0), view.mask(1));
    try std.testing.expectEqual(Emoji.like.bit(), view.mask(2));
}
