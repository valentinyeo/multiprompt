const std = @import("std");
const transcript = @import("chat_transcript.zig");
const md = @import("chat_markdown.zig");
const style = @import("chat_style.zig");
const echo = @import("chat_echo.zig");

const Message = struct { role: []const u8, timestamp: []const u8 = "", text: []const u8, id: []const u8 = "", settlement: ?struct { operation: []const u8, content: []const u8 = "" } = null };
pub const MAX_CACHE_BYTES = 16 * 1024 * 1024;
pub const TAIL_BYTES = 512 * 1024;
pub const CACHE_WRITE_MS = 30_000;
const Header = struct { version: u8 = 3, start: u64 = 0, inode: u64, offset: u64, sid: []const u8, host: u8, codex: bool, tmux: []const u8, mtime: u64 = 0, probe: []const u8 = "", partial: bool = false };
pub const History = struct {
    rows: std.ArrayList(u8) = .empty,
    text: std.ArrayList(u16) = .empty,
    blocks: std.ArrayList(md.Block) = .empty,
    sid: [40]u8 = @splat(0),
    inode: u64 = 0,
    offset: u64 = 0,
    start: u64 = 0,
    revision: u64 = 0,
    last_row: usize = 0,
    last_text: usize = 0,
    last_block: usize = 0,
    changed_from: usize = 0,
    mtime: u64 = 0,
    probe: [64]u8 = @splat(0),
    more: bool = false,
    restore_full: bool = false,

    pub fn deinit(self: *History, a: std.mem.Allocator) void {
        self.rows.deinit(a);
        self.text.deinit(a);
        self.blocks.deinit(a);
        self.* = .{};
    }

    pub fn clone(self: History, a: std.mem.Allocator) !History {
        var result: History = .{ .sid = self.sid, .inode = self.inode, .offset = self.offset, .mtime = self.mtime, .probe = self.probe, .more = self.more, .restore_full = self.restore_full, .start = self.start, .revision = self.revision, .last_row = self.last_row, .last_text = self.last_text, .last_block = self.last_block, .changed_from = self.changed_from };
        errdefer result.deinit(a);
        try result.rows.appendSlice(a, self.rows.items);
        try result.text.appendSlice(a, self.text.items);
        try result.blocks.appendSlice(a, self.blocks.items);
        return result;
    }

    fn appendMessage(self: *History, a: std.mem.Allocator, bytes: []const u8, role: md.Role, stamp: []const u8) !void {
        const start = self.text.items.len;
        const first_block = self.blocks.items.len;
        const max_blocks = 1 + std.mem.count(u8, bytes, "\n");
        try self.text.ensureUnusedCapacity(a, bytes.len);
        try self.blocks.ensureUnusedCapacity(a, max_blocks);
        const message = try transcript.messageBlocks(bytes, self.text.unusedCapacitySlice(), start, role, self.blocks.unusedCapacitySlice()[0..max_blocks]);
        if (message.count == 0) return error.InvalidHistory;
        self.text.items.len += message.len;
        self.blocks.items.len += message.count;
        const recorded = style.timestamp(stamp);
        for (self.blocks.items[first_block..]) |*block| block.stamp_ms = @import("chat_echo.zig").stampMs(stamp);
        const image = @import("chat_image.zig");
        for (self.blocks.items[first_block..]) |*block| {
            if (block.role == .code) continue;
            var ranges: [image.MAX_PER_BLOCK]image.Range = undefined;
            block.image_count = @intCast(image.findImageUrls(self.text.items[block.start..][0..block.len], &ranges));
        }
        self.blocks.items[first_block].time = recorded.time;
        self.blocks.items[first_block].zone = recorded.zone;
    }

    fn render(self: *History, a: std.mem.Allocator) !void {
        var lines = std.mem.splitScalar(u8, self.rows.items, '\n');
        var last_id: std.ArrayList(u8) = .empty;
        defer last_id.deinit(a);
        var last_stamp: std.ArrayList(u8) = .empty;
        defer last_stamp.deinit(a);
        var last_role: md.Role = .prose;
        var message: std.ArrayList(u8) = .empty;
        defer message.deinit(a);
        var arena = std.heap.ArenaAllocator.init(a);
        defer arena.deinit();
        var row_at: usize = 0;
        while (lines.next()) |line| {
            defer row_at += line.len + 1;
            if (line.len == 0) continue;
            _ = arena.reset(.retain_capacity);
            const parsed = try std.json.parseFromSlice(Message, arena.allocator(), line, .{ .allocate = .alloc_always });
            const m = parsed.value;
            if (m.settlement != null) continue;
            const role: md.Role = if (std.mem.eql(u8, m.role, "user")) .user else if (std.mem.eql(u8, m.role, "assistant")) .prose else return error.InvalidHistory;
            if (m.text.len == 0) return error.InvalidHistory;
            const merge = m.id.len > 0 and std.mem.eql(u8, m.id, last_id.items) and role == last_role;
            if (merge) {
                try message.append(a, '\n');
            } else {
                if (message.items.len > 0) try self.appendMessage(a, message.items, last_role, last_stamp.items);
                message.clearRetainingCapacity();
                self.last_row = row_at;
                self.last_text = self.text.items.len;
                self.last_block = self.blocks.items.len;
                last_stamp.clearRetainingCapacity();
                try last_stamp.appendSlice(a, m.timestamp);
            }
            try message.appendSlice(a, m.text);
            last_id.clearRetainingCapacity();
            try last_id.appendSlice(a, m.id);
            last_role = role;
        }
        if (message.items.len > 0) try self.appendMessage(a, message.items, last_role, last_stamp.items);
    }

    pub fn deliveryEvidence(self: History, a: std.mem.Allocator, pending: echo.Pending) !echo.DeliveryEvidence {
        var result: echo.DeliveryEvidence = .{};
        var queue: std.ArrayList(struct { hash: u64, matches: bool }) = .empty;
        defer queue.deinit(a);
        var lines = std.mem.splitScalar(u8, self.rows.items, '\n');
        var prefix_buf: [16384]u16 = undefined;
        const prefix = echo.normalize(pending.text, &prefix_buf);
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            if (std.mem.indexOf(u8, line, "\"settlement\"") == null) continue;
            const parsed = try std.json.parseFromSlice(Message, a, line, .{});
            defer parsed.deinit();
            const m = parsed.value;
            const fact = m.settlement orelse continue;
            const content = try std.unicode.utf8ToUtf16LeAlloc(a, fact.content);
            defer a.free(content);
            const stamp = echo.stampMs(m.timestamp);
            result.latest_ms = @max(result.latest_ms, stamp);
            const fresh = echo.isNewBlock(pending.anchor, stamp, 0, true);
            if (std.mem.eql(u8, fact.operation, "rejected")) {
                if (fresh and echo.refusesCommand(content, pending.text)) result.refused = true;
                continue;
            }
            var normalized: [32768]u16 = undefined;
            const norm = echo.normalize(content, &normalized);
            const hash = std.hash.Wyhash.hash(0, std.mem.sliceAsBytes(norm));
            const matches = fresh and echo.blockMatches(content, prefix);
            if (std.mem.eql(u8, fact.operation, "enqueue")) {
                try queue.append(a, .{ .hash = hash, .matches = matches });
                if (matches) result.removed_ms = 0;
            } else if (std.mem.eql(u8, fact.operation, "popAll")) {
                for (queue.items) |item| {
                    if (fresh and item.matches) result.removed_ms = stamp;
                }
                queue.clearRetainingCapacity();
            } else if (std.mem.eql(u8, fact.operation, "remove") or std.mem.eql(u8, fact.operation, "dequeue")) {
                var index: ?usize = null;
                if (content.len == 0) {
                    if (queue.items.len > 0) index = 0;
                } else {
                    for (queue.items, 0..) |item, i| {
                        if (item.hash == hash) {
                            index = i;
                            break;
                        }
                    }
                }
                if (index) |i| {
                    const item = queue.orderedRemove(i);
                    if (fresh and item.matches) result.removed_ms = stamp;
                } else if (matches) result.removed_ms = stamp;
            }
        }
        return result;
    }

    pub fn cursor(self: History) History {
        return .{ .sid = self.sid, .inode = self.inode, .offset = self.offset, .start = self.start, .mtime = self.mtime, .probe = self.probe, .more = self.more, .revision = self.revision };
    }

    pub fn updateCursor(self: *History, other: History) void {
        self.offset = other.offset;
        self.more = other.more;
        self.mtime = other.mtime;
        self.probe = other.probe;
        if (!other.more) self.restore_full = false;
    }

    pub fn suffix(self: History, a: std.mem.Allocator) !History {
        var result = self.cursor();
        errdefer result.deinit(a);
        try result.rows.appendSlice(a, self.rows.items[self.last_row..]);
        try result.render(a);
        return result;
    }

    pub fn appendParsed(self: *History, a: std.mem.Allocator, next: *History) !void {
        const old_suffix = self.rows.items.len - self.last_row;
        if (next.rows.items.len < old_suffix) return error.InvalidHistory;
        const added = next.rows.items[old_suffix..];
        try self.rows.ensureUnusedCapacity(a, added.len);
        try self.text.ensureTotalCapacity(a, self.last_text + next.text.items.len);
        try self.blocks.ensureTotalCapacity(a, self.last_block + next.blocks.items.len);
        self.changed_from = self.last_block;
        self.rows.appendSliceAssumeCapacity(added);
        self.text.items.len = self.last_text;
        self.blocks.items.len = self.last_block;
        for (next.blocks.items) |*block| block.start += self.last_text;
        self.text.appendSliceAssumeCapacity(next.text.items);
        self.blocks.appendSliceAssumeCapacity(next.blocks.items);
        self.last_row += next.last_row;
        self.last_text += next.last_text;
        self.last_block += next.last_block;
        self.revision = next.revision;
        self.restore_full = false;
        self.updateCursor(next.*);
    }

    pub fn encode(self: History, a: std.mem.Allocator, key: transcript.Identity) ![]u8 {
        var start: usize = 0;
        const budget = TAIL_BYTES - 512;
        if (self.rows.items.len > budget) {
            start = self.rows.items.len - budget;
            start += if (std.mem.indexOfScalar(u8, self.rows.items[start..], '\n')) |n| n + 1 else self.rows.items.len - start;
        }
        const header = try std.json.Stringify.valueAlloc(a, Header{ .inode = self.inode, .offset = self.offset, .start = self.start, .sid = std.mem.sliceTo(&self.sid, 0), .host = key.host, .codex = key.codex, .tmux = std.mem.sliceTo(&key.tmux, 0), .mtime = self.mtime, .probe = std.mem.sliceTo(&self.probe, 0), .partial = start > 0 or self.restore_full }, .{});
        defer a.free(header);
        if (header.len + 1 > 512) return error.InvalidHistory;
        return std.fmt.allocPrint(a, "{s}\n{s}", .{ header, self.rows.items[start..] });
    }

    pub fn decode(a: std.mem.Allocator, bytes: []const u8, key: transcript.Identity) !History {
        if (bytes.len > MAX_CACHE_BYTES) return error.InvalidHistory;
        const end = std.mem.indexOfScalar(u8, bytes, '\n') orelse return error.InvalidHistory;
        const parsed = try std.json.parseFromSlice(Header, a, bytes[0..end], .{});
        defer parsed.deinit();
        const h = parsed.value;
        if ((h.version != 2 and h.version != 3) or h.sid.len == 0 or h.sid.len >= 40 or bytes[bytes.len - 1] != '\n' or
            (h.probe.len != 0 and h.probe.len != 64) or h.host != key.host or h.codex != key.codex or !std.mem.eql(u8, h.tmux, std.mem.sliceTo(&key.tmux, 0)) or
            (key.sid[0] != 0 and !std.mem.eql(u8, h.sid, std.mem.sliceTo(&key.sid, 0)))) return error.InvalidHistory;
        var result: History = .{ .inode = h.inode, .offset = h.offset, .mtime = h.mtime, .restore_full = h.partial or h.version == 2, .start = h.start, .revision = 1 };
        errdefer result.deinit(a);
        @memcpy(result.sid[0..h.sid.len], h.sid);
        @memcpy(result.probe[0..h.probe.len], h.probe);
        var tail = bytes[end + 1 ..];
        if (tail.len > TAIL_BYTES - 512) {
            const from = tail.len - (TAIL_BYTES - 512);
            const skip = std.mem.indexOfScalarPos(u8, tail, from, '\n') orelse return error.InvalidHistory;
            tail = tail[skip + 1 ..];
            result.restore_full = true;
        }
        try result.rows.appendSlice(a, tail);
        try result.render(a);
        return result;
    }

    pub fn apply(self: *History, a: std.mem.Allocator, wire: []const u8, id: u32, key: transcript.Identity) !void {
        var lines = std.mem.splitScalar(u8, wire, '\n');
        var fields = std.mem.splitScalar(u8, lines.next() orelse return error.InvalidHistory, '\t');
        if (!std.mem.eql(u8, fields.next() orelse "", "@mp") or
            (std.fmt.parseInt(u32, fields.next() orelse "", 10) catch return error.InvalidHistory) != id or
            !std.mem.eql(u8, fields.next() orelse "", "history") or
            !std.mem.eql(u8, fields.next() orelse "", "ok")) return error.InvalidHistory;
        const sid = fields.next() orelse return error.InvalidHistory;
        const base = std.fmt.parseInt(u64, fields.next() orelse "", 10) catch return error.InvalidHistory;
        const end = std.fmt.parseInt(u64, fields.next() orelse "", 10) catch return error.InvalidHistory;
        const inode = std.fmt.parseInt(u64, fields.next() orelse "", 10) catch return error.InvalidHistory;
        const more = fields.next() orelse return error.InvalidHistory;
        const agent = fields.next() orelse return error.InvalidHistory;
        const tmux = fields.next() orelse return error.InvalidHistory;
        const mtime_field = fields.next();
        const mtime = if (mtime_field) |v| std.fmt.parseInt(u64, v, 10) catch return error.InvalidHistory else 0;
        const probe = if (mtime_field != null) fields.next() orelse return error.InvalidHistory else "";
        const mode = if (mtime_field != null) fields.next() else null;
        const mode_text = mode orelse if (base == 0) "tail" else "delta";
        const oldest = if (mode != null) std.fmt.parseInt(u64, fields.next() orelse return error.InvalidHistory, 10) catch return error.InvalidHistory else self.start;
        if (!std.mem.eql(u8, mode_text, "tail") and !std.mem.eql(u8, mode_text, "delta") and !std.mem.eql(u8, mode_text, "older")) return error.InvalidHistory;
        if (probe.len != 0 and probe.len != 64) return error.InvalidHistory;
        if (sid.len == 0 or sid.len >= self.sid.len or end < base or inode == 0 or fields.next() != null or
            (!std.mem.eql(u8, more, "0") and !std.mem.eql(u8, more, "1")) or
            !std.mem.eql(u8, agent, if (key.codex) "codex" else "claude") or
            !std.mem.eql(u8, tmux, if (key.tmux[0] != 0) std.mem.sliceTo(&key.tmux, 0) else "-")) return error.InvalidHistory;
        if (key.tmux[0] == 0 and key.sid[0] != 0 and !std.mem.eql(u8, sid, std.mem.sliceTo(&key.sid, 0))) return error.InvalidHistory;
        const append = std.mem.eql(u8, mode_text, "delta");
        const prepend = std.mem.eql(u8, mode_text, "older");
        if ((append or prepend) and (inode != self.inode or !std.mem.eql(u8, sid, std.mem.sliceTo(&self.sid, 0)) or
            (if (prepend) end != self.start or oldest != base else base != self.offset or oldest != self.start))) return error.InvalidHistory;
        if (oldest > base) return error.InvalidHistory;
        var next: History = .{ .inode = inode, .offset = end, .start = if (mode == null and !append) 0 else oldest, .mtime = mtime, .more = std.mem.eql(u8, more, "1"), .revision = self.revision +% 1 };
        @memcpy(next.probe[0..probe.len], probe);
        errdefer next.deinit(a);
        @memcpy(next.sid[0..sid.len], sid);
        var ended = false;
        while (lines.next()) |line| {
            if (std.mem.eql(u8, line, "@@MP_END@@")) {
                ended = true;
                break;
            }
            if (line.len == 0) return error.InvalidHistory;
            try next.rows.appendSlice(a, line);
            try next.rows.append(a, '\n');
        }
        if (!ended) return error.InvalidHistory;
        while (lines.next()) |line| if (line.len != 0) return error.InvalidHistory;
        if (!append and !prepend and next.rows.items.len == 0 and self.rows.items.len > 0) return error.EmptyReset;
        if (append and next.rows.items.len == 0) {
            self.updateCursor(next);
            next.deinit(a);
            return;
        }
        if (append) {
            try next.rows.insertSlice(a, 0, self.rows.items[self.last_row..]);
            try next.render(a);
            try self.appendParsed(a, &next);
            next.deinit(a);
            return;
        }
        if (prepend) {
            try next.rows.appendSlice(a, self.rows.items);
            next.updateCursor(self.*);
        }
        try next.render(a);
        next.restore_full = mode == null and next.more and self.rows.items.len > 0;
        self.deinit(a);
        self.* = next;
    }
};

