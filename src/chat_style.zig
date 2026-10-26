const std = @import("std");
const md = @import("chat_markdown.zig");

pub fn readingColumn(pane_width: i32, scaled_max_width: i32) struct { left: i32, width: i32 } {
    const pane = @max(0, pane_width);
    const width = @min(pane, @max(0, scaled_max_width));
    return .{ .left = @divTrunc(pane - width, 2), .width = width };
}

pub fn contentColumn(pane_left: i32, pane_width: i32, scaled_max_width: i32) struct { left: i32, width: i32 } {
    const reading = readingColumn(pane_width, scaled_max_width);
    return .{ .left = pane_left + reading.left, .width = reading.width };
}

test "chat column centers within the available pane and caps at 960" {
    const wide = contentColumn(220, 1700, 960);
    try std.testing.expectEqual(@as(i32, 590), wide.left);
    try std.testing.expectEqual(@as(i32, 960), wide.width);
    for ([_]i32{ 0, 1, 12, 40, 300, 600, 960, 1700 }) |width| {
        const col = contentColumn(220, width, 960);
        try std.testing.expectEqual(@min(width, 960), col.width);
        try std.testing.expectEqual(220 + @divTrunc(width - col.width, 2), col.left);
        try std.testing.expect(col.left + col.width <= 220 + width);
    }
}

pub fn bubbleMaxWidth(width: i32, narrow_width: i32) i32 {
    const percent: i64 = if (width <= narrow_width) 9 else 6;
    return @intCast(@max(1, @divTrunc(@as(i64, @max(1, width)) * percent, 10)));
}
pub fn agentBubbleWidth(width: i32, narrow_width: i32) i32 {
    return bubbleMaxWidth(width, narrow_width);
}
pub fn cornerRadius(w: i32, h: i32, want: i32) i32 {
    return @max(0, @min(want, @divTrunc(@min(w, h), 2)));
}
pub fn argb(c: u32) u32 {
    return 0xFF000000 | ((c & 0xFF) << 16) | (c & 0xFF00) | ((c >> 16) & 0xFF);
}
fn channelShift(v: u32, delta: i32) u32 {
    return @intCast(std.math.clamp(@as(i32, @intCast(v)) + delta, 0, 255));
}
pub fn shift(c: u32, delta: i32) u32 {
    return channelShift(c & 0xFF, delta) | (channelShift((c >> 8) & 0xFF, delta) << 8) | (channelShift((c >> 16) & 0xFF, delta) << 16);
}
pub fn isDark(c: u32) bool {
    const lum = (2126 * (c & 0xFF) + 7152 * ((c >> 8) & 0xFF) + 722 * ((c >> 16) & 0xFF)) / 10000;
    return lum < 128;
}
pub fn scrollThumbColor(bg: u32) u32 {
    return shift(bg, if (isDark(bg)) 44 else -60);
}
pub const BubbleColors = struct { user: u32, agent: u32, injected: u32 };
pub fn bubbleColors(bg: u32) BubbleColors {
    if (isDark(bg)) return .{ .user = shift(bg, 53), .agent = shift(bg, 36), .injected = 0x4F2F1E };
    return .{ .user = shift(bg, -26), .agent = shift(bg, -11), .injected = 0xF7E6D6 };
}
pub fn bubbleWidth(width: i32, natural: i32, pad: i32, narrow_width: i32) i32 {
    return std.math.clamp(natural + 2 * pad, 1, bubbleMaxWidth(width, narrow_width));
}
pub fn headerHeight(_: md.Block, _: i32) i32 {
    return 0;
}
pub fn timestamp(iso: []const u8) struct { time: [5]u16, zone: [6]u16 } {
    var result: @TypeOf(timestamp("")) = .{ .time = @splat(0), .zone = @splat(0) };
    if (iso.len < 19 or iso[10] != 'T' or iso[13] != ':' or iso[16] != ':') return result;
    for ([_]usize{ 11, 12, 14, 15 }) |i| if (!std.ascii.isDigit(iso[i])) return result;
    const hour = std.fmt.parseInt(u8, iso[11..13], 10) catch return result;
    const minute = std.fmt.parseInt(u8, iso[14..16], 10) catch return result;
    if (hour > 23 or minute > 59) return result;
    for (iso[11..16], 0..) |c, i| result.time[i] = c;
    if (iso[iso.len - 1] == 'Z') {
        result.zone = .{ 'U', 'T', 'C', 0, 0, 0 };
    } else if (iso.len >= 25) {
        const suffix = iso[iso.len - 6 ..];
        if ((suffix[0] == '+' or suffix[0] == '-') and suffix[3] == ':') {
            for (suffix, 0..) |c, i| result.zone[i] = c;
        }
    }
    return result;
}

