const std = @import("std");
const history = @import("chat_history.zig");
const echo = @import("chat_echo.zig");
const transcript = @import("chat_transcript.zig");
const md = @import("chat_markdown.zig");

const Row = struct {
    role: []const u8,
    text: []const u8,
    timestamp: []const u8 = "",
    id: []const u8 = "",
    settlement: ?struct { operation: []const u8, content: []const u8 = "" } = null,
};

fn first80(text: []const u8) []const u8 {
    var i: usize = 0;
    var count: usize = 0;
    while (i < text.len and count < 80) : (count += 1) i += std.unicode.utf8ByteSequenceLength(text[i]) catch 1;
    return text[0..@min(i, text.len)];
}

fn emit(a: std.mem.Allocator, out: *std.Io.Writer, value: anytype) !void {
    const json = try std.json.Stringify.valueAlloc(a, value, .{});
    try out.writeAll(json);
    try out.writeByte('\n');
}

fn finding(a: std.mem.Allocator, out: *std.Io.Writer, kind: []const u8, row: usize, stamp: []const u8, text: []const u8) !void {
    try emit(a, out, .{ .kind = kind, .row = row, .timestamp = stamp, .text = first80(text) });
}

fn normalized(a: std.mem.Allocator, text: []const u16) ![]const u16 {
    return echo.normalize(text, try a.alloc(u16, text.len));
}