pub fn cacheKey(key: transcript.Identity) u64 {
    const name = if (key.tmux[0] != 0) std.mem.sliceTo(&key.tmux, 0) else std.mem.sliceTo(&key.sid, 0);
    return std.hash.Wyhash.hash(std.hash.Wyhash.hash(0, &.{ key.host, @intFromBool(key.codex), @intFromBool(key.tmux[0] != 0) }), name);
}

pub fn sameSession(a: transcript.Identity, b: transcript.Identity) bool {
    if (a.shell_id == 0 or b.shell_id == 0 or a.host != b.host or a.codex != b.codex) return false;
    if (a.sid[0] != 0 and b.sid[0] != 0 and !std.mem.eql(u8, &a.sid, &b.sid)) return false;
    if (a.tmux[0] != 0 or b.tmux[0] != 0) return a.tmux[0] != 0 and std.mem.eql(u8, &a.tmux, &b.tmux);
    if (a.sid[0] != 0 or b.sid[0] != 0) return a.sid[0] != 0 and std.mem.eql(u8, &a.sid, &b.sid);
    return a.shell_id == b.shell_id;
}

pub const Anchor = struct { index: usize, offset: i32 };
pub fn scrollAnchor(rects: anytype, scroll_y: i32) ?Anchor {
    var lo: usize = 0;
    var hi: usize = rects.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        if (rects[mid].bottom <= scroll_y) lo = mid + 1 else hi = mid;
    }
    return if (lo < rects.len) .{ .index = lo, .offset = scroll_y - rects[lo].top } else null;
}

