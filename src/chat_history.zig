const std = @import("std");
const transcript = @import("chat_transcript.zig");
const md = @import("chat_markdown.zig");
const style = @import("chat_style.zig");
const echo = @import("chat_echo.zig");
const diff = @import("chat_diff.zig");

const Message = struct { diff: ?[]const u8 = null, added: usize = 0, removed: usize = 0, offset: u64 = 0, end: u64 = 0, segment: u64 = 0, result_offset: ?u64 = null, status: ?[]const u8 = null, detail: ?[]const u8 = null, role: []const u8, timestamp: []const u8 = "", text: []const u8 = "", id: []const u8 = "", read_id: ?[]const u8 = null, settlement: ?struct { operation: []const u8, content: []const u8 = "" } = null };
pub const ISSUE_349_STRICT_DEQUEUE = true;
pub const MAX_CACHE_BYTES = 16 * 1024 * 1024;
pub const TAIL_BYTES = 512 * 1024;
pub const CACHE_WRITE_MS = 30_000;
const Header = struct { version: u8 = 6, start: u64 = 0, inode: u64, offset: u64, sid: []const u8, host: u8, codex: bool, tmux: []const u8, mtime: u64 = 0, probe: []const u8 = "", read_sid: []const u8 = "", partial: bool = false };
pub const History = struct {
    status: transcript.Status = .{},
    rows: std.ArrayList(u8) = .empty,
    text: std.ArrayList(u16) = .empty,
    blocks: std.ArrayList(md.Block) = .empty,
    sid: [40]u8 = @splat(0),
    read_sid: [40]u8 = @splat(0),
    received_ms: u64 = 0,
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
    defer_render: bool = false,

    pub fn deinit(self: *History, a: std.mem.Allocator) void {
        self.rows.deinit(a);
        self.text.deinit(a);
        self.blocks.deinit(a);
        self.* = .{};
    }

    pub fn clone(self: History, a: std.mem.Allocator) !History {
        var result: History = .{ .status = self.status, .sid = self.sid, .read_sid = self.read_sid, .inode = self.inode, .offset = self.offset, .mtime = self.mtime, .probe = self.probe, .more = self.more, .restore_full = self.restore_full, .start = self.start, .revision = self.revision, .last_row = self.last_row, .last_text = self.last_text, .last_block = self.last_block, .changed_from = self.changed_from };
        errdefer result.deinit(a);
        try result.rows.appendSlice(a, self.rows.items);
        try result.text.appendSlice(a, self.text.items);
        try result.blocks.appendSlice(a, self.blocks.items);
        return result;
    }

    fn appendMessage(self: *History, a: std.mem.Allocator, bytes: []const u8, role: md.Role, stamp: []const u8, source_offset: u64, source_end: u64, segment: u64, id: []const u8) !void {
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
        const message_id = if (id.len == 0) 0 else std.hash.Wyhash.hash(std.hash.Wyhash.hash(0, if (self.read_sid[0] != 0) &self.read_sid else &self.sid), id);
        for (self.blocks.items[first_block..]) |*block| {
            block.message_id = message_id;
            block.source_offset = source_offset;
            block.source_end = source_end;
            block.segment = segment;
        }
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
        var last_read_id: std.ArrayList(u8) = .empty;
        defer last_read_id.deinit(a);
        var last_stamp: std.ArrayList(u8) = .empty;
        defer last_stamp.deinit(a);
        var last_role: md.Role = .prose;
        var source_offset: u64 = 0;
        var source_end: u64 = 0;
        var segment: u64 = 0;
        var message: std.ArrayList(u8) = .empty;
        defer message.deinit(a);
        var arena = std.heap.ArenaAllocator.init(a);
        defer arena.deinit();
        var tools = std.StringHashMap(struct { index: usize, input_start: usize, input_len: usize, row: usize, text: usize }).init(a);
        defer tools.deinit();
        var tool_arena = std.heap.ArenaAllocator.init(a);
        defer tool_arena.deinit();
        var row_at: usize = 0;
        while (lines.next()) |line| {
            defer row_at += line.len + 1;
            if (line.len == 0) continue;
            _ = arena.reset(.retain_capacity);
            const parsed = try std.json.parseFromSlice(Message, arena.allocator(), line, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
            const m = parsed.value;
            if (m.settlement != null) continue;
            if (std.mem.eql(u8, m.role, "tool_result")) {
                if (tools.get(m.id)) |tool| {
                    var block = &self.blocks.items[tool.index];
                    block.tool_status = std.meta.stringToEnum(md.ToolStatus, m.status orelse "ok") orelse .ok;
                    block.result_offset = m.offset;
                    var input_len = @min(tool.input_len, if (tool.input_len > 1800) @as(usize, 1799) else 1800);
                    if (input_len < tool.input_len and input_len > 0 and std.unicode.utf16IsHighSurrogate(self.text.items[tool.input_start + input_len - 1])) input_len -= 1;
                    const detail = try std.unicode.utf8ToUtf16LeAlloc(arena.allocator(), m.detail orelse "");
                    const start = self.text.items.len;
                    try self.text.ensureUnusedCapacity(a, 4000);
                    try self.text.appendSlice(a, self.text.items[tool.input_start..][0..input_len]);
                    if (input_len < tool.input_len) try self.text.append(a, 0x2026);
                    try self.text.appendSlice(a, &.{ '\n', '\n' });
                    const available = 4000 - (self.text.items.len - start);
                    var output_len = @min(detail.len, if (detail.len > available) available - 1 else available);
                    if (output_len < detail.len and output_len > 0 and std.unicode.utf16IsHighSurrogate(detail[output_len - 1])) output_len -= 1;
                    try self.text.appendSlice(a, detail[0..output_len]);
                    if (output_len < detail.len) try self.text.append(a, 0x2026);
                    block.detail_start = start;
                    block.detail_len = self.text.items.len - start;
                    if (m.diff) |patch| {
                        const wide = try std.unicode.utf8ToUtf16LeAlloc(arena.allocator(), patch);
                        block.diff_start = self.text.items.len;
                        block.diff_len = wide.len;
                        try self.text.appendSlice(a, wide);
                        const base = self.text.items[block.start..][0..diff.summaryLen(self.text.items[block.start..][0..block.len])];
                        const counts = try std.fmt.allocPrint(arena.allocator(), " +{d} -{d}", .{ m.added, m.removed });
                        const suffix_text = try std.unicode.utf8ToUtf16LeAlloc(arena.allocator(), counts);
                        const summary = try arena.allocator().dupe(u16, base);
                        block.start = self.text.items.len;
                        block.len = summary.len + suffix_text.len;
                        try self.text.appendSlice(a, summary);
                        try self.text.appendSlice(a, suffix_text);
                    }
                    self.last_text = self.text.items.len;
                    if (message.items.len == 0) {
                        self.last_row = row_at + line.len + 1;
                        self.last_block = self.blocks.items.len;
                    }
                }
                continue;
            }
            if (std.mem.eql(u8, m.role, "tool")) {
                if (message.items.len > 0) try self.appendMessage(a, message.items, last_role, last_stamp.items, source_offset, source_end, segment, last_read_id.items);
                message.clearRetainingCapacity();
                last_id.clearRetainingCapacity();
                if (m.text.len == 0) continue;
                const tool_text_start = self.text.items.len;
                try self.appendMessage(a, m.text, .tool, m.timestamp, m.offset, m.end, m.segment, m.id);
                const index = self.blocks.items.len - 1;
                var block = &self.blocks.items[index];
                block.tool_status = std.meta.stringToEnum(md.ToolStatus, m.status orelse "running") orelse .running;
                block.tool_id = std.hash.Wyhash.hash(0, m.id);
                block.result_offset = m.result_offset;
                const detail = try std.unicode.utf8ToUtf16LeAlloc(arena.allocator(), m.detail orelse "");
                block.detail_start = self.text.items.len;
                block.detail_len = detail.len;
                try self.text.appendSlice(a, detail);
                const patch = try std.unicode.utf8ToUtf16LeAlloc(arena.allocator(), m.diff orelse "");
                block.diff_start = self.text.items.len;
                block.diff_len = patch.len;
                try self.text.appendSlice(a, patch);
                if (m.id.len > 0) try tools.put(try tool_arena.allocator().dupe(u8, m.id), .{ .index = index, .input_start = block.detail_start, .input_len = block.detail_len, .row = row_at, .text = tool_text_start });
                self.last_row = row_at + line.len + 1;
                self.last_text = self.text.items.len;
                self.last_block = self.blocks.items.len;
                continue;
            }
            const role: md.Role = if (std.mem.eql(u8, m.role, "user")) .user else if (std.mem.eql(u8, m.role, "assistant")) .prose else continue;
            if (m.text.len == 0) return error.InvalidHistory;
            const merge = m.id.len > 0 and std.mem.eql(u8, m.id, last_id.items) and role == last_role and segment == m.segment;
            if (merge) {
                try message.append(a, '\n');
            } else {
                if (message.items.len > 0) try self.appendMessage(a, message.items, last_role, last_stamp.items, source_offset, source_end, segment, last_read_id.items);
                message.clearRetainingCapacity();
                source_offset = m.offset;
                segment = m.segment;
                self.last_row = row_at;
                self.last_text = self.text.items.len;
                self.last_block = self.blocks.items.len;
                last_stamp.clearRetainingCapacity();
                try last_stamp.appendSlice(a, m.timestamp);
            }
            source_end = m.end;
            try message.appendSlice(a, m.text);
            last_id.clearRetainingCapacity();
            try last_id.appendSlice(a, m.id);
            last_read_id.clearRetainingCapacity();
            try last_read_id.appendSlice(a, m.read_id orelse m.id);
            last_role = role;
        }
        if (message.items.len > 0) try self.appendMessage(a, message.items, last_role, last_stamp.items, source_offset, source_end, segment, last_read_id.items);
        var pending = tools.valueIterator();
        while (pending.next()) |tool| {
            if (self.blocks.items[tool.index].tool_status == .running and tool.index < self.last_block) {
                self.last_row = tool.row;
                self.last_text = tool.text;
                self.last_block = tool.index;
            }
        }
        for (self.blocks.items[0..self.last_block]) |block| {
            if (block.role == .tool) {
                self.last_text = @max(self.last_text, block.detail_start + block.detail_len);
                self.last_text = @max(self.last_text, block.diff_start + block.diff_len);
                self.last_text = @max(self.last_text, block.start + block.len);
            }
        }
    }

    pub fn deliveryEvidence(self: History, a: std.mem.Allocator, pending: echo.Pending) !echo.DeliveryEvidence {
        var result: echo.DeliveryEvidence = .{};
        var complete = (self.start == 0 and !self.restore_full) or !ISSUE_349_STRICT_DEQUEUE;
        var queue: std.ArrayList(struct { hash: u64, matches: bool }) = .empty;
        defer queue.deinit(a);
        var lines = std.mem.splitScalar(u8, self.rows.items, '\n');
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
            const matches = fresh and echo.sameText(content, pending.text);
            if (std.mem.eql(u8, fact.operation, "enqueue")) {
                try queue.append(a, .{ .hash = hash, .matches = matches });
                if (matches) result.removed_ms = 0;
            } else if (std.mem.eql(u8, fact.operation, "popAll")) {
                for (queue.items) |item| {
                    if (complete and fresh and item.matches) result.removed_ms = stamp;
                }
                queue.clearRetainingCapacity();
                complete = true;
            } else if (std.mem.eql(u8, fact.operation, "remove") or std.mem.eql(u8, fact.operation, "dequeue")) {
                var index: ?usize = null;
                if (content.len == 0) {
                    if (complete and queue.items.len > 0) index = 0;
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
        for (queue.items) |item| {
            if (item.matches) result.enqueued = true;
        }
        return result;
    }

    pub fn newMessages(self: History, next: History) usize {
        if (self.revision == 0 or self.restore_full or
            self.inode != next.inode or !std.mem.eql(u8, &self.sid, &next.sid) or next.offset <= self.offset) return 0;
        var count: usize = 0;
        var last_offset: ?u64 = null;
        for (next.blocks.items) |block| {
            if (!block.first or block.role == .tool or block.source_offset < self.offset) continue;
            if (last_offset == block.source_offset) continue;
            count += 1;
            last_offset = block.source_offset;
        }
        return count;
    }

    pub fn cursor(self: History) History {
        return .{ .status = self.status, .sid = self.sid, .read_sid = self.read_sid, .inode = self.inode, .offset = self.offset, .start = self.start, .mtime = self.mtime, .probe = self.probe, .more = self.more, .revision = self.revision };
    }

    pub fn updateCursor(self: *History, other: History) void {
        self.status = other.status;
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
        for (next.blocks.items) |*block| {
            block.start += self.last_text;
            if (block.role == .tool) {
                block.detail_start += self.last_text;
                block.diff_start += self.last_text;
            }
        }
        self.text.appendSliceAssumeCapacity(next.text.items);
        self.blocks.appendSliceAssumeCapacity(next.blocks.items);
        self.last_row += next.last_row;
        self.last_text += next.last_text;
        self.last_block += next.last_block;
        self.revision = next.revision;
        self.restore_full = false;
        self.updateCursor(next.*);
    }

    fn retainRows(self: *History, a: std.mem.Allocator, previous: History) !void {
        var arena = std.heap.ArenaAllocator.init(a);
        defer arena.deinit();
        const scratch = arena.allocator();
        var incoming = std.StringHashMap(struct { rows: std.ArrayList(u8) = .empty, used: bool = false, known: bool = false, index: usize }).init(scratch);
        var order: std.ArrayList([]const u8) = .empty;
        var lines = std.mem.splitScalar(u8, self.rows.items, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            const key = try rowIdentity(scratch, line);
            const slot = try incoming.getOrPut(key);
            if (!slot.found_existing) {
                slot.value_ptr.* = .{ .index = order.items.len };
                try order.append(scratch, key);
            }
            try slot.value_ptr.rows.appendSlice(scratch, line);
            try slot.value_ptr.rows.append(scratch, '\n');
        }
        lines = std.mem.splitScalar(u8, previous.rows.items, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            if (incoming.getPtr(try rowIdentity(scratch, line))) |entry| entry.known = true;
        }
        var rows: std.ArrayList(u8) = .empty;
        errdefer rows.deinit(a);
        var cursor_index: usize = 0;
        lines = std.mem.splitScalar(u8, previous.rows.items, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            const key = try rowIdentity(scratch, line);
            if (incoming.getPtr(key)) |replacement| {
                while (cursor_index <= replacement.index) : (cursor_index += 1) {
                    const added = incoming.getPtr(order.items[cursor_index]).?;
                    if (!added.known and !added.used) {
                        try rows.appendSlice(a, added.rows.items);
                        added.used = true;
                    }
                }
                if (!replacement.used) try rows.appendSlice(a, replacement.rows.items);
                replacement.used = true;
            } else {
                try rows.appendSlice(a, line);
                try rows.append(a, '\n');
            }
        }
        for (order.items) |key| {
            const entry = incoming.getPtr(key).?;
            if (!entry.used) try rows.appendSlice(a, entry.rows.items);
        }
        self.rows.deinit(a);
        self.rows = rows;
    }

    fn rowIdentity(a: std.mem.Allocator, line: []const u8) ![]const u8 {
        const parsed = try std.json.parseFromSlice(Message, a, line, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();
        const m = parsed.value;
        const id = m.read_id orelse m.id;
        return std.json.Stringify.valueAlloc(a, .{ m.role, id, m.segment, if (id.len == 0) m.timestamp else "", if (id.len == 0) m.text else "", if (id.len == 0) m.settlement else null }, .{});
    }

    pub fn encode(self: History, a: std.mem.Allocator, key: transcript.Identity) ![]u8 {
        var start: usize = 0;
        const budget = TAIL_BYTES - 512;
        if (self.rows.items.len > budget) {
            start = self.rows.items.len - budget;
            start += if (std.mem.indexOfScalar(u8, self.rows.items[start..], '\n')) |n| n + 1 else self.rows.items.len - start;
        }
        const header = try std.json.Stringify.valueAlloc(a, Header{ .inode = self.inode, .offset = self.offset, .start = self.start, .sid = std.mem.sliceTo(&self.sid, 0), .host = key.host, .codex = key.codex, .tmux = std.mem.sliceTo(&key.tmux, 0), .mtime = self.mtime, .probe = std.mem.sliceTo(&self.probe, 0), .read_sid = std.mem.sliceTo(&self.read_sid, 0), .partial = start > 0 or self.restore_full }, .{});
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
        if ((h.version < 2 or h.version > 6) or h.sid.len == 0 or h.sid.len >= 40 or h.read_sid.len >= 40 or bytes[bytes.len - 1] != '\n' or
            (h.probe.len != 0 and h.probe.len != 64) or h.host != key.host or h.codex != key.codex or !std.mem.eql(u8, h.tmux, std.mem.sliceTo(&key.tmux, 0)) or
            (key.sid[0] != 0 and !std.mem.eql(u8, h.sid, std.mem.sliceTo(&key.sid, 0)))) return error.InvalidHistory;
        var result: History = .{ .inode = h.inode, .offset = h.offset, .mtime = h.mtime, .restore_full = h.partial or h.version < 6, .start = h.start, .revision = 1 };
        errdefer result.deinit(a);
        @memcpy(result.sid[0..h.sid.len], h.sid);
        const read_sid = if (h.read_sid.len > 0) h.read_sid else h.sid;
        @memcpy(result.read_sid[0..read_sid.len], read_sid);
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
        var next: History = .{ .status = if (append or prepend) self.status else .{}, .inode = inode, .offset = end, .start = if (mode == null and !append) 0 else oldest, .mtime = mtime, .more = std.mem.eql(u8, more, "1"), .revision = self.revision +% 1 };
        @memcpy(next.probe[0..probe.len], probe);
        errdefer next.deinit(a);
        @memcpy(next.sid[0..sid.len], sid);
        next.read_sid = if (self.read_sid[0] != 0) self.read_sid else if (self.sid[0] != 0) self.sid else next.sid;
        var ended = false;
        while (lines.next()) |line| {
            if (std.mem.eql(u8, line, "@@MP_END@@")) {
                ended = true;
                break;
            }
            if (line.len == 0) return error.InvalidHistory;
            if (transcript.parseStatus(line)) |status| {
                next.status = status.status;
                continue;
            }
            try next.rows.appendSlice(a, line);
            try next.rows.append(a, '\n');
        }
        if (!ended) return error.InvalidHistory;
        while (lines.next()) |line| if (line.len != 0) return error.InvalidHistory;
        if (prepend and oldest == self.start) {
            next.deinit(a);
            return;
        }
        if (!append and !prepend and next.rows.items.len == 0 and self.rows.items.len > 0) return error.EmptyReset;
        if (append and next.rows.items.len == 0) {
            if (!std.meta.eql(self.status, next.status)) self.revision +%= 1;
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
        if (!prepend and mode != null and self.rows.items.len > 0) {
            if (inode == self.inode and std.mem.eql(u8, sid, std.mem.sliceTo(&self.sid, 0)) and end < self.offset) return error.InvalidHistory;
            try next.retainRows(a, self.*);
            if (inode == self.inode and std.mem.eql(u8, sid, std.mem.sliceTo(&self.sid, 0))) next.start = @min(next.start, self.start);
        }
        if (prepend) {
            var tail = self.cursor();
            defer tail.deinit(a);
            try tail.rows.appendSlice(a, self.rows.items);
            try tail.retainRows(a, next);
            next.rows.deinit(a);
            next.rows = tail.rows;
            tail.rows = .empty;
            next.updateCursor(self.*);
        }
        if (!self.defer_render) try next.render(a);
        next.restore_full = mode == null and next.more and self.rows.items.len > 0;
        self.deinit(a);
        self.* = next;
    }
};

pub const Backfill = struct {
    pages: std.ArrayList([]u8) = .empty,
    start: u64 = 0,

    pub fn deinit(self: *Backfill, a: std.mem.Allocator) void {
        for (self.pages.items) |page| a.free(page);
        self.pages.deinit(a);
        self.* = .{};
    }

    pub fn stage(self: *Backfill, a: std.mem.Allocator, page: *History) !void {
        try self.pages.ensureUnusedCapacity(a, 1);
        const rows = try page.rows.toOwnedSlice(a);
        self.pages.appendAssumeCapacity(rows);
        self.start = page.start;
        page.deinit(a);
    }

    pub fn finish(self: *Backfill, a: std.mem.Allocator, tail: History) !History {
        var result = tail.cursor();
        errdefer result.deinit(a);
        var size = tail.rows.items.len;
        for (self.pages.items) |page| size += page.len;
        try result.rows.ensureTotalCapacity(a, size);
        var i = self.pages.items.len;
        while (i > 0) {
            i -= 1;
            result.rows.appendSliceAssumeCapacity(self.pages.items[i]);
        }
        var recent = tail.cursor();
        defer recent.deinit(a);
        try recent.rows.appendSlice(a, tail.rows.items);
        try recent.retainRows(a, result);
        result.rows.deinit(a);
        result.rows = recent.rows;
        recent.rows = .empty;
        result.start = self.start;
        result.revision +%= 1;
        try result.render(a);
        self.deinit(a);
        return result;
    }
};

pub fn statusOnly(wire: []const u8) bool {
    var lines = std.mem.splitScalar(u8, wire, '\n');
    _ = lines.next() orelse return false;
    while (lines.next()) |line| {
        if (std.mem.eql(u8, line, "@@MP_END@@")) return true;
        if (transcript.parseStatus(line) == null) return false;
    }
    return false;
}

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

pub const NewMessages = struct {
    value: isize = 0,

    pub fn count(self: NewMessages) usize {
        return @abs(self.value);
    }

    pub fn visible(self: NewMessages, scrolled_up: bool) bool {
        return scrolled_up and self.value > 0;
    }

    pub fn arrive(self: *NewMessages, added: usize, scrolled_up: bool) void {
        if (!scrolled_up) return;
        const delta: isize = @intCast(added);
        self.value += if (self.value < 0) -delta else delta;
    }

    pub fn atBottom(self: *NewMessages, scrolled_up: bool) void {
        if (!scrolled_up) self.value = 0;
    }

    pub fn dismiss(self: *NewMessages) void {
        self.value = -@as(isize, @intCast(self.count()));
    }
};

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

pub fn followBottom(force: bool, pending: bool, scrolled_up: bool) bool {
    return force or pending or !scrolled_up;
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

pub fn showScreen(keyed: bool, file_blocks: usize, missing: bool, failures: u8) bool {
    return !keyed or (file_blocks == 0 and (missing or failures > 0));
}

pub fn screenText(raw: []const u16, width: usize, rows: usize, out: []u16) usize {
    if (width == 0) return 0;
    const available_rows = @min(rows, raw.len / width + @intFromBool(raw.len % width != 0));
    var written: usize = 0;
    var end: usize = 0;
    for (0..available_rows) |row_index| {
        const start = row_index * width;
        const line = std.mem.trimEnd(u16, raw[start .. start + @min(width, raw.len - start)], &.{ ' ', '\t', 0 });
        if (written == 0 and line.len == 0) continue;
        const separator: usize = if (written == 0) 0 else 2;
        if (separator > out.len - written or line.len > out.len - written - separator) break;
        if (separator != 0) {
            out[written] = '\r';
            out[written + 1] = '\n';
            written += 2;
        }
        @memcpy(out[written .. written + line.len], line);
        written += line.len;
        if (line.len != 0) end = written;
    }
    return end;
}

test "terminal fallback keeps every row of a real btop screen" {
    const a = std.testing.allocator;
    const fixtures = [_][]const u8{
        @embedFile("testdata/btop-screen.txt"),
        "owner@vps:~$ echo hi\nhi\nvalentin@vps:~$\n\n\n",
    };
    for (fixtures, 0..) |fixture, fixture_index| {
        const text = try std.unicode.utf8ToUtf16LeAlloc(a, fixture);
        defer a.free(text);
        var lines: std.ArrayList([]const u16) = .empty;
        defer lines.deinit(a);
        var split = std.mem.splitScalar(u16, text, '\n');
        var width: usize = 0;
        while (split.next()) |line| {
            width = @max(width, line.len);
            try lines.append(a, line);
        }
        const raw = try a.alloc(u16, width * lines.items.len);
        defer a.free(raw);
        @memset(raw, ' ');
        for (lines.items, 0..) |line, i| @memcpy(raw[i * width .. i * width + line.len], line);
        const out = try a.alloc(u16, raw.len + 2 * lines.items.len);
        defer a.free(out);
        const len = screenText(raw, width, lines.items.len, out);
        var first_row: usize = 0;
        var last = lines.items.len;
        while (first_row < last and std.mem.trimEnd(u16, lines.items[first_row], &.{ ' ', '\t', 0 }).len == 0) : (first_row += 1) {}
        while (last > first_row and std.mem.trimEnd(u16, lines.items[last - 1], &.{ ' ', '\t', 0 }).len == 0) : (last -= 1) {}
        var actual = std.mem.splitSequence(u16, out[0..len], &.{ '\r', '\n' });
        var count: usize = 0;
        while (actual.next()) |line| {
            try std.testing.expect(first_row + count < last);
            try std.testing.expectEqualSlices(u16, std.mem.trimEnd(u16, lines.items[first_row + count], &.{ ' ', '\t', 0 }), line);
            count += 1;
        }
        try std.testing.expectEqual(last - first_row, count);
        if (fixture_index == 0) {
            try std.testing.expectEqual(@as(u16, 0x256D), out[0]);
        } else {
            try std.testing.expectEqual(@as(usize, 3), count);
        }
    }
}

test "terminal screen text trims empty edges and stops at whole rows" {
    const raw = std.unicode.utf8ToUtf16LeStringLiteral("    " ++ " a\t\x00" ++ "    " ++ "bc  " ++ "    ");
    var out: [32]u16 = @splat(0xFFFF);
    const expected = std.unicode.utf8ToUtf16LeStringLiteral(" a\r\n\r\nbc");
    const len = screenText(raw, 4, 5, &out);
    try std.testing.expectEqualSlices(u16, expected, out[0..len]);
    try std.testing.expectEqual(@as(usize, 2), screenText(raw, 4, 5, out[0..7]));
    try std.testing.expectEqual(@as(usize, 0), screenText(raw, 4, 5, out[0..1]));
    try std.testing.expectEqual(@as(usize, 0), screenText(raw, 0, 5, &out));
    try std.testing.expectEqual(@as(usize, 0), screenText(raw, 4, 0, &out));
    try std.testing.expectEqual(@as(usize, 0), screenText(&.{}, 4, 5, &out));
    try std.testing.expectEqual(@as(usize, 0), screenText(raw[0..4], 4, 5, &out));
    const short_len = screenText(raw[0..14], 4, 9, &out);
    try std.testing.expectEqualSlices(u16, expected, out[0..short_len]);
}

test "a keyed tab whose transcript is missing or failing shows the terminal instead of an empty chat" {
    try std.testing.expect(showScreen(false, 0, false, 0));
    try std.testing.expect(!showScreen(true, 0, false, 0));
    try std.testing.expect(showScreen(true, 0, true, 0));
    try std.testing.expect(showScreen(true, 0, false, 2));
    try std.testing.expect(!showScreen(true, 12, true, 1));
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

test "ISSUE-349 incomplete queue cannot blame A for C before A is delivered" {
    const a = std.testing.allocator;
    const key = transcript.Identity.init(1, 0, false, "sid", "");
    const text = std.unicode.utf8ToUtf16LeStringLiteral("please check the build A");
    var h: History = .{};
    defer h.deinit(a);
    const wire = "@mp\t1\thistory\tok\tsid\t100\t200\t9\t0\tclaude\t-\t1\taaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\ttail\t100\n{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T15:22:08.000Z\",\"settlement\":{\"operation\":\"enqueue\",\"content\":\"please check the build A\"}}\n{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T15:22:31.000Z\",\"settlement\":{\"operation\":\"enqueue\",\"content\":\"please check the build B\"}}\n{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T15:23:23.429Z\",\"settlement\":{\"operation\":\"dequeue\",\"content\":\"\"}}\n{\"role\":\"user\",\"text\":\"please check the build C\",\"timestamp\":\"2026-10-17T15:23:23.843Z\"}\n@@MP_END@@\n";
    try h.apply(a, wire, 1, key);
    var pending = [_]echo.Pending{.{ .text = text, .prefix = text, .anchor = .{ .after_ms = echo.stampMs("2026-10-17T15:23:23.843Z"), .sent_ms = echo.stampMs("2026-10-17T15:22:08.000Z") } }};
    try std.testing.expectEqual(@as(i64, 0), (try h.deliveryEvidence(a, pending[0])).removed_ms);
    pending[0].anchor.after_ms = echo.stampMs("2026-10-17T15:22:07.000Z");
    try std.testing.expectEqual(@as(i64, 0), (try h.deliveryEvidence(a, pending[0])).removed_ms);
    pending[0].anchor.after_ms = echo.stampMs("2026-10-17T15:23:23.843Z");
    try h.apply(a, "@mp\t2\thistory\tok\tsid\t200\t300\t9\t0\tclaude\t-\t1\tbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\tdelta\t100\n{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T15:24:01.000Z\",\"settlement\":{\"operation\":\"enqueue\",\"content\":\"please check the build D\"}}\n{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T15:24:31.000Z\",\"settlement\":{\"operation\":\"enqueue\",\"content\":\"please check the build E\"}}\n{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T15:25:01.000Z\",\"settlement\":{\"operation\":\"enqueue\",\"content\":\"please check the build F\"}}\n{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T15:25:59.000Z\",\"settlement\":{\"operation\":\"remove\",\"content\":\"please check the build E\"}}\n{\"role\":\"user\",\"text\":\"please check the build E\",\"timestamp\":\"2026-10-17T15:25:59.000Z\"}\n{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T15:27:43.000Z\",\"settlement\":{\"operation\":\"dequeue\",\"content\":\"\"}}\n{\"role\":\"user\",\"text\":\"please check the build A\",\"timestamp\":\"2026-10-17T15:27:44.000Z\"}\n@@MP_END@@\n", 2, key);
    try std.testing.expectEqual(@as(i64, 0), (try h.deliveryEvidence(a, pending[0])).removed_ms);
    var users: [3]echo.UserBlock = undefined;
    for (h.blocks.items, 0..) |block, i| users[i] = .{ .text = h.text.items[block.start..][0..block.len], .stamp_ms = block.stamp_ms };
    var picked: [1]?usize = undefined;
    echo.assign(&pending, &users, false, &.{}, &picked);
    try std.testing.expectEqual(@as(?usize, 2), picked[0]);
}

test "ISSUE-349 popAll establishes an empty point but cannot remove an uncertain pending" {
    const a = std.testing.allocator;
    var h: History = .{ .start = 100 };
    defer h.deinit(a);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("please check the build");
    const pending: echo.Pending = .{ .text = text, .prefix = text, .anchor = .{ .after_ms = 1 } };
    const enqueue = "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T15:22:08Z\",\"settlement\":{\"operation\":\"enqueue\",\"content\":\"please check the build\"}}\n";
    const pop = "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T15:23:23Z\",\"settlement\":{\"operation\":\"popAll\",\"content\":\"\"}}\n";
    try h.rows.appendSlice(a, enqueue ++ pop);
    try std.testing.expectEqual(@as(i64, 0), (try h.deliveryEvidence(a, pending)).removed_ms);
    try h.rows.appendSlice(a, enqueue ++ pop);
    try std.testing.expect((try h.deliveryEvidence(a, pending)).removed_ms > 0);
}

test "ISSUE-349 a partial disk cache is not a complete queue even with zero start" {
    const a = std.testing.allocator;
    var h: History = .{ .restore_full = true };
    defer h.deinit(a);
    const text = std.unicode.utf8ToUtf16LeStringLiteral("please check the build");
    const pending: echo.Pending = .{ .text = text, .prefix = text, .anchor = .{ .after_ms = 1 } };
    try h.rows.appendSlice(a, "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T15:22:08Z\",\"settlement\":{\"operation\":\"enqueue\",\"content\":\"please check the build\"}}\n" ++
        "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T15:23:23Z\",\"settlement\":{\"operation\":\"dequeue\",\"content\":\"\"}}\n");
    try std.testing.expectEqual(@as(i64, 0), (try h.deliveryEvidence(a, pending)).removed_ms);
    try h.rows.appendSlice(a, "{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T15:25:59Z\",\"settlement\":{\"operation\":\"remove\",\"content\":\"please check the build\"}}\n");
    try std.testing.expect((try h.deliveryEvidence(a, pending)).removed_ms > 0);
}

test "ISSUE-349 outstanding exact enqueue survives unrelated strict dequeue and never times out" {
    const a = std.testing.allocator;
    const key = transcript.Identity.init(1, 0, false, "sid", "");
    const pending = echo.Pending{ .prefix = &.{}, .text = std.unicode.utf8ToUtf16LeStringLiteral("please check the build"), .anchor = .{ .after_ms = echo.stampMs("2026-10-17T12:00:00Z") } };
    var h = History{};
    defer h.deinit(a);
    try h.apply(a, "@mp\t1\thistory\tok\tsid\t500\t600\t9\t0\tclaude\t-\t1\t\ttail\t500\n{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T12:00:01Z\",\"settlement\":{\"operation\":\"enqueue\",\"content\":\"please check the build\"}}\n{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T12:00:02Z\",\"settlement\":{\"operation\":\"dequeue\",\"content\":\"\"}}\n@@MP_END@@\n", 1, key);
    var facts = try h.deliveryEvidence(a, pending);
    try std.testing.expect(facts.enqueued);
    try std.testing.expectEqual(@as(i64, 0), facts.removed_ms);
    var watch = echo.DeliveryWatch{};
    try std.testing.expectEqual(echo.TranscriptDecision.queued, echo.transcriptStatus(&watch, true, 600_000, 600_000, if (facts.enqueued) .enqueued else .none));
    try h.apply(a, "@mp\t2\thistory\tok\tsid\t600\t700\t9\t0\tclaude\t-\t2\t\tdelta\t500\n{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T12:00:03Z\",\"settlement\":{\"operation\":\"remove\",\"content\":\"please check the build\"}}\n@@MP_END@@\n", 2, key);
    facts = try h.deliveryEvidence(a, pending);
    try std.testing.expect(!facts.enqueued);
    try std.testing.expect(facts.removed_ms > 0);
}

test "ISSUE-349 enqueue content must match the whole pending message" {
    const a = std.testing.allocator;
    const key = transcript.Identity.init(1, 0, false, "sid", "");
    var h = History{};
    defer h.deinit(a);
    try h.apply(a, "@mp\t1\thistory\tok\tsid\t0\t100\t9\t0\tclaude\t-\n{\"role\":\"assistant\",\"text\":\"\",\"timestamp\":\"2026-10-17T12:00:01Z\",\"settlement\":{\"operation\":\"enqueue\",\"content\":\"please check the build and tests\"}}\n@@MP_END@@\n", 1, key);
    const facts = try h.deliveryEvidence(a, .{ .prefix = &.{}, .text = std.unicode.utf8ToUtf16LeStringLiteral("please check the build"), .anchor = .{ .after_ms = echo.stampMs("2026-10-17T12:00:00Z") } });
    try std.testing.expect(!facts.enqueued);
}

test "ISSUE-263 tool row is one folded block and later result pairs across worker suffix and cache" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var h: History = .{};
    defer h.deinit(a);
    try h.apply(a, "@mp\t1\thistory\tok\tsid\t0\t100\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"user\",\"text\":\"please test\"}\n" ++
        "{\"role\":\"tool\",\"id\":\"call-263\",\"text\":\"Ran tests\",\"status\":\"running\",\"detail\":\"zig build test\"}\n" ++
        "{\"role\":\"assistant\",\"text\":\"Waiting for tests\"}\n@@MP_END@@\n", 1, key);
    try std.testing.expectEqual(@as(usize, 3), h.blocks.items.len);
    try std.testing.expectEqual(md.Role.tool, h.blocks.items[1].role);
    try std.testing.expectEqual(md.ToolStatus.running, h.blocks.items[1].tool_status);
    try std.testing.expect(!h.blocks.items[1].tool_open);
    try std.testing.expectEqual(@as(i32, 0), style.headerHeight(h.blocks.items[1], 28));
    var suffix_page = try h.suffix(a);
    defer suffix_page.deinit(a);
    try suffix_page.apply(a, "@mp\t2\thistory\tok\tsid\t100\t200\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"tool_result\",\"id\":\"unmatched\",\"text\":\"\",\"status\":\"ok\",\"detail\":\"ignored\"}\n" ++
        "{\"role\":\"tool_result\",\"id\":\"call-263\",\"text\":\"\",\"status\":\"error\",\"detail\":\"Exit code: 1\"}\n@@MP_END@@\n", 2, key);
    try h.appendParsed(a, &suffix_page);
    try std.testing.expectEqual(@as(usize, 3), h.blocks.items.len);
    const tool = h.blocks.items[1];
    try std.testing.expectEqual(md.ToolStatus.@"error", tool.tool_status);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Ran tests"), h.text.items[tool.start..][0..tool.len]);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("zig build test\n\nExit code: 1"), h.text.items[tool.detail_start..][0..tool.detail_len]);
    const disk = try h.encode(a, key);
    defer a.free(disk);
    var restored = try History.decode(a, disk, key);
    defer restored.deinit(a);
    try std.testing.expect(!restored.restore_full);
    try std.testing.expectEqual(md.ToolStatus.@"error", restored.blocks.items[1].tool_status);
    try std.testing.expectEqualSlices(u16, h.text.items, restored.text.items);
    try std.testing.expectEqual(@as(usize, 1), h.changed_from);
}

test "ISSUE-263 unknown roles are skipped and tool markdown stays one block" {
    const a = std.testing.allocator;
    var h: History = .{};
    defer h.deinit(a);
    try h.rows.appendSlice(a, "{\"role\":\"future_role\",\"future_field\":true}\n" ++
        "{\"role\":\"tool_result\",\"id\":\"orphan\",\"status\":\"ok\"}\n" ++
        "{\"role\":\"tool\",\"id\":\"call\",\"text\":\"Edited main.zig\\n\\n```zig\\ncode\\n```\",\"status\":\"ok\",\"detail\":\"patch\"}\n" ++
        "{\"role\":\"assistant\",\"text\":\"still visible\"}\n");
    try h.render(a);
    try std.testing.expectEqual(@as(usize, 2), h.blocks.items.len);
    try std.testing.expectEqual(md.Role.tool, h.blocks.items[0].role);
    try std.testing.expectEqual(md.ToolStatus.ok, h.blocks.items[0].tool_status);
    try std.testing.expectEqual(md.Role.prose, h.blocks.items[1].role);
}

test "ISSUE-402 pre-segment cache versions require transcript rehydration" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    for ([_]u8{ '2', '3', '4' }) |version| {
        const bytes = try a.dupe(u8, "{\"version\":3,\"inode\":9,\"offset\":100,\"sid\":\"sid\",\"host\":0,\"codex\":false,\"tmux\":\"term-1\"}\n" ++ row);
        defer a.free(bytes);
        bytes[11] = version;
        var restored = try History.decode(a, bytes, key);
        defer restored.deinit(a);
        try std.testing.expect(restored.restore_full);
    }
}

test "ISSUE-263 replacement results retain input and bounded valid Unicode details" {
    const a = std.testing.allocator;
    var h: History = .{};
    defer h.deinit(a);
    const input = "input " ** 400;
    const output = "😀" ** 3000;
    const call = try std.json.Stringify.valueAlloc(a, Message{ .role = "tool", .id = "call", .text = "Ran tests", .detail = input }, .{});
    defer a.free(call);
    const result = try std.json.Stringify.valueAlloc(a, Message{ .role = "tool_result", .id = "call", .status = "error", .detail = output }, .{});
    defer a.free(result);
    try h.rows.appendSlice(a, call);
    try h.rows.append(a, '\n');
    try h.rows.appendSlice(a, result);
    try h.rows.append(a, '\n');
    try h.render(a);
    const block = h.blocks.items[0];
    try std.testing.expect(block.detail_len <= 4000);
    const detail = try std.unicode.utf16LeToUtf8Alloc(a, h.text.items[block.detail_start..][0..block.detail_len]);
    defer a.free(detail);
    try std.testing.expect(std.mem.endsWith(u8, detail, "…"));
    h.text.clearRetainingCapacity();
    h.blocks.clearRetainingCapacity();
    try h.rows.appendSlice(a, "{\"role\":\"tool_result\",\"id\":\"call\",\"status\":\"ok\",\"detail\":\"passed\"}\n");
    try h.render(a);
    const updated = h.blocks.items[0];
    try std.testing.expectEqual(md.ToolStatus.ok, updated.tool_status);
    const final_detail = try std.unicode.utf16LeToUtf8Alloc(a, h.text.items[updated.detail_start..][0..updated.detail_len]);
    defer a.free(final_detail);
    try std.testing.expect(std.mem.endsWith(u8, final_detail, "…\n\npassed"));
    try std.testing.expect(std.mem.indexOf(u8, final_detail, "😀") == null);
}

test "ISSUE-263 completed tools release the settled prefix while unresolved calls still pair" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    for ([_]bool{ false, true }) |paired| {
        var h: History = .{};
        defer h.deinit(a);
        try h.rows.appendSlice(a, if (paired)
            "{\"role\":\"tool\",\"id\":\"done\",\"text\":\"Ran tests\",\"status\":\"ok\",\"detail\":\"passed\"}\n"
        else
            "{\"role\":\"tool\",\"id\":\"done\",\"text\":\"Ran tests\",\"detail\":\"test\"}\n" ++
                "{\"role\":\"tool_result\",\"id\":\"done\",\"status\":\"ok\",\"detail\":\"passed\"}\n");
        for (0..10000) |_| try h.rows.appendSlice(a, "{\"role\":\"assistant\",\"text\":\"later\"}\n");
        try h.render(a);
        try std.testing.expectEqual(@as(usize, 10001), h.blocks.items.len);
        try std.testing.expectEqual(@as(usize, 10000), h.last_block);
        var suffix = try h.suffix(a);
        defer suffix.deinit(a);
        try std.testing.expectEqual(@as(usize, 1), suffix.blocks.items.len);
    }
    var h: History = .{};
    defer h.deinit(a);
    try h.apply(a, "@mp\t1\thistory\tok\tsid\t0\t100\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"tool\",\"id\":\"first\",\"text\":\"First\",\"detail\":\"input\"}\n" ++
        "{\"role\":\"tool\",\"id\":\"pending\",\"text\":\"Second\",\"detail\":\"input\"}\n" ++
        "{\"role\":\"tool_result\",\"id\":\"first\",\"status\":\"ok\",\"detail\":\"done\"}\n" ++
        "{\"role\":\"assistant\",\"id\":\"message\",\"text\":\"Waiting\"}\n@@MP_END@@\n", 1, key);
    try std.testing.expectEqual(@as(usize, 1), h.last_block);
    var suffix = try h.suffix(a);
    defer suffix.deinit(a);
    try suffix.apply(a, "@mp\t2\thistory\tok\tsid\t100\t200\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"tool_result\",\"id\":\"pending\",\"status\":\"error\",\"detail\":\"failed\"}\n" ++
        "{\"role\":\"assistant\",\"id\":\"message\",\"text\":\"Finished\"}\n@@MP_END@@\n", 2, key);
    try h.appendParsed(a, &suffix);
    try std.testing.expectEqual(@as(usize, 2), h.last_block);
    try std.testing.expectEqual(md.ToolStatus.@"error", h.blocks.items[1].tool_status);
    const first_tool = h.blocks.items[0];
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("input\n\ndone"), h.text.items[first_tool.detail_start..][0..first_tool.detail_len]);
    const detail = h.blocks.items[1];
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("input\n\nfailed"), h.text.items[detail.detail_start..][0..detail.detail_len]);
    var settled = try h.suffix(a);
    defer settled.deinit(a);
    try std.testing.expectEqual(@as(usize, 1), settled.blocks.items.len);
    try settled.apply(a, "@mp\t3\thistory\tok\tsid\t200\t300\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"assistant\",\"text\":\"Next\"}\n@@MP_END@@\n", 3, key);
    try h.appendParsed(a, &settled);
    try std.testing.expectEqual(md.ToolStatus.@"error", h.blocks.items[1].tool_status);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("input\n\nfailed"), h.text.items[h.blocks.items[1].detail_start..][0..h.blocks.items[1].detail_len]);
}

test "status row metadata is independent of conversation rows across deltas and older pages" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var h: History = .{};
    defer h.deinit(a);
    try h.apply(a, "@mp\t1\thistory\tok\tsid\t100\t200\t9\t0\tclaude\tterm-1\t1\t\ttail\t100\n{\"role\":\"user\",\"text\":\"hello\"}\n{\"role\":\"status\",\"model\":\"Opus 5.5\",\"percent_left\":62}\n@@MP_END@@\n", 1, key);
    try std.testing.expectEqual(@as(usize, 1), h.blocks.items.len);
    try std.testing.expectEqual(@as(?u8, 62), h.status.percent_left);
    const revision = h.revision;
    try h.apply(a, "@mp\t2\thistory\tok\tsid\t200\t200\t9\t0\tclaude\tterm-1\t1\t\tdelta\t100\n{\"role\":\"status\",\"model\":\"Opus 5.5\",\"percent_left\":62}\n@@MP_END@@\n", 2, key);
    try std.testing.expectEqual(revision, h.revision);
    try h.apply(a, "@mp\t3\thistory\tok\tsid\t200\t300\t9\t0\tclaude\tterm-1\t2\t\tdelta\t100\n{\"role\":\"status\",\"percent_left\":50,\"todos\":[]}\n@@MP_END@@\n", 3, key);
    try std.testing.expectEqual(revision + 1, h.revision);
    try std.testing.expectEqual(@as(usize, 1), h.blocks.items.len);
    try std.testing.expectEqual(@as(?u8, 50), h.status.percent_left);
    var copy = try h.clone(a);
    defer copy.deinit(a);
    try std.testing.expectEqualDeep(h.status, copy.status);
    try h.apply(a, "@mp\t4\thistory\tok\tsid\t0\t100\t9\t0\tclaude\tterm-1\t2\t\tolder\t0\n{\"role\":\"user\",\"text\":\"older\"}\n@@MP_END@@\n", 4, key);
    try std.testing.expectEqual(@as(usize, 2), h.blocks.items.len);
    try std.testing.expectEqual(@as(?u8, 50), h.status.percent_left);
}

