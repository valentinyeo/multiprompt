const std = @import("std");
const md = @import("chat_markdown.zig");

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
pub const Pending = struct { id: u64, text: []const u16 };

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
    hash: u64 = 0,
    context: u64 = 0,

    pub fn deinit(self: *View, a: std.mem.Allocator) void {
        self.hidden.deinit(a);
        self.badges.deinit(a);
        self.pending.deinit(a);
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

    fn hideReplies(self: *View, blocks: []const md.Block, from: usize) void {
        var end = from;
        var count: usize = 0;
        while (end < blocks.len and blocks[end].role != .user) : (end += 1) {
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
            const reaction = parse(text[block.start..][0..block.len]) orelse continue;
            const target = try resolve(a, reaction, &targets, blocks, text, i) orelse continue;
            self.hidden.items[i] = true;
            self.badges.items[target] |= reaction.emoji.bit();
        }
        for (pending) |item| {
            const reaction = parse(item.text) orelse continue;
            const target = try resolve(a, reaction, &targets, blocks, text, blocks.len) orelse continue;
            try self.pending.append(a, item.id);
            self.badges.items[target] |= reaction.emoji.bit();
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
        const next = hash.final();
        const changed = next != self.hash;
        self.hash = next;
        return changed;
    }

    pub fn hides(self: *const View, index: usize) bool {
        return index < self.hidden.items.len and self.hidden.items[index];
    }

    pub fn mask(self: *const View, index: usize) u8 {
        return if (index < self.badges.items.len) self.badges.items[index] else 0;
    }

    pub fn hidesPending(self: *const View, id: u64) bool {
        return std.mem.indexOfScalar(u64, self.pending.items, id) != null;
    }
};

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
}