pub fn scrollAfterLayout(content_h: i32, viewport_h: i32, old_y: i32, follow_bottom: bool, anchor_top: ?i32, offset: i32) i32 {
    const bottom = content_h - viewport_h;
    if (follow_bottom) return bottom;
    return std.math.clamp(if (anchor_top) |top| top + offset else old_y, @min(0, bottom), @max(0, bottom));
}

pub const MISSING_RETRY_MS: u64 = 60_000;

pub fn missingReason(wire: []const u8, id: u32) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, wire, '\n');
    var fields = std.mem.splitScalar(u8, lines.next() orelse return null, '\t');
    if (!std.mem.eql(u8, fields.next() orelse return null, "@mp") or
        (std.fmt.parseInt(u32, fields.next() orelse return null, 10) catch return null) != id or
        !std.mem.eql(u8, fields.next() orelse return null, "history") or
        !std.mem.eql(u8, fields.next() orelse return null, "missing") or
        !std.mem.eql(u8, fields.next() orelse return null, "-") or
        !std.mem.eql(u8, fields.next() orelse return null, "0")) return null;
    const reason = fields.next() orelse "session transcript not found";
    if (reason.len == 0 or fields.next() != null or !std.mem.eql(u8, lines.next() orelse return null, "@@MP_END@@")) return null;
    while (lines.next()) |line| if (line.len != 0) return null;
    return reason;
}