test "ISSUE-268 older pages retain source-mapped hits past the old native block limit" {
    const a = std.testing.allocator;
    var h: History = .{};
    defer h.deinit(a);
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "/work");
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try wire.appendSlice(a, "@mp\t1\thistory\tok\tsid\t0\t400\t9\t0\tclaude\tterm-1\n");
    for (0..350) |i| {
        const line = try std.fmt.allocPrint(a, "{{\"role\":\"user\",\"text\":\"message {d}\",\"offset\":{d},\"end\":{d}}}\n", .{ i, i, i + 1 });
        defer a.free(line);
        try wire.appendSlice(a, line);
    }
    try wire.appendSlice(a, "@@MP_END@@\n");
    try h.apply(a, wire.items, 1, key);
    try std.testing.expectEqual(@as(usize, 350), h.blocks.items.len);
    try std.testing.expectEqual(@as(u64, 0), h.blocks.items[0].source_offset);
    try std.testing.expectEqual(@as(u64, 1), h.blocks.items[0].source_end);
    try std.testing.expectEqual(@as(u64, 349), h.blocks.items[349].source_offset);
}

test "ISSUE-270 diff survives result delta suffix clone cache and settled-prefix append" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var h: History = .{};
    defer h.deinit(a);
    try h.apply(a, "@mp\t1\thistory\tok\tsid\t0\t100\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"user\",\"text\":\"edit this\"}\n" ++
        "{\"role\":\"tool\",\"id\":\"edit\",\"text\":\"Edited foo +1 -1\",\"status\":\"running\",\"detail\":\"input\",\"diff\":\"-old\\n+fallback\"}\n@@MP_END@@\n", 1, key);
    const initial = h.blocks.items[1];
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("-old\n+fallback"), h.text.items[initial.diff_start..][0..initial.diff_len]);
    var next = try h.suffix(a);
    defer next.deinit(a);
    try next.apply(a, "@mp\t2\thistory\tok\tsid\t100\t200\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"tool_result\",\"id\":\"edit\",\"status\":\"ok\",\"detail\":\"done\",\"diff\":\"-old\\n+real\\n+extra\",\"added\":2,\"removed\":1}\n" ++
        "{\"role\":\"assistant\",\"text\":\"finished\"}\n@@MP_END@@\n", 2, key);
    try h.appendParsed(a, &next);
    var cloned = try h.clone(a);
    defer cloned.deinit(a);
    const encoded = try cloned.encode(a, key);
    defer a.free(encoded);
    var cached = try History.decode(a, encoded, key);
    defer cached.deinit(a);
    try cached.apply(a, "@mp\t3\thistory\tok\tsid\t200\t300\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"tool\",\"id\":\"next\",\"text\":\"Wrote next +1 -0\",\"status\":\"ok\",\"diff\":\"+next\"}\n@@MP_END@@\n", 3, key);
    for ([_]*History{ &h, &cloned, &cached }) |history| {
        const block = history.blocks.items[1];
        try std.testing.expect(!block.tool_open);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("-old\n+real\n+extra"), history.text.items[block.diff_start..][0..block.diff_len]);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Edited foo +2 -1"), history.text.items[block.start..][0..block.len]);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("input\n\ndone"), history.text.items[block.detail_start..][0..block.detail_len]);
    }
    const last = cached.blocks.items[cached.blocks.items.len - 1];
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("+next"), cached.text.items[last.diff_start..][0..last.diff_len]);
}