fn visible(a: std.mem.Allocator, h: history.History, user: ?bool, plain: bool, plain_users: bool) ![]const u16 {
    var text: std.ArrayList(u16) = .empty;
    for (h.blocks.items) |block| {
        if (block.role == .tool) continue;
        if (user) |is_user| {
            if (is_user != (block.role == .user or block.role == .injected)) continue;
        }
        const content = h.text.items[block.start..][0..block.len];
        if (plain and block.role != .code and (plain_users or block.role != .user)) {
            const spans = try a.alloc(md.Span, content.len + 1);
            const count = md.inlineSpans(content, spans);
            for (spans[0..count]) |span| try text.appendSlice(a, content[span.text.start..span.text.end]);
        } else try text.appendSlice(a, content);
        try text.append(a, ' ');
    }
    if (plain) for (text.items) |*c| {
        c.* = switch (c.*) {
            0x2018, 0x2019 => '\'',
            0x201c, 0x201d => '"',
            else => c.*,
        };
    };
    return normalized(a, text.items);
}

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const a = arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    var input_buffer: [8192]u8 = undefined;
    var input = std.Io.File.stdin().readerStreaming(init.io, &input_buffer);
    const wire = try input.interface.allocRemaining(a, .limited(64 * 1024 * 1024));
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    const out = &output.interface;
    defer out.flush() catch {};
    var lines = std.mem.splitScalar(u8, wire, '\n');
    var fields = std.mem.splitScalar(u8, lines.next() orelse return error.InvalidHistory, '\t');
    var header: [15][]const u8 = @splat("");
    var n: usize = 0;
    while (fields.next()) |field| {
        if (n == header.len) return error.InvalidHistory;
        header[n] = field;
        n += 1;
    }
    if (n < 11) return error.InvalidHistory;
    const id = try std.fmt.parseInt(u32, header[1], 10);
    const key = if (std.mem.eql(u8, header[10], "-"))
        transcript.Identity.init(1, 0, std.mem.eql(u8, header[9], "codex"), header[4], "")
    else
        transcript.Identity.initTmux(1, 0, std.mem.eql(u8, header[9], "codex"), header[10], "");
    var h: history.History = .{};
    try h.apply(a, wire, id, key);
    const rendered = try visible(a, h, null, true, false);
    const rendered_plain = try visible(a, h, null, true, true);
    const rendered_users = try visible(a, h, true, false, false);
    const rendered_assistants = try visible(a, h, false, false, false);
    var rows: std.ArrayList(Row) = .empty;
    var row_lines = std.mem.splitScalar(u8, h.rows.items, '\n');
    while (row_lines.next()) |line| {
        if (line.len == 0) continue;
        const parsed = try std.json.parseFromSlice(Row, a, line, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
        try rows.append(a, parsed.value);
    }
    var users: std.ArrayList(echo.UserBlock) = .empty;
    for (h.blocks.items) |block| {
        if (block.role == .tool) continue;
        const text = h.text.items[block.start..][0..block.len];
        if (block.role == .user) try users.append(a, .{ .text = text, .stamp_ms = block.stamp_ms });
        const utf8 = try std.unicode.utf16LeToUtf8Alloc(a, text);
        const lower = try std.ascii.allocLowerString(a, utf8);
        for ([_][]const u8{ "<pasted_content", "<command-name>", "<command-message>", "<command-args>", "<local-command-", "<system-reminder>", "<task-notification>" }) |tag| {
            if (std.mem.indexOf(u8, lower, tag)) |at| {
                var source_row: usize = 0;
                var source_stamp: []const u8 = "";
                for (rows.items, 0..) |row, ri| {
                    if (row.settlement == null and echo.stampMs(row.timestamp) == block.stamp_ms and std.mem.indexOf(u8, row.text, utf8[at..][0..tag.len]) != null) {
                        source_row = ri + 1;
                        source_stamp = row.timestamp;
                        break;
                    }
                }
                try finding(a, out, "raw_markup", source_row, source_stamp, utf8[at..]);
                break;
            }
        }
    }
    var newest: i64 = 0;
    for (rows.items, 0..) |row, ri| {
        if (!std.mem.eql(u8, row.role, "user") and !std.mem.eql(u8, row.role, "assistant")) continue;
        const stamp = echo.stampMs(row.timestamp);
        defer newest = @max(newest, stamp);
        if (row.settlement) |fact| {
            if (!std.mem.eql(u8, fact.operation, "enqueue") or fact.content.len == 0) continue;
            const text = try std.unicode.utf8ToUtf16LeAlloc(a, fact.content);
            if (transcript.injectedMessage(text) != null or std.mem.startsWith(u8, std.mem.trimStart(u8, fact.content, " \r\n\t"), "<task-notification>")) continue;
            var eligible = false;
            for (rows.items[ri + 1 ..]) |later| {
                if (later.settlement) |removed| {
                    if (!std.mem.eql(u8, removed.operation, "remove") and !std.mem.eql(u8, removed.operation, "dequeue")) continue;
                    const content = try std.unicode.utf8ToUtf16LeAlloc(a, removed.content);
                    if (echo.sameText(text, content)) eligible = true;
                } else if (std.mem.eql(u8, later.role, "user")) {
                    const content = try std.unicode.utf8ToUtf16LeAlloc(a, later.text);
                    if (echo.sameText(text, content)) eligible = true;
                }
            }
            if (!eligible) continue;
            var pending = [_]echo.Pending{.{ .text = text, .prefix = try normalized(a, text), .anchor = .{ .after_ms = newest, .sent_ms = stamp } }};
            var picked: [1]?usize = undefined;
            echo.assign(&pending, users.items, h.start != 0, &.{}, &picked);
            if (picked[0] == null) try finding(a, out, "pending_but_delivered", ri + 1, row.timestamp, fact.content);
        } else {
            const wide = try a.alloc(u16, row.text.len);
            const blocks = try a.alloc(md.Block, 1 + std.mem.count(u8, row.text, "\n"));
            const projected = try transcript.messageBlocks(row.text, wide, 0, if (std.mem.eql(u8, row.role, "user")) .user else .prose, blocks);
            var expected: std.ArrayList(u16) = .empty;
            for (blocks[0..projected.count]) |block| {
                try expected.appendSlice(a, wide[block.start..][0..block.len]);
                try expected.append(a, ' ');
            }
            const norm = try normalized(a, expected.items);
            const rendered_role = if (std.mem.eql(u8, row.role, "user")) rendered_users else rendered_assistants;
            if (norm.len == 0 or std.mem.indexOf(u16, rendered_role, norm) == null) try finding(a, out, "turn_missing", ri + 1, row.timestamp, row.text);
        }
    }
    var arg: usize = 1;
    var probe: usize = 0;
    while (arg < args.len) : (arg += 1) {
        if (!std.mem.eql(u8, args[arg], "--contains") or arg + 1 >= args.len) return error.InvalidArgument;
        arg += 1;
        const wide = try std.unicode.utf8ToUtf16LeAlloc(a, args[arg]);
        for (wide) |*c| c.* = switch (c.*) {
            0x2018, 0x2019 => '\'',
            0x201c, 0x201d => '"',
            else => c.*,
        };
        const norm = try normalized(a, wide);
        try emit(a, out, .{ .probe = probe, .present = norm.len > 0 and (std.mem.indexOf(u16, rendered, norm) != null or std.mem.indexOf(u16, rendered_plain, norm) != null) });
        probe += 1;
    }
}