test "missing transcript carries a reason and waits a minute without accepting malformed replies" {
    try std.testing.expectEqualStrings("permission denied", missingReason("@mp\t7\thistory\tmissing\t-\t0\tpermission denied\n@@MP_END@@\n", 7).?);
    try std.testing.expectEqualStrings("session transcript not found", missingReason("@mp\t7\thistory\tmissing\t-\t0\n@@MP_END@@\n", 7).?);
    for ([_][]const u8{ "@mp\t8\thistory\tmissing\t-\t0\n@@MP_END@@\n", "@mp\t7\thistory\tmissing\t-\t0\n", "@mp\t7\thistory\tok\t-\t0\n@@MP_END@@\n" }) |wire| {
        try std.testing.expect(missingReason(wire, 7) == null);
    }
    try std.testing.expect(!retryDue(false, 59_999, MISSING_RETRY_MS));
    try std.testing.expect(retryDue(false, 60_000, MISSING_RETRY_MS));
}

pub fn retryDelay(failures: u8) u64 {
    return @min(@as(u64, 30_000), @as(u64, 1000) << @intCast(@min(failures -| 1, 5)));
}

pub fn retryDue(pending: bool, now: u64, next: u64) bool {
    return !pending and now >= next;
}

pub const Rect = struct { left: i32, top: i32, right: i32, bottom: i32 };
pub fn browserOverlapsContent(content: Rect, browser: Rect) bool {
    return @max(content.left, browser.left) < @min(content.right, browser.right) and
        @max(content.top, browser.top) < @min(content.bottom, browser.bottom);
}