test "ISSUE-402 identical split text keeps find identity through suffix clone and cache" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "/work");
    var h: History = .{};
    defer h.deinit(a);
    try h.apply(a, "@mp\t1\thistory\tok\tsid\t0\t100\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"assistant\",\"id\":\"reply\",\"text\":\"needle\",\"offset\":0,\"end\":100,\"segment\":0}\n" ++
        "{\"role\":\"tool\",\"id\":\"t\",\"text\":\"Read\",\"offset\":0,\"end\":100}\n" ++
        "{\"role\":\"assistant\",\"id\":\"reply:text:0:2\",\"text\":\"needle\",\"offset\":0,\"end\":100,\"segment\":2}\n@@MP_END@@\n", 1, key);
    var next = try h.suffix(a);
    defer next.deinit(a);
    try next.apply(a, "@mp\t2\thistory\tok\tsid\t100\t150\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"tool_result\",\"id\":\"t\",\"offset\":100,\"end\":150}\n@@MP_END@@\n", 2, key);
    try h.appendParsed(a, &next);
    var cloned = try h.clone(a);
    defer cloned.deinit(a);
    const bytes = try h.encode(a, key);
    defer a.free(bytes);
    var cached = try History.decode(a, bytes, key);
    defer cached.deinit(a);
    const find = @import("chat_find.zig");
    var result = try find.parse(a, "@mp\t3\tsearch\tok\tsid\t9\t150\t2\t0\tclaude\tterm-1\n" ++
        "{\"offset\":0,\"end\":100,\"segment\":0,\"role\":\"assistant\",\"timestamp\":\"\",\"snippet\":\"needle\"}\n" ++
        "{\"offset\":0,\"end\":100,\"segment\":2,\"role\":\"assistant\",\"timestamp\":\"\",\"snippet\":\"needle\"}\n@@MP_END@@\n", 3, false, "term-1");
    defer result.deinit();
    for ([_]*History{ &h, &cloned, &cached }) |history| {
        try std.testing.expectEqual(@as(usize, 3), history.blocks.items.len);
        for (result.hits, 0..) |hit, index| {
            for (history.blocks.items, 0..) |block, block_index| {
                try std.testing.expectEqual(block_index == index * 2, find.contains(block, hit));
            }
        }
    }
}