pub const BubblePos = enum { single, first, middle, last };

pub fn bubblePositions(blocks: []const md.Block, out: []BubblePos) void {
    const n = @min(blocks.len, out.len);
    for (0..n) |i| {
        const joins_prev = i > 0 and joinsRun(blocks[i - 1], blocks[i]);
        const joins_next = i + 1 < blocks.len and joinsRun(blocks[i], blocks[i + 1]);
        out[i] = if (joins_prev and joins_next) .middle else if (joins_prev) .last else if (joins_next) .first else .single;
    }
}
fn joinsRun(prev: md.Block, next: md.Block) bool {
    return prev.role == .prose and next.role == .prose and !next.first;
}
pub fn topInset(pos: BubblePos, pad: i32, para_gap: i32) i32 {
    return if (pos == .single or pos == .first) pad else para_gap;
}
pub fn bottomInset(pos: BubblePos, pad: i32) i32 {
    return if (pos == .single or pos == .last) pad else 0;
}
pub fn roundTop(pos: BubblePos) bool {
    return pos == .single or pos == .first;
}
pub fn roundBottom(pos: BubblePos) bool {
    return pos == .single or pos == .last;
}

pub fn markScreenMessages(blocks: []md.Block) void {
    var agent_start = true;
    for (blocks) |*block| {
        if (block.markdown) continue;
        if (block.role == .user) {
            block.first = true;
            agent_start = true;
        } else {
            block.first = agent_start;
            agent_start = false;
        }
    }
}

test "user bubbles stay right aligned and cannot exceed the reader width" {
    for ([_]i32{ 1, 24, 200, 800, 1600 }) |width| {
        const bubble = bubbleWidth(width, 10000, 12, 720);
        try std.testing.expect(bubble <= width);
        try std.testing.expect(width - bubble >= 0);
        try std.testing.expect(bubble <= bubbleMaxWidth(width, 720));
    }
    try std.testing.expectEqual(@as(i32, 74), bubbleWidth(800, 50, 12, 720));
}
test "IGSH-897 the scroll thumb is a dark gray a little brighter than a dark chat and darker than a light one" {
    const dark_bg: u32 = 0x181818;
    const dark_thumb = scrollThumbColor(dark_bg);
    try std.testing.expect(isDark(dark_thumb) and dark_thumb > dark_bg);
    try std.testing.expectEqual(@as(u32, 0x444444), scrollThumbColor(0x181818) & 0xFFFFFF & 0x444444);
    try std.testing.expect(scrollThumbColor(0xF3F3F3) < 0xF3F3F3);
}