pub fn column(client_right: i32, sidebar: i32, visible_browser: bool, split_left: i32, split_width: i32) struct { left: i32, width: i32 } {
    return if (visible_browser) .{ .left = split_left, .width = split_width } else .{ .left = sidebar, .width = @max(1, client_right - sidebar) };
}

const row = "{\"role\":\"user\",\"text\":\"old history\",\"timestamp\":\"2026-10-03T12:34:00Z\",\"id\":\"one\"}\n";
const first = "@mp\t1\thistory\tok\tsid\t0\t100\t9\t0\tclaude\tterm-1\n" ++ row ++ "@@MP_END@@\n";
test "persistent session cache survives runtime id cwd and discovered sid changes" {
    var k = transcript.Identity.initTmux(1, 0, false, "term-1", "/old");
    const stable = cacheKey(k);
    k.shell_id = 99;
    k.cwd = @splat(0);
    @memcpy(k.sid[0..3], "sid");
    try std.testing.expectEqual(stable, cacheKey(k));
    try std.testing.expect(sameSession(k, transcript.Identity.initTmux(1, 0, false, "term-1", "/old")));
    k.codex = true;
    try std.testing.expect(stable != cacheKey(k));
    k.codex = false;
    k.host = 1;
    try std.testing.expect(stable != cacheKey(k));
    var h: History = .{};
    defer h.deinit(std.testing.allocator);
    try h.apply(std.testing.allocator, first, 1, transcript.Identity.initTmux(1, 0, false, "term-1", ""));
    const disk = try h.encode(std.testing.allocator, k);
    defer std.testing.allocator.free(disk);
    var restored = try History.decode(std.testing.allocator, disk, k);
    defer restored.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(h.rows.items, restored.rows.items);
    try std.testing.expectEqualSlices(u16, h.text.items, restored.text.items);
    try std.testing.expectEqual(@as(u64, 100), restored.offset);
}
test "delta appends, timeout malformed empty reset and stale offset preserve full history" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(7, 0, false, "term-1", "");
    var h: History = .{};
    defer h.deinit(a);
    try h.apply(a, first, 1, key);
    for ([_][]const u8{ "", first[0 .. first.len - 12], "@mp\t2\thistory\tok\tsid\t0\t0\t10\t0\tclaude\tterm-1\n@@MP_END@@\n", "@mp\t2\thistory\tok\tsid\t99\t200\t9\t0\tclaude\tterm-1\n@@MP_END@@\n" }) |bad| {
        if (h.apply(a, bad, 2, key)) |_| return error.ExpectedFailure else |_| {}
        try std.testing.expectEqualStrings(row, h.rows.items);
        try std.testing.expectEqual(@as(u64, 100), h.offset);
    }
    try h.apply(a, "@mp\t2\thistory\tok\tsid\t100\t200\t9\t0\tclaude\tterm-1\n{\"role\":\"assistant\",\"text\":\"new reply\"}\n@@MP_END@@\n", 2, key);
    try std.testing.expectEqual(@as(usize, 2), h.blocks.items.len);
    try std.testing.expectEqual(@as(u64, 200), h.offset);
    try h.apply(a, "@mp\t3\thistory\tok\tsid\t200\t200\t9\t0\tclaude\tterm-1\n@@MP_END@@\n", 3, key);
    try std.testing.expectEqual(@as(usize, 2), h.blocks.items.len);
    try std.testing.expectError(error.InvalidHistory, h.apply(a, first, 1, transcript.Identity.initTmux(8, 0, false, "other", "")));
}
test "history has no rolling message or markdown block cap" {
    const a = std.testing.allocator;
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try wire.appendSlice(a, "@mp\t1\thistory\tok\tsid\t0\t500\t9\t0\tclaude\tterm-1\n");
    for (0..600) |_| try wire.appendSlice(a, row);
    try wire.appendSlice(a, "@@MP_END@@\n");
    var h: History = .{};
    defer h.deinit(a);
    try h.apply(a, wire.items, 1, transcript.Identity.initTmux(1, 0, false, "term-1", ""));
    try std.testing.expectEqual(@as(usize, 1), h.blocks.items.len);
    try std.testing.expect(h.text.items.len > 6000);
}
test "retry backs off forever with a cap and no request before its deadline" {
    try std.testing.expectEqual(@as(u64, 1000), retryDelay(1));
    try std.testing.expectEqual(@as(u64, 2000), retryDelay(2));
    try std.testing.expectEqual(@as(u64, 30_000), retryDelay(255));
    try std.testing.expect(!retryDue(true, 5000, 1000));
    try std.testing.expect(!retryDue(false, 999, 1000));
    try std.testing.expect(retryDue(false, 1000, 1000));
}
test "hidden or parked browser uses the entire content column" {
    const full = column(1920, 220, false, 724, 691);
    try std.testing.expectEqual(@as(i32, 220), full.left);
    try std.testing.expectEqual(@as(i32, 1700), full.width);
    const split = column(1920, 220, true, 220, 590);
    try std.testing.expectEqual(@as(i32, 590), split.width);
}