test "IGSH-720 passive messages preserve the anchor while forced refresh follows" {
    const follow = followBottom(false, false, true);
    try std.testing.expect(!follow);
    try std.testing.expectEqual(@as(i32, 120), scrollAfterLayout(1400, 800, 120, follow, 100, 20));
    try std.testing.expectEqual(@as(i32, 200), scrollAfterLayout(1600, 800, 120, follow, 180, 20));
    try std.testing.expectEqual(@as(i32, 800), scrollAfterLayout(1600, 800, 120, followBottom(true, false, true), 180, 20));
}

test "IGSH-720 bottom follows new messages until upward scrolling clears pending" {
    try std.testing.expect(followBottom(false, false, false));
    try std.testing.expectEqual(@as(i32, 600), scrollAfterLayout(1400, 800, 400, followBottom(false, false, false), null, 0));
    try std.testing.expectEqual(@as(i32, 600), scrollAfterLayout(1400, 800, 120, followBottom(false, true, true), null, 0));
    try std.testing.expect(!followBottom(false, false, true));
    try std.testing.expectEqual(@as(i32, 120), scrollAfterLayout(1600, 800, 120, followBottom(false, false, true), null, 0));
}

test "IGSH-720 fresh sends and forced refreshes show the bottom even when scrolled up" {
    for ([_][2]bool{ .{ false, true }, .{ true, false }, .{ true, true } }) |request| {
        const follow = followBottom(request[0], request[1], true);
        try std.testing.expect(follow);
        try std.testing.expectEqual(@as(i32, 1000), scrollAfterLayout(1800, 800, 200, follow, 160, 40));
    }
    try std.testing.expectEqual(@as(i32, 200), scrollAfterLayout(1800, 800, 200, followBottom(false, false, true), 160, 40));
}