test "IGSH-849 assistant headers reserve no space" {
    var block = md.Block{ .start = 0, .len = 1, .role = .prose, .first = true };
    try std.testing.expectEqual(@as(i32, 0), headerHeight(block, 28));
    block.first = false;
    try std.testing.expectEqual(@as(i32, 0), headerHeight(block, 28));
    block.first = true;
    block.role = .user;
    try std.testing.expectEqual(@as(i32, 0), headerHeight(block, 28));
}
test "screen fallback keeps user and assistant message styling without invented times" {
    var blocks = [_]md.Block{
        .{ .start = 0, .len = 1, .role = .user },
        .{ .start = 1, .len = 1, .role = .prose },
        .{ .start = 2, .len = 1, .role = .code },
        .{ .start = 3, .len = 1, .role = .user },
        .{ .start = 4, .len = 1, .role = .prose },
    };
    markScreenMessages(&blocks);
    try std.testing.expect(blocks[1].first and !blocks[2].first and blocks[4].first);
    try std.testing.expectEqual(@as(u16, 0), blocks[1].time[0]);
}
test "recorded timestamps show their timezone and invalid times remain absent" {
    const utc = timestamp("2026-10-03T12:34:00.123Z");
    try std.testing.expectEqualSlices(u16, &.{ '1', '2', ':', '3', '4' }, &utc.time);
    try std.testing.expectEqual(@as(u16, 'U'), utc.zone[0]);
    const offset = timestamp("2026-10-03T14:34:00+02:00");
    try std.testing.expectEqualSlices(u16, &.{ '+', '0', '2', ':', '0', '0' }, &offset.zone);
    try std.testing.expectEqual(@as(u16, 0), timestamp("-").time[0]);
    try std.testing.expectEqual(@as(u16, 0), timestamp("2026-10-03T99:99:00Z").time[0]);
}
test "bubble colours derive from the theme background" {
    const amoled = bubbleColors(0x000000);
    try std.testing.expectEqual(@as(u32, 0x353535), amoled.user);
    try std.testing.expectEqual(@as(u32, 0x242424), amoled.agent);
    const light = bubbleColors(0xFFFFFF);
    try std.testing.expectEqual(@as(u32, 0xE5E5E5), light.user);
    try std.testing.expect(light.agent > light.user);
    try std.testing.expectEqual(@as(u32, 0xFFFFFF), shift(0xF0F0F0, 99));
    try std.testing.expectEqual(@as(u32, 0), shift(0x050505, -99));
}
test "bubble geometry: 60 percent cap for both roles, pill corners, argb order" {
    try std.testing.expectEqual(@as(i32, 576), bubbleMaxWidth(960, 720));
    try std.testing.expectEqual(@as(i32, 576), agentBubbleWidth(960, 720));
    try std.testing.expectEqual(@as(i32, 18), cornerRadius(300, 100, 18));
    try std.testing.expectEqual(@as(i32, 14), cornerRadius(300, 28, 18));
    try std.testing.expectEqual(@as(i32, 0), cornerRadius(0, 0, 18));
    try std.testing.expectEqual(@as(u32, 0xFF332211), argb(0x112233));
}

test "one agent reply is one bubble; user messages and code panels stand alone" {
    var blocks = [_]md.Block{
        .{ .start = 0, .len = 1, .role = .user, .first = true },
        .{ .start = 1, .len = 1, .role = .prose, .first = true },
        .{ .start = 2, .len = 1, .role = .prose },
        .{ .start = 3, .len = 1, .role = .prose },
        .{ .start = 4, .len = 1, .role = .code },
        .{ .start = 5, .len = 1, .role = .prose },
        .{ .start = 6, .len = 1, .role = .prose, .first = true },
        .{ .start = 7, .len = 1, .role = .user, .first = true },
        .{ .start = 8, .len = 1, .role = .prose, .first = true },
    };
    var pos: [blocks.len]BubblePos = undefined;
    bubblePositions(&blocks, &pos);
    const want = [_]BubblePos{ .single, .first, .middle, .last, .single, .single, .single, .single, .single };
    try std.testing.expectEqualSlices(BubblePos, &want, &pos);
    try std.testing.expect(roundTop(.first) and !roundBottom(.first));
    try std.testing.expect(!roundTop(.middle) and !roundBottom(.middle));
    try std.testing.expect(!roundTop(.last) and roundBottom(.last));
    try std.testing.expectEqual(@as(i32, 10), topInset(.first, 10, 8));
    try std.testing.expectEqual(@as(i32, 8), topInset(.last, 10, 8));
    try std.testing.expectEqual(@as(i32, 0), bottomInset(.middle, 10));
    try std.testing.expectEqual(@as(i32, 10), bottomInset(.single, 10));
}
test "prose after a code panel starts its own bubble run" {
    var blocks = [_]md.Block{
        .{ .start = 0, .len = 1, .role = .prose, .first = true },
        .{ .start = 1, .len = 1, .role = .code },
        .{ .start = 2, .len = 1, .role = .prose },
        .{ .start = 3, .len = 1, .role = .prose },
    };
    var pos: [4]BubblePos = undefined;
    bubblePositions(&blocks, &pos);
    try std.testing.expectEqualSlices(BubblePos, &.{ .single, .single, .first, .last }, &pos);
    var short: [2]BubblePos = undefined;
    bubblePositions(&blocks, &short);
    try std.testing.expectEqual(BubblePos.single, short[0]);
}