test "visible overlap works on negative-coordinate monitors but rejects parked panes" {
    const frame = Rect{ .left = 220, .top = 0, .right = 1920, .bottom = 1032 };
    try std.testing.expect(!browserOverlapsContent(frame, .{ .left = -1692, .top = 0, .right = -500, .bottom = 1032 }));
    try std.testing.expect(!browserOverlapsContent(frame, .{ .left = -32000, .top = -32000, .right = -31000, .bottom = -31000 }));
    try std.testing.expect(browserOverlapsContent(frame, .{ .left = 820, .top = 0, .right = 1920, .bottom = 1032 }));
    try std.testing.expect(browserOverlapsContent(.{ .left = -1700, .top = 0, .right = 0, .bottom = 1032 }, .{ .left = -1000, .top = 0, .right = 0, .bottom = 1032 }));
}

test "thumbnail height changes preserve the reader's block and the full scroll range" {
    const before = [_]Rect{
        .{ .left = 0, .top = 0, .right = 500, .bottom = 200 },
        .{ .left = 0, .top = 220, .right = 500, .bottom = 700 },
    };
    const anchor = scrollAnchor(&before, 300).?;
    try std.testing.expectEqual(@as(usize, 1), anchor.index);
    try std.testing.expectEqual(@as(i32, 80), anchor.offset);
    try std.testing.expectEqual(@as(i32, 600), scrollAfterLayout(1600, 800, 300, false, 520, anchor.offset));
    try std.testing.expectEqual(@as(i32, 800), scrollAfterLayout(1600, 800, 300, true, 520, anchor.offset));
    try std.testing.expectEqual(@as(i32, 0), scrollAfterLayout(1600, 800, -900, false, null, 0));
    try std.testing.expectEqual(@as(i32, 800), scrollAfterLayout(1600, 800, 9000, false, null, 0));
    try std.testing.expectEqual(@as(i32, -500), scrollAfterLayout(300, 800, 0, true, null, 0));
}

test "all messages and every paragraph remain present beyond the legacy 96 and 256 limits" {
    const a = std.testing.allocator;
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try wire.appendSlice(a, "@mp\t1\thistory\tok\tsid\t0\t99999\t9\t0\tclaude\tterm-1\n");
    for (0..600) |_| try wire.appendSlice(a, "{\"role\":\"assistant\",\"text\":\"first paragraph\\n\\nsecond paragraph\"}\n");
    try wire.appendSlice(a, "@@MP_END@@\n");
    var h: History = .{};
    defer h.deinit(a);
    try h.apply(a, wire.items, 1, transcript.Identity.initTmux(1, 0, false, "term-1", ""));
    try std.testing.expectEqual(@as(usize, 1200), h.blocks.items.len);
    try std.testing.expectEqual(@as(usize, 600), std.mem.count(u8, h.rows.items, "first paragraph"));
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("first paragraph"), h.text.items[h.blocks.items[0].start..][0..h.blocks.items[0].len]);
}

test "incomplete disk cache fails and adjacent streamed fragments merge across pages" {
    const a = std.testing.allocator;
    var h: History = .{};
    defer h.deinit(a);
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    try h.apply(a, first, 1, key);
    try h.apply(a, "@mp\t2\thistory\tok\tsid\t100\t200\t9\t0\tclaude\tterm-1\n{\"role\":\"user\",\"text\":\"continuation\",\"id\":\"one\"}\n@@MP_END@@\n", 2, key);
    try std.testing.expectEqual(@as(usize, 1), h.blocks.items.len);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("old history\ncontinuation"), h.text.items);
    const disk = try h.encode(a, key);
    defer a.free(disk);
    try std.testing.expectError(error.InvalidHistory, History.decode(a, disk[0 .. disk.len - 1], key));
}

test "cache headers reject reused sessions hosts providers and hash-path collisions" {
    const a = std.testing.allocator;
    var key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var h: History = .{};
    defer h.deinit(a);
    try h.apply(a, first, 1, key);
    const disk = try h.encode(a, key);
    defer a.free(disk);
    const original = key;
    @memcpy(key.sid[0..5], "other");
    var known = original;
    @memcpy(known.sid[0..3], "sid");
    try std.testing.expect(!sameSession(known, key));
    try std.testing.expectError(error.InvalidHistory, History.decode(a, disk, key));
    key = original;
    key.host = 1;
    try std.testing.expectError(error.InvalidHistory, History.decode(a, disk, key));
    key = original;
    key.codex = true;
    try std.testing.expectError(error.InvalidHistory, History.decode(a, disk, key));
    try std.testing.expectError(error.InvalidHistory, History.decode(a, disk, transcript.Identity.initTmux(2, 0, false, "another", "")));
    try std.testing.expect(!sameSession(transcript.Identity.init(1, 0, false, "", ""), transcript.Identity.init(2, 0, false, "", "")));
}