test "IGSH-813 arrival while scrolled up increments only new message starts" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var before: History = .{};
    defer before.deinit(a);
    try before.apply(a, "@mp\t1\thistory\tok\tsid\t0\t100\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"user\",\"text\":\"already loaded\",\"offset\":0,\"end\":100}\n@@MP_END@@\n", 1, key);
    var after = try before.clone(a);
    defer after.deinit(a);
    try after.apply(a, "@mp\t2\thistory\tok\tsid\t100\t300\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"assistant\",\"id\":\"reply\",\"text\":\"# Heading\\n\\nNew reply\",\"offset\":100,\"end\":200}\n" ++
        "{\"role\":\"tool\",\"id\":\"tool\",\"text\":\"Read file\",\"offset\":200,\"end\":300}\n@@MP_END@@\n", 2, key);
    var counter: NewMessages = .{};
    counter.arrive(before.newMessages(after), true);
    try std.testing.expectEqual(@as(usize, 1), counter.count());
    try std.testing.expect(counter.visible(true));
    counter.arrive(after.newMessages(after), true);
    try std.testing.expectEqual(@as(usize, 1), counter.count());
    before.more = true;
    after.more = true;
    try std.testing.expectEqual(@as(usize, 1), before.newMessages(after));
    after.inode = 10;
    try std.testing.expectEqual(@as(usize, 0), before.newMessages(after));
}

