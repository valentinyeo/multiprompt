const std = @import("std");
const md = @import("chat_markdown.zig");

pub const ISSUE_268_CHAT_FIND = true;
pub const Hit = struct {
    offset: u64,
    end: u64,
    role: enum { user, assistant, tool },
    timestamp: []const u8,
    snippet: []const u8,
};
pub const Result = struct {
    arena: std.heap.ArenaAllocator,
    hits: []Hit,
    sid: []const u8,
    inode: u64,
    size: u64,
    truncated: bool,

    pub fn deinit(self: *Result) void {
        self.arena.deinit();
    }
};

pub fn parse(a: std.mem.Allocator, wire: []const u8, id: u32, codex: bool, tmux: []const u8) !Result {
    var arena = std.heap.ArenaAllocator.init(a);
    errdefer arena.deinit();
    const alloc = arena.allocator();
    var lines = std.mem.splitScalar(u8, wire, '\n');
    var fields = std.mem.splitScalar(u8, lines.next() orelse return error.InvalidSearch, '\t');
    const prefix = [_][]const u8{ "@mp", "", "search", "ok" };
    for (prefix, 0..) |expected, i| {
        const field = fields.next() orelse return error.InvalidSearch;
        if (i == 1) {
            if (try std.fmt.parseInt(u32, field, 10) != id) return error.StaleSearch;
        } else if (!std.mem.eql(u8, field, expected)) return error.InvalidSearch;
    }
    const sid = try alloc.dupe(u8, fields.next() orelse return error.InvalidSearch);
    if (sid.len == 0 or sid.len > 40) return error.InvalidSearch;
    const inode = try std.fmt.parseInt(u64, fields.next() orelse return error.InvalidSearch, 10);
    const size = try std.fmt.parseInt(u64, fields.next() orelse return error.InvalidSearch, 10);
    const count = try std.fmt.parseInt(usize, fields.next() orelse return error.InvalidSearch, 10);
    if (count > 500) return error.InvalidSearch;
    const flag = fields.next() orelse return error.InvalidSearch;
    if (!std.mem.eql(u8, flag, "0") and !std.mem.eql(u8, flag, "1")) return error.InvalidSearch;
    if (!std.mem.eql(u8, fields.next() orelse return error.InvalidSearch, if (codex) "codex" else "claude")) return error.InvalidSearch;
    if (!std.mem.eql(u8, fields.next() orelse return error.InvalidSearch, if (tmux.len > 0) tmux else "-") or fields.next() != null) return error.InvalidSearch;
    const hits = try alloc.alloc(Hit, count);
    for (hits, 0..) |*hit, i| {
        const parsed = try std.json.parseFromSlice(Hit, alloc, lines.next() orelse return error.InvalidSearch, .{ .allocate = .alloc_always });
        hit.* = parsed.value;
        if (hit.end <= hit.offset or hit.end > size or (i > 0 and hits[i - 1].offset > hit.offset)) return error.InvalidSearch;
        if (try std.unicode.utf8CountCodepoints(hit.snippet) > 160) return error.InvalidSearch;
    }
    if (!std.mem.eql(u8, lines.next() orelse return error.InvalidSearch, "@@MP_END@@")) return error.InvalidSearch;
    while (lines.next()) |line| if (line.len != 0) return error.InvalidSearch;
    return .{ .arena = arena, .hits = hits, .sid = sid, .inode = inode, .size = size, .truncated = std.mem.eql(u8, flag, "1") };
}

pub fn step(selected: usize, count: usize, previous: bool) usize {
    if (count == 0) return 0;
    return if (previous) (if (selected == 0) count - 1 else selected - 1) else (selected + 1) % count;
}

pub fn counter(out: []u8, selected: usize, count: usize, truncated: bool) ![]const u8 {
    return std.fmt.bufPrint(out, "{d} of {d}{s}", .{ if (count == 0) @as(usize, 0) else selected + 1, count, if (truncated) "+" else "" });
}

pub fn needsOlder(offset: u64, oldest: u64) bool {
    return oldest > 0 and offset < oldest;
}

pub fn contains(block: md.Block, hit: Hit) bool {
    if ((hit.role == .tool) != (block.role == .tool)) return false;
    if (hit.role == .user and block.role != .user and block.role != .injected) return false;
    if (hit.role == .assistant and (block.role == .user or block.role == .injected)) return false;
    return (block.source_end > block.source_offset and hit.offset >= block.source_offset and hit.offset < block.source_end) or
        (block.result_offset != null and block.result_offset.? == hit.offset);
}

pub fn ownsKeys(open: bool, ours: bool) bool {
    return ISSUE_268_CHAT_FIND and open and ours;
}