test "durable snapshots are bounded while live history stays complete and partial tails require rehydration" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var h: History = .{ .inode = 9, .offset = 100 };
    defer h.deinit(a);
    @memcpy(h.sid[0..3], "sid");
    const text = try a.alloc(u8, 64 * 1024);
    defer a.free(text);
    @memset(text, 'x');
    const message = try std.json.Stringify.valueAlloc(a, Message{ .role = "assistant", .text = text }, .{});
    defer a.free(message);
    for (0..20) |_| {
        try h.rows.appendSlice(a, message);
        try h.rows.append(a, '\n');
    }
    const before = h.rows.items.len;
    const disk = try h.encode(a, key);
    defer a.free(disk);
    try std.testing.expect(disk.len <= MAX_CACHE_BYTES);
    try std.testing.expectEqual(before, h.rows.items.len);
    var restored = try History.decode(a, disk, key);
    defer restored.deinit(a);
    try std.testing.expect(restored.restore_full);
    try std.testing.expect(restored.blocks.items.len > 0 and restored.blocks.items.len < 20);
    var clone = try restored.clone(a);
    defer clone.deinit(a);
    try std.testing.expect(clone.restore_full);
    try std.testing.expectError(error.EmptyReset, restored.apply(a, "@mp\t2\thistory\tok\tsid\t0\t0\t10\t0\tclaude\tterm-1\n@@MP_END@@\n", 2, key));
    try std.testing.expect(restored.blocks.items.len > 0);
}

test "reset pages rebuild offscreen until complete and clone retains pagination" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var h: History = .{};
    defer h.deinit(a);
    try h.apply(a, first, 1, key);
    try h.apply(a, "@mp\t2\thistory\tok\tsid\t0\t50\t10\t1\tclaude\tterm-1\n" ++ row ++ "@@MP_END@@\n", 2, key);
    try std.testing.expect(h.more and h.restore_full);
    var clone = try h.clone(a);
    defer clone.deinit(a);
    try std.testing.expect(clone.more and clone.restore_full);
    try h.apply(a, "@mp\t3\thistory\tok\tsid\t50\t100\t10\t0\tclaude\tterm-1\n@@MP_END@@\n", 3, key);
    try std.testing.expect(!h.more and !h.restore_full);
}

test "complete user fragments classify injections without transforming mixed messages or replies" {
    const a = std.testing.allocator;
    var h = History{};
    defer h.deinit(a);
    try h.rows.appendSlice(a, "{\"role\":\"user\",\"id\":\"injection\",\"timestamp\":\"2026-10-03T17:32:00Z\",\"text\":\"<cross-session-message from-name='RUNNER 7' from='private.sock'>\"}\n" ++
        "{\"role\":\"user\",\"id\":\"injection\",\"text\":\"scope &amp; tests</cross-session-message>\"}\n" ++
        "{\"role\":\"assistant\",\"text\":\"I will check it\"}\n" ++
        "{\"role\":\"user\",\"id\":\"mixed\",\"text\":\"Please explain\"}\n" ++
        "{\"role\":\"user\",\"id\":\"mixed\",\"text\":\"<task-notification>done</task-notification>\"}\n" ++
        "{\"role\":\"user\",\"text\":\"<task-notification><summary>Tests &lt;passed&gt;</summary></task-notification>\"}\n");
    try h.render(a);
    try std.testing.expectEqual(@as(usize, 4), h.blocks.items.len);
    try std.testing.expectEqual(md.Role.injected, h.blocks.items[0].role);
    try std.testing.expectEqual(md.Role.prose, h.blocks.items[1].role);
    try std.testing.expectEqual(md.Role.user, h.blocks.items[2].role);
    try std.testing.expectEqual(md.Role.injected, h.blocks.items[3].role);
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const injected = h.blocks.items[0];
    try std.testing.expectEqualSlices(u16, w("scope & tests"), h.text.items[injected.start .. injected.start + injected.len]);
    try std.testing.expectEqualSlices(u16, w("RUNNER 7"), std.mem.sliceTo(&injected.sender, 0));
    try std.testing.expectEqualSlices(u16, w("17:32"), &injected.time);
    const task = h.blocks.items[3];
    try std.testing.expectEqualSlices(u16, w("Tests <passed>"), h.text.items[task.start .. task.start + task.len]);
    try std.testing.expectEqualSlices(u16, w("Task"), std.mem.sliceTo(&task.sender, 0));
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    @memcpy(h.sid[0..3], "sid");
    const bytes = try h.encode(a, key);
    defer a.free(bytes);
    var restored = try History.decode(a, bytes, key);
    defer restored.deinit(a);
    try std.testing.expectEqualSlices(u16, h.text.items, restored.text.items);
    try std.testing.expectEqual(md.Role.injected, restored.blocks.items[0].role);
}