test "IGSH-813 arrival at bottom does not count or show a pill" {
    var counter: NewMessages = .{};
    counter.arrive(3, false);
    try std.testing.expectEqual(@as(usize, 0), counter.count());
    try std.testing.expect(!counter.visible(false));
    try std.testing.expect(!counter.visible(true));
}

test "IGSH-813 reaching bottom resets but scrolling elsewhere retains the count" {
    var counter: NewMessages = .{};
    counter.arrive(2, true);
    counter.atBottom(true);
    counter.atBottom(true);
    try std.testing.expectEqual(@as(usize, 2), counter.count());
    counter.atBottom(false);
    try std.testing.expectEqual(@as(usize, 0), counter.count());
    try std.testing.expect(!counter.visible(true));
}

test "IGSH-813 close hides without losing the count including later arrivals" {
    var counter: NewMessages = .{};
    counter.arrive(2, true);
    counter.dismiss();
    try std.testing.expectEqual(@as(usize, 2), counter.count());
    try std.testing.expect(!counter.visible(true));
    counter.atBottom(true);
    counter.arrive(1, true);
    try std.testing.expectEqual(@as(usize, 3), counter.count());
    try std.testing.expect(!counter.visible(true));
    counter.atBottom(false);
    counter.arrive(1, true);
    try std.testing.expect(counter.visible(true));
    try std.testing.expectEqual(@as(usize, 1), counter.count());
}

test "IGSH-813 loaded history repeated refresh streaming edits and prepends are not arrivals" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var before: History = .{};
    defer before.deinit(a);
    try before.apply(a, "@mp\t1\thistory\tok\tsid\t0\t100\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"assistant\",\"id\":\"reply\",\"text\":\"stream\",\"offset\":0,\"end\":100}\n@@MP_END@@\n", 1, key);
    try std.testing.expectEqual(@as(usize, 0), (History{}).newMessages(before));
    try std.testing.expectEqual(@as(usize, 0), before.newMessages(before));
    var after = try before.clone(a);
    defer after.deinit(a);
    try after.apply(a, "@mp\t2\thistory\tok\tsid\t100\t200\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"assistant\",\"id\":\"reply\",\"text\":\"continues\",\"offset\":100,\"end\":200}\n@@MP_END@@\n", 2, key);
    try std.testing.expectEqual(@as(usize, 0), before.newMessages(after));
    try std.testing.expectEqual(@as(usize, 0), after.newMessages(before));
    before.more = true;
    try std.testing.expectEqual(@as(usize, 0), before.newMessages(after));
    before.more = false;
    before.restore_full = true;
    try std.testing.expectEqual(@as(usize, 0), before.newMessages(after));
}