test "injected bubbles use readable blue fills and reserve no agent header" {
    try std.testing.expectEqual(@as(u32, 0xFF1E2F4F), argb(bubbleColors(0).injected));
    try std.testing.expectEqual(@as(u32, 0xFFD6E6F7), argb(bubbleColors(0xFFFFFF).injected));
    const block = md.Block{ .start = 0, .len = 1, .role = .injected, .first = true };
    try std.testing.expectEqual(@as(i32, 0), headerHeight(block, 28));
    var positions: [1]BubblePos = undefined;
    bubblePositions(&.{block}, &positions);
    try std.testing.expectEqual(BubblePos.single, positions[0]);
}

test "reading column caps wide panes at the configured maximum" {
    for ([_]i32{ 1690, 2000, 3000, 4000 }) |width| {
        const col = readingColumn(width, 960);
        try std.testing.expectEqual(@as(i32, 960), col.width);
        try std.testing.expectEqual(@divTrunc(width - 960, 2), col.left);
    }
}

test "reading column clamps to narrow panes and scales the maximum" {
    for ([_]i32{ 0, 1, 400, 759, 760 }) |pane| {
        const col = readingColumn(pane, 760);
        try std.testing.expectEqual(pane, col.width);
        try std.testing.expectEqual(@as(i32, 0), col.left);
    }
    const scaled = readingColumn(1690, 1140);
    try std.testing.expectEqual(@as(i32, 1140), scaled.width);
    try std.testing.expectEqual(@as(i32, 275), scaled.left);
    try std.testing.expectEqual(@as(i32, 900), readingColumn(900, 1140).width);
}

test "reading column recomputes centered bounds on resize and stays inside the pane" {
    for ([_]i32{ -1, 0, 1, 759, 760, 761, 1691, 3000, std.math.maxInt(i32) }) |pane| {
        const col = readingColumn(pane, 760);
        try std.testing.expect(col.width >= 0 and col.width <= @max(0, pane));
        try std.testing.expect(col.left >= 0 and col.left + col.width <= @max(0, pane));
        try std.testing.expect(@max(0, pane) - col.width - 2 * col.left <= 1);
    }
    try std.testing.expectEqual(@as(i32, 760), readingColumn(2000, 760).width);
    try std.testing.expectEqual(@as(i32, 760), readingColumn(4000, 760).width);
}

pub fn statusHeight(known: bool, expanded: bool, count: usize, available: i32, header_h: i32, row_h: i32) i32 {
    if (!known) return 0;
    const limit = @max(0, @divTrunc(available, 2));
    return @min(@max(0, available), header_h + if (expanded) @min(@as(i32, @intCast(@min(count, 50))) * row_h, @max(0, limit - header_h)) else @as(i32, 0));
}

test "status row geometry hides unknown state and reserves a bounded independent todo viewport" {
    try std.testing.expectEqual(@as(i32, 0), statusHeight(false, true, 50, 600, 28, 24));
    try std.testing.expectEqual(@as(i32, 28), statusHeight(true, false, 50, 600, 28, 24));
    try std.testing.expectEqual(@as(i32, 196), statusHeight(true, true, 7, 600, 28, 24));
    try std.testing.expectEqual(@as(i32, 300), statusHeight(true, true, 50, 600, 28, 24));
    try std.testing.expectEqual(@as(i32, 10), statusHeight(true, true, 50, 10, 28, 24));
}