test "settlement: typed facts survive event-only delta clone and cache without rendering bubbles" {
    const a = std.testing.allocator;
    const key = transcript.Identity.init(1, 0, false, "sid", "");
    const pending = echo.Pending{ .prefix = &.{}, .text = std.unicode.utf8ToUtf16LeStringLiteral("/hormozi-skills:audit-offer can you use this also to review my own offer"), .anchor = .{ .after_ms = echo.stampMs("2026-10-13T11:06:00Z") } };
    var h = History{};
    defer h.deinit(a);
    try h.apply(a, "@mp\t1\thistory\tok\tsid\t0\t100\t9\t0\tclaude\t-\n{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-13T11:06:22.591Z\",\"settlement\":{\"operation\":\"enqueue\",\"content\":\"/hormozi-skills:audit-offer can you use this also to review my own offer\"}}\n@@MP_END@@\n", 1, key);
    try std.testing.expectEqual(@as(usize, 0), h.blocks.items.len);
    try std.testing.expectEqual(@as(i64, 0), (try h.deliveryEvidence(a, pending)).removed_ms);
    try h.apply(a, "@mp\t2\thistory\tok\tsid\t100\t200\t9\t0\tclaude\t-\n{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-13T11:06:59.442Z\",\"settlement\":{\"operation\":\"remove\",\"content\":\"/hormozi-skills:audit-offer can you use this also to review my own offer\"}}\n@@MP_END@@\n", 2, key);
    try std.testing.expectEqual(@as(usize, 0), h.text.items.len);
    try std.testing.expect((try h.deliveryEvidence(a, pending)).removed_ms > 0);
    var clone = try h.clone(a);
    defer clone.deinit(a);
    const disk = try clone.encode(a, key);
    defer a.free(disk);
    var restored = try History.decode(a, disk, key);
    defer restored.deinit(a);
    try std.testing.expect((try restored.deliveryEvidence(a, pending)).removed_ms > 0);
    try restored.apply(a, "@mp\t3\thistory\tok\tsid\t200\t300\t9\t0\tclaude\t-\n{\"role\":\"user\",\"text\":\"/hormozi-skills:audit-offer can you use this also to review my own offer\",\"timestamp\":\"2026-10-13T11:06:59.443Z\"}\n@@MP_END@@\n", 3, key);
    try std.testing.expectEqual(@as(usize, 1), restored.blocks.items.len);
    try std.testing.expectEqual(md.Role.user, restored.blocks.items[0].role);
    try std.testing.expect(echo.sameText(pending.text, restored.text.items));
}

test "settlement: remove dequeue and popAll track the matching queue entry, not unrelated traffic" {
    const a = std.testing.allocator;
    const pending = echo.Pending{ .prefix = &.{}, .text = std.unicode.utf8ToUtf16LeStringLiteral("/hormozi-skills:audit-offer can you use this also to review my own offer"), .anchor = .{ .after_ms = echo.stampMs("2026-10-13T11:06:00Z") } };
    for ([_][]const u8{ "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-13T11:06:59.442Z\",\"settlement\":{\"operation\":\"remove\",\"content\":\"/hormozi-skills:audit-offer can you use this also to review my own offer\"}}\n", "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-13T11:06:59.442Z\",\"settlement\":{\"operation\":\"dequeue\",\"content\":\"\"}}\n", "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-13T11:06:59.442Z\",\"settlement\":{\"operation\":\"popAll\",\"content\":\"\"}}\n" }) |removed| {
        var h = History{};
        defer h.deinit(a);
        try h.rows.appendSlice(a, "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-13T11:06:22.591Z\",\"settlement\":{\"operation\":\"enqueue\",\"content\":\"/hormozi-skills:audit-offer can you use this also to review my own offer\"}}\n");
        try h.rows.appendSlice(a, removed);
        try std.testing.expect((try h.deliveryEvidence(a, pending)).removed_ms > 0);
        try h.rows.appendSlice(a, "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-13T11:06:22.591Z\",\"settlement\":{\"operation\":\"enqueue\",\"content\":\"/hormozi-skills:audit-offer can you use this also to review my own offer\"}}\n");
        try std.testing.expectEqual(@as(i64, 0), (try h.deliveryEvidence(a, pending)).removed_ms);
    }
    var h = History{};
    defer h.deinit(a);
    try h.rows.appendSlice(a, "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-13T11:06:59.442Z\",\"settlement\":{\"operation\":\"enqueue\",\"content\":\"another message\"}}\n" ++ "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-13T11:06:22.591Z\",\"settlement\":{\"operation\":\"enqueue\",\"content\":\"/hormozi-skills:audit-offer can you use this also to review my own offer\"}}\n" ++ "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-13T11:06:59.442Z\",\"settlement\":{\"operation\":\"dequeue\",\"content\":\"\"}}\n");
    try std.testing.expectEqual(@as(i64, 0), (try h.deliveryEvidence(a, pending)).removed_ms);
    try h.rows.appendSlice(a, "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-13T11:06:59.442Z\",\"settlement\":{\"operation\":\"dequeue\",\"content\":\"\"}}\n");
    try std.testing.expect((try h.deliveryEvidence(a, pending)).removed_ms > 0);
    try h.rows.appendSlice(a, "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-13T11:06:59.442Z\",\"settlement\":{\"operation\":\"rejected\",\"content\":\"Unknown command: /hormozi-skills:audit-offer\"}}\n");
    try std.testing.expect((try h.deliveryEvidence(a, pending)).refused);
    var later = pending;
    later.anchor.after_ms = echo.stampMs("2026-10-13T11:06:59.442Z");
    try std.testing.expect(!(try h.deliveryEvidence(a, later)).refused);
    try std.testing.expectEqual(@as(i64, 0), (try h.deliveryEvidence(a, later)).removed_ms);
}