test "IGSH-813 prepending a loaded older page never counts its messages" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var before: History = .{};
    defer before.deinit(a);
    try before.apply(a, "@mp\t1\thistory\tok\tsid\t100\t200\t9\t0\tclaude\tterm-1\t1\t\ttail\t100\n{\"role\":\"user\",\"text\":\"loaded tail\",\"offset\":100,\"end\":200}\n@@MP_END@@\n", 1, key);
    var after = try before.clone(a);
    defer after.deinit(a);
    try after.apply(a, "@mp\t2\thistory\tok\tsid\t0\t100\t9\t0\tclaude\tterm-1\t2\t\tolder\t0\n{\"role\":\"user\",\"text\":\"older message\",\"offset\":0,\"end\":100}\n@@MP_END@@\n", 2, key);
    try std.testing.expectEqual(@as(usize, 2), after.blocks.items.len);
    try std.testing.expectEqual(@as(usize, 0), before.newMessages(after));
}

test "IGSH-815 tail reconciliation retains prepended rows through cache restart and deltas" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var h: History = .{};
    defer h.deinit(a);
    const tail = "@mp\t1\thistory\tok\tsid\t100\t200\t9\t0\tclaude\tterm-1\t1\t\ttail\t100\n" ++
        "{\"role\":\"assistant\",\"text\":\"last\",\"offset\":100,\"end\":200}\n@@MP_END@@\n";
    try h.apply(a, tail, 1, key);
    try h.apply(a, "@mp\t2\thistory\tok\tsid\t0\t100\t9\t0\tclaude\tterm-1\t1\t\tolder\t0\n" ++
        "{\"role\":\"user\",\"text\":\"first\",\"offset\":0,\"end\":100}\n@@MP_END@@\n", 2, key);
    const encoded = try h.encode(a, key);
    defer a.free(encoded);
    var restored = try History.decode(a, encoded, key);
    defer restored.deinit(a);
    for ([_]*History{ &h, &restored }) |history| {
        for (0..3) |_| {
            try history.apply(a, tail, 1, key);
            try std.testing.expectEqual(@as(u64, 0), history.start);
            try std.testing.expectEqual(@as(usize, 2), history.blocks.items.len);
            try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("firstlast"), history.text.items);
        }
        try history.apply(a, "@mp\t3\thistory\tok\tsid\t200\t300\t9\t0\tclaude\tterm-1\t2\t\tdelta\t0\n" ++
            "{\"role\":\"user\",\"text\":\"new\",\"offset\":200,\"end\":300}\n@@MP_END@@\n", 3, key);
        try std.testing.expectEqual(@as(usize, 3), history.blocks.items.len);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("firstlastnew"), history.text.items);
        try std.testing.expectError(error.InvalidHistory, history.apply(a, tail, 1, key));
        try std.testing.expectEqual(@as(usize, 3), history.blocks.items.len);
        try history.apply(a, "@mp\t4\thistory\tok\tsid\t100\t200\t10\t0\tclaude\tterm-1\t3\t\ttail\t100\n" ++
            "{\"role\":\"assistant\",\"text\":\"replacement\",\"offset\":100,\"end\":200}\n@@MP_END@@\n", 4, key);
        try std.testing.expectEqual(@as(usize, 4), history.blocks.items.len);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("firstlastnewreplacement"), history.text.items);
        try std.testing.expectEqual(@as(u64, 100), history.start);
    }
}

pub const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };

pub fn unreadBoundary(blocks: []const md.Block, marker: u64) ReadBoundary {
    if (marker == 0 or blocks.len == 0) return .{};
    var last: ?usize = null;
    for (blocks, 0..) |block, i| {
        if (block.role != .tool and block.message_id == marker) last = i;
    }
    if (last) |read| {
        for (blocks[read + 1 ..], read + 1..) |block, i| {
            if (block.role != .tool and block.first and block.message_id != marker) return .{ .index = i };
        }
        return .{};
    }
    for (blocks, 0..) |block, i| {
        if (block.role != .tool) return .{ .index = i, .unknown = true };
    }
    return .{};
}

test "IGSH-814 history gap never guesses from offsets and resync keeps the message anchor" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var h: History = .{};
    defer h.deinit(a);
    try h.apply(a, "@mp\t1\thistory\tok\tsid\t0\t300\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"assistant\",\"id\":\"read\",\"text\":\"# Read\\n\\nAlready read\",\"offset\":0,\"end\":100}\n" ++
        "{\"role\":\"assistant\",\"id\":\"unread\",\"text\":\"# New\\n\\nUnread reply\",\"offset\":100,\"end\":200}\n@@MP_END@@\n", 1, key);
    const marker = h.blocks.items[0].message_id;
    try std.testing.expect(marker != 0);
    const boundary = unreadBoundary(h.blocks.items, marker);
    try std.testing.expect(!boundary.unknown);
    try std.testing.expectEqual(@as(?usize, 2), boundary.index);
    const encoded = try h.encode(a, key);
    defer a.free(encoded);
    var resynced = try History.decode(a, encoded, key);
    defer resynced.deinit(a);
    for (resynced.blocks.items) |*block| block.source_offset += 900;
    try std.testing.expectEqualDeep(boundary, unreadBoundary(resynced.blocks.items, marker));
    const gap = unreadBoundary(h.blocks.items[2..], marker);
    try std.testing.expect(gap.unknown);
    try std.testing.expectEqual(@as(?usize, 0), gap.index);
}

test "IGSH-814 all read and legacy chats never draw a divider" {
    const blocks = [_]md.Block{
        .{ .start = 0, .len = 1, .role = .prose, .first = true, .message_id = 11 },
        .{ .start = 1, .len = 1, .role = .code, .message_id = 11 },
        .{ .start = 2, .len = 1, .role = .tool },
    };
    try std.testing.expectEqualDeep(ReadBoundary{}, unreadBoundary(&blocks, 11));
    try std.testing.expectEqualDeep(ReadBoundary{}, unreadBoundary(&blocks, 0));
    try std.testing.expectEqualDeep(ReadBoundary{}, unreadBoundary(&.{}, 11));
}

test "IGSH-814 mixed message read identity is independent of wire row offsets" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, false, "term-1", "");
    var before: History = .{};
    defer before.deinit(a);
    var after: History = .{};
    defer after.deinit(a);
    try before.apply(a, "@mp\t1\thistory\tok\tsid\t0\t200\t9\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"assistant\",\"id\":\"reply:text:100:2\",\"read_id\":\"stable-source:text:2\",\"text\":\"Read\",\"offset\":100,\"end\":200}\n@@MP_END@@\n", 1, key);
    try after.apply(a, "@mp\t2\thistory\tok\tsid\t0\t1000\t10\t0\tclaude\tterm-1\n" ++
        "{\"role\":\"assistant\",\"id\":\"reply:text:900:2\",\"read_id\":\"stable-source:text:2\",\"text\":\"Read\",\"offset\":900,\"end\":1000}\n@@MP_END@@\n", 2, key);
    const marker = before.blocks.items[0].message_id;
    try std.testing.expectEqual(marker, after.blocks.items[0].message_id);
    try std.testing.expectEqualDeep(ReadBoundary{}, unreadBoundary(after.blocks.items, marker));
}

test "IGSH-814 ID-less Codex source records retain their saved read anchor" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, true, "term-1", "");
    var history: History = .{};
    defer history.deinit(a);
    try history.apply(a, "@mp\t1\thistory\tok\tsid\t0\t200\t9\t0\tcodex\tterm-1\n" ++
        "{\"role\":\"assistant\",\"id\":\"\",\"read_id\":\"event:read\",\"text\":\"Read\",\"offset\":0,\"end\":100}\n" ++
        "{\"role\":\"assistant\",\"id\":\"\",\"read_id\":\"event:unread\",\"text\":\"Unread\",\"offset\":100,\"end\":200}\n@@MP_END@@\n", 1, key);
    const marker = history.blocks.items[0].message_id;
    try std.testing.expect(marker != 0);
    const bytes = try history.encode(a, key);
    defer a.free(bytes);
    var restored = try History.decode(a, bytes, key);
    defer restored.deinit(a);
    const boundary = unreadBoundary(restored.blocks.items, marker);
    try std.testing.expect(!boundary.unknown);
    try std.testing.expectEqual(@as(?usize, 1), boundary.index);
}

test "IGSH-814 old caches reload source identities before saving read markers" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(1, 0, true, "term-1", "");
    const bytes = "{\"version\":5,\"inode\":9,\"offset\":100,\"sid\":\"sid\",\"host\":0,\"codex\":true,\"tmux\":\"term-1\"}\n" ++
        "{\"role\":\"assistant\",\"id\":\"\",\"timestamp\":\"2026-10-25T11:00:00.000Z\",\"text\":\"Previously cached Codex reply\"}\n";
    var restored = try History.decode(a, bytes, key);
    defer restored.deinit(a);
    try std.testing.expect(restored.restore_full);
    try std.testing.expectEqual(@as(u64, 0), restored.blocks.items[0].message_id);
}