test "ISSUE-268 parses whole-file search header and rows, rejects stale or malformed replies" {
    const wire = "@mp\t7\tsearch\tok\tsid\t12\t100\t1\t1\tclaude\tterm-1\n" ++
        "{\"offset\":0,\"end\":50,\"role\":\"user\",\"timestamp\":\"today\",\"snippet\":\"hello\"}\n@@MP_END@@\n";
    var result = try parse(std.testing.allocator, wire, 7, false, "term-1");
    defer result.deinit();
    try std.testing.expectEqual(@as(u64, 12), result.inode);
    try std.testing.expectEqual(@as(u64, 100), result.size);
    try std.testing.expect(result.truncated);
    try std.testing.expectEqual(@as(u64, 0), result.hits[0].offset);
    try std.testing.expectEqualStrings("hello", result.hits[0].snippet);
    try std.testing.expectError(error.StaleSearch, parse(std.testing.allocator, wire, 8, false, "term-1"));
    try std.testing.expectError(error.InvalidSearch, parse(std.testing.allocator, wire, 7, true, "term-1"));
    try std.testing.expectError(error.InvalidSearch, parse(std.testing.allocator, wire[0 .. wire.len - 12], 7, false, "term-1"));
}

test "ISSUE-268 newest start, n of m, wraps both ways, and older pages stop at loaded offset" {
    const count: usize = 3;
    const newest = count - 1;
    try std.testing.expectEqual(@as(usize, 0), step(newest, count, false));
    try std.testing.expectEqual(newest, step(0, count, true));
    try std.testing.expectEqual(@as(usize, 1), step(0, count, false));
    try std.testing.expectEqual(@as(usize, 0), step(0, 0, true));
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("3 of 3+", try counter(&buf, newest, count, true));
    try std.testing.expectEqualStrings("0 of 0", try counter(&buf, 0, 0, false));
    try std.testing.expect(needsOlder(20, 100));
    try std.testing.expect(needsOlder(20, 40));
    try std.testing.expect(!needsOlder(20, 20));
    try std.testing.expect(!needsOlder(20, 0));
}

test "ISSUE-268 find owns every key only while open in our foreground" {
    try std.testing.expect(ownsKeys(true, true));
    try std.testing.expect(!ownsKeys(false, true));
    try std.testing.expect(!ownsKeys(true, false));
}

test "ISSUE-268 source offsets map a tool result to its visible tool block" {
    const hit: Hit = .{ .offset = 80, .end = 100, .role = .tool, .timestamp = "", .snippet = "passed" };
    const block: md.Block = .{ .start = 0, .len = 10, .role = .tool, .source_offset = 10, .source_end = 40, .result_offset = 80 };
    try std.testing.expect(contains(block, hit));
    try std.testing.expect(!contains(block, .{ .offset = 50, .end = 60, .role = .assistant, .timestamp = "", .snippet = "absent" }));
}

pub fn snippetPosition(hit: Hit, text: []const u16, start: usize, end: usize) ?usize {
    var wide: [320]u16 = undefined;
    const n = std.unicode.utf8ToUtf16Le(&wide, hit.snippet) catch return null;
    if (n == 0 or start > end or end > text.len) return null;
    const at = std.mem.indexOf(u16, text[start..end], wide[0..n]) orelse return null;
    return start + at;
}

test "ISSUE-268 literal snippet locates a match deep inside a loaded message" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("earlier text\nStraße match near the end");
    const hit: Hit = .{ .offset = 0, .end = 100, .role = .assistant, .timestamp = "", .snippet = "Straße match near the end" };
    try std.testing.expectEqual(@as(?usize, 13), snippetPosition(hit, text, 0, text.len));
    try std.testing.expectEqual(@as(?usize, null), snippetPosition(hit, text, 0, 10));
}

pub fn toolSnippetMatches(hit: Hit, text: []const u16, block: md.Block) bool {
    const body_end = block.start + block.len;
    const detail_end = block.detail_start + block.detail_len;
    if (body_end > text.len or detail_end > text.len) return false;
    if (snippetPosition(hit, text, block.start, body_end) != null or snippetPosition(hit, text, block.detail_start, detail_end) != null) return true;
    var wide: [320]u16 = undefined;
    const n = std.unicode.utf8ToUtf16Le(&wide, hit.snippet) catch return false;
    const split = std.mem.indexOfScalar(u16, wide[0..n], '\n') orelse return false;
    return std.mem.endsWith(u16, text[block.start..body_end], wide[0..split]) and
        std.mem.startsWith(u16, text[block.detail_start..detail_end], wide[split + 1 .. n]);
}

test "ISSUE-268 parallel tool calls on one source line keep their own snippet targets" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const title = w("Read config.json");
    const first = w("{\"path\":\"/first/config.json\"}");
    const second = w("{\"path\":\"/second/config.json\"}");
    const text = w("Read config.json{\"path\":\"/first/config.json\"}Read config.json{\"path\":\"/second/config.json\"}");
    const left: md.Block = .{ .start = 0, .len = title.len, .role = .tool, .detail_start = title.len, .detail_len = first.len };
    const at = title.len + first.len;
    const right: md.Block = .{ .start = at, .len = title.len, .role = .tool, .detail_start = at + title.len, .detail_len = second.len };
    const hit: Hit = .{ .offset = 0, .end = 100, .role = .tool, .timestamp = "", .snippet = "Read config.json\n{\"path\":\"/second/config.json\"}" };
    try std.testing.expect(!toolSnippetMatches(hit, text, left));
    try std.testing.expect(toolSnippetMatches(hit, text, right));
}