test "IGSH-815 staged older pages keep the visible tail stable and materialize every message across cache restore" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(815, 0, false, "term-1", "");
    var tail: History = .{};
    defer tail.deinit(a);
    try tail.apply(a, "@mp\t1\thistory\tok\tsid\t49\t50\t9\t0\tclaude\tterm-1\t0\t\ttail\t49\n{\"role\":\"assistant\",\"text\":\"message 49\"}\n@@MP_END@@\n", 1, key);
    var backfill: Backfill = .{};
    defer backfill.deinit(a);
    const tail_text = tail.text.items.ptr;
    var before: u64 = 49;
    while (before > 0) {
        var page = tail.cursor();
        defer page.deinit(a);
        page.start = before;
        page.defer_render = true;
        const wire = try std.fmt.allocPrint(a, "@mp\t2\thistory\tok\tsid\t{d}\t{d}\t9\t0\tclaude\tterm-1\t0\t\tolder\t{d}\n{{\"role\":\"assistant\",\"text\":\"message {d}\"}}\n@@MP_END@@\n", .{ before - 1, before, before - 1, before - 1 });
        defer a.free(wire);
        try page.apply(a, wire, 2, key);
        try std.testing.expectEqual(@as(usize, 0), page.text.items.len);
        try std.testing.expectEqual(@as(usize, 0), page.blocks.items.len);
        try backfill.stage(a, &page);
        try std.testing.expectEqual(tail_text, tail.text.items.ptr);
        try std.testing.expectEqual(@as(usize, 1), tail.blocks.items.len);
        before = backfill.start;
    }
    var complete = try backfill.finish(a, tail);
    defer complete.deinit(a);
    try std.testing.expectEqual(@as(u64, 0), complete.start);
    try std.testing.expectEqual(@as(u64, 50), complete.offset);
    try std.testing.expectEqual(@as(usize, 50), complete.blocks.items.len);
    try std.testing.expectEqual(@as(usize, 0), backfill.pages.items.len);
    const encoded = try complete.encode(a, key);
    defer a.free(encoded);
    var restored = try History.decode(a, encoded, key);
    defer restored.deinit(a);
    try std.testing.expectEqual(@as(usize, 50), restored.blocks.items.len);
    try std.testing.expectEqualStrings(complete.rows.items, restored.rows.items);
    try std.testing.expect(std.mem.startsWith(u8, restored.rows.items, "{\"role\":\"assistant\",\"text\":\"message 0\"}"));
}

test "IGSH-934 rewritten sources retain messages, update overlaps and keep read identities" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(934, 0, false, "term-1", "");
    var h: History = .{};
    defer h.deinit(a);
    try h.apply(a, "@mp\t1\thistory\tok\tsid\t0\t300\t9\t0\tclaude\tterm-1\t0\t\ttail\t0\n" ++
        "{\"role\":\"user\",\"id\":\"one\",\"text\":\"first\",\"offset\":0,\"end\":100}\n" ++
        "{\"role\":\"assistant\",\"id\":\"two\",\"text\":\"partial\",\"offset\":100,\"end\":200}\n" ++
        "{\"role\":\"user\",\"id\":\"three\",\"text\":\"third\",\"offset\":200,\"end\":300}\n@@MP_END@@\n", 1, key);
    const first_id = h.blocks.items[0].message_id;
    try h.apply(a, "@mp\t2\thistory\tok\tnew-sid\t0\t200\t10\t0\tclaude\tterm-1\t0\t\ttail\t0\n" ++
        "{\"role\":\"assistant\",\"id\":\"two\",\"text\":\"complete\",\"offset\":0,\"end\":100}\n" ++
        "{\"role\":\"assistant\",\"id\":\"four\",\"text\":\"fourth\",\"offset\":100,\"end\":200}\n@@MP_END@@\n", 2, key);
    try std.testing.expectEqual(@as(usize, 4), h.blocks.items.len);
    try std.testing.expectEqual(first_id, h.blocks.items[0].message_id);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("firstcompletethirdfourth"), h.text.items);
    const encoded = try h.encode(a, key);
    defer a.free(encoded);
    var restored = try History.decode(a, encoded, key);
    defer restored.deinit(a);
    try std.testing.expectEqual(first_id, restored.blocks.items[0].message_id);
    try std.testing.expectError(error.EmptyReset, h.apply(a, "@mp\t3\thistory\tok\tnew-sid\t0\t0\t11\t0\tclaude\tterm-1\t0\t\ttail\t0\n@@MP_END@@\n", 3, key));
    try std.testing.expectEqual(@as(usize, 4), h.blocks.items.len);
    try std.testing.expectError(error.InvalidHistory, h.apply(a, "@mp\t3\thistory\tok\tnew-sid\t0\t100\t10\t0\tclaude\tterm-1\t0\t\ttail\t0\n{\"role\":\"user\",\"id\":\"one\",\"text\":\"stale\"}\n@@MP_END@@\n", 3, key));
}

test "IGSH-934 backfill after a source rewrite deduplicates already retained messages" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(934, 0, false, "term-1", "");
    var h: History = .{};
    defer h.deinit(a);
    try h.apply(a, "@mp\t1\thistory\tok\tsid\t0\t300\t9\t0\tclaude\tterm-1\t0\t\ttail\t0\n" ++
        "{\"role\":\"user\",\"id\":\"one\",\"text\":\"first\",\"offset\":0,\"end\":100}\n" ++
        "{\"role\":\"assistant\",\"id\":\"two\",\"text\":\"second\",\"offset\":100,\"end\":200}\n" ++
        "{\"role\":\"user\",\"id\":\"three\",\"text\":\"third\",\"offset\":200,\"end\":300}\n@@MP_END@@\n", 1, key);
    try h.apply(a, "@mp\t2\thistory\tok\tsid\t200\t400\t10\t0\tclaude\tterm-1\t0\t\ttail\t200\n" ++
        "{\"role\":\"user\",\"id\":\"three\",\"text\":\"third\",\"offset\":200,\"end\":300}\n" ++
        "{\"role\":\"assistant\",\"id\":\"four\",\"text\":\"fourth\",\"offset\":300,\"end\":400}\n@@MP_END@@\n", 2, key);
    var page = h.cursor();
    defer page.deinit(a);
    try page.apply(a, "@mp\t3\thistory\tok\tsid\t0\t200\t10\t0\tclaude\tterm-1\t0\t\tolder\t0\n" ++
        "{\"role\":\"user\",\"id\":\"one\",\"text\":\"first\",\"offset\":0,\"end\":100}\n" ++
        "{\"role\":\"assistant\",\"id\":\"two\",\"text\":\"second\",\"offset\":100,\"end\":200}\n@@MP_END@@\n", 3, key);
    var backfill: Backfill = .{};
    defer backfill.deinit(a);
    try backfill.stage(a, &page);
    var complete = try backfill.finish(a, h);
    defer complete.deinit(a);
    try std.testing.expectEqual(@as(usize, 4), complete.blocks.items.len);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("firstsecondthirdfourth"), complete.text.items);
}

test "IGSH-934 2000 messages survive 200 burst arrivals with rewritten and empty refreshes" {
    const a = std.testing.allocator;
    const fixture = struct {
        fn wire(alloc: std.mem.Allocator, first_index: usize, count: usize, base: u64, inode: u64, mode: []const u8) !std.ArrayList(u8) {
            var bytes: std.ArrayList(u8) = .empty;
            errdefer bytes.deinit(alloc);
            const header = try std.fmt.allocPrint(alloc, "@mp\t1\thistory\tok\tsid\t{d}\t{d}\t{d}\t0\tclaude\tterm-1\t0\t\t{s}\t0\n", .{ base, base + count * 100, inode, mode });
            defer alloc.free(header);
            try bytes.appendSlice(alloc, header);
            for (first_index..first_index + count) |i| {
                const line = try std.fmt.allocPrint(alloc, "{{\"role\":\"assistant\",\"id\":\"message-{d}\",\"text\":\"message {d}\",\"offset\":{d},\"end\":{d}}}\n", .{ i, i, base + (i - first_index) * 100, base + (i - first_index + 1) * 100 });
                defer alloc.free(line);
                try bytes.appendSlice(alloc, line);
            }
            try bytes.appendSlice(alloc, "@@MP_END@@\n");
            return bytes;
        }
    };
    const key = transcript.Identity.initTmux(934, 0, false, "term-1", "");
    var h: History = .{};
    defer h.deinit(a);
    var initial = try fixture.wire(a, 0, 2000, 0, 9, "tail");
    defer initial.deinit(a);
    try h.apply(a, initial.items, 1, key);
    const first_id = h.blocks.items[0].message_id;
    for (0..10) |burst| {
        if (burst == 6) {
            try std.testing.expectError(error.EmptyReset, h.apply(a, "@mp\t1\thistory\tok\tsid\t0\t0\t11\t0\tclaude\tterm-1\t0\t\ttail\t0\n@@MP_END@@\n", 1, key));
        }
        var incoming = try fixture.wire(a, 2000 + burst * 20, 20, if (burst == 3) 0 else h.offset, if (burst >= 3) 10 else 9, if (burst == 3) "tail" else "delta");
        defer incoming.deinit(a);
        try h.apply(a, incoming.items, 1, key);
        try std.testing.expectEqual(@as(usize, 2020) + burst * 20, h.blocks.items.len);
        try std.testing.expectEqual(first_id, h.blocks.items[0].message_id);
        for (h.blocks.items, 0..) |block, i| {
            const expected = try std.fmt.allocPrint(a, "message {d}", .{i});
            defer a.free(expected);
            const wide = try std.unicode.utf8ToUtf16LeAlloc(a, expected);
            defer a.free(wide);
            try std.testing.expectEqualSlices(u16, wide, h.text.items[block.start..][0..block.len]);
        }
    }
}

test "IGSH-934 a reset with a wider window inserts unseen older messages before the known overlap" {
    const a = std.testing.allocator;
    const key = transcript.Identity.initTmux(934, 0, false, "term-1", "");
    var h: History = .{};
    defer h.deinit(a);
    try h.apply(a, "@mp\t1\thistory\tok\tsid\t100\t200\t9\t0\tclaude\tterm-1\t0\t\ttail\t100\n{\"role\":\"user\",\"id\":\"two\",\"text\":\"second\",\"offset\":100,\"end\":200}\n@@MP_END@@\n", 1, key);
    try h.apply(a, "@mp\t2\thistory\tok\tsid\t0\t300\t10\t0\tclaude\tterm-1\t0\t\ttail\t0\n" ++
        "{\"role\":\"assistant\",\"id\":\"one\",\"text\":\"first\",\"offset\":0,\"end\":100}\n" ++
        "{\"role\":\"user\",\"id\":\"two\",\"text\":\"second\",\"offset\":100,\"end\":200}\n" ++
        "{\"role\":\"assistant\",\"id\":\"three\",\"text\":\"third\",\"offset\":200,\"end\":300}\n@@MP_END@@\n", 2, key);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("firstsecondthird"), h.text.items);
}
