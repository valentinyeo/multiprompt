const std = @import("std");

pub const Agent = enum { claude, codex, other };
pub const Mode = enum { slash, dollar, file };
pub const Token = struct { mode: Mode, start: usize, end: usize };
pub const Entry = struct { kind: u8, name: []const u8, hint: []const u8, desc: []const u8 };
pub const Status = enum { ok, stale, loading, @"error" };
pub const Header = struct { id: u32, op: []const u8, status: Status, cwd: []const u8, count: u32 };
pub const Response = struct { header: Header, n: usize };

fn space(c: u16) bool {
    return c == ' ' or c == '\t' or c == '\r' or c == '\n';
}

pub fn tokenAtCaret(text: []const u16, caret: usize, agent: Agent) ?Token {
    if (agent == .other or caret > text.len) return null;
    var start = caret;
    while (start > 0 and !space(text[start - 1])) : (start -= 1) {}
    if (start == caret) return null;
    const c = text[start];
    const mode: Mode = switch (c) {
        '/' => if (agent == .codex and start != 0) return null else .slash,
        '$' => if (agent == .codex) .dollar else return null,
        '@' => .file,
        else => return null,
    };
    return .{ .mode = mode, .start = start, .end = caret };
}

pub fn endsInTriggerToken(text: []const u16, agent: Agent) bool {
    return tokenAtCaret(text, text.len, if (agent == .other) .claude else agent) != null or
        tokenAtCaret(text, text.len, .claude) != null or
        (text.len > 0 and text[text.len - 1] != ' ' and tokenAtCaret(text, text.len, .codex) != null);
}

pub fn parseResponse(bytes: []const u8, out: []Entry) ?Response {
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    const first = std.mem.trimEnd(u8, lines.next() orelse return null, "\r");
    var h = std.mem.splitScalar(u8, first, '\t');
    if (!std.mem.eql(u8, h.next() orelse return null, "@mp")) return null;
    const id = std.fmt.parseInt(u32, h.next() orelse return null, 10) catch return null;
    const op = h.next() orelse return null;
    const status = std.meta.stringToEnum(Status, h.next() orelse return null) orelse return null;
    const cwd = h.next() orelse return null;
    if (op.len > 255 or cwd.len > 255) return null;
    const count = std.fmt.parseInt(u32, h.next() orelse return null, 10) catch return null;
    if (h.next() != null or count > out.len) return null;
    for (out[0..count]) |*entry| {
        const line = std.mem.trimEnd(u8, lines.next() orelse return null, "\r");
        var fields = std.mem.splitScalar(u8, line, '\t');
        const kind = fields.next() orelse return null;
        if (kind.len != 1) return null;
        const name = fields.next() orelse return null;
        const hint = fields.next() orelse return null;
        const desc = fields.next() orelse return null;
        if (fields.next() != null or name.len > 255 or hint.len > 255 or desc.len > 255) return null;
        entry.* = .{ .kind = kind[0], .name = name, .hint = hint, .desc = desc };
    }
    if (!std.mem.eql(u8, std.mem.trimEnd(u8, lines.next() orelse return null, "\r"), "@@MP_END@@")) return null;
    return .{ .header = .{ .id = id, .op = op, .status = status, .cwd = cwd, .count = count }, .n = count };
}

fn prefixAtWord(hay: []const u8, needle: []const u8, boundaries: []const u8) bool {
    for (hay, 0..) |c, i| {
        if (i == 0 or std.mem.indexOfScalar(u8, boundaries, hay[i - 1]) != null) {
            if (std.ascii.startsWithIgnoreCase(hay[i..], needle)) return true;
        }
        _ = c;
    }
    return false;
}

pub fn score(name: []const u8, desc: []const u8, query: []const u8) ?u16 {
    if (query.len == 0) return 6;
    if (std.ascii.eqlIgnoreCase(name, query)) return 0;
    if (std.ascii.startsWithIgnoreCase(name, query)) return 1;
    if (prefixAtWord(name, query, ":-_/")) return 2;
    if (std.ascii.indexOfIgnoreCase(name, query) != null) return 3;
    if (prefixAtWord(desc, query, " \t.,:;()")) return 4;
    var q: usize = 0;
    for (name) |c| {
        if (q < query.len and std.ascii.toLower(c) == std.ascii.toLower(query[q])) q += 1;
    }
    return if (q == query.len) 5 else null;
}

fn recent(name: []const u8, mru: []const []const u8) usize {
    for (mru, 0..) |item, i| if (std.ascii.eqlIgnoreCase(item, name)) return i;
    return mru.len;
}

pub fn rank(entries: []const Entry, query: []const u8, mru: []const []const u8, out: []u16) usize {
    var n: usize = 0;
    for (entries, 0..) |entry, i| {
        if (i >= 65536 or n >= out.len) break;
        const s = score(entry.name, entry.desc, query) orelse continue;
        var at = n;
        while (at > 0) {
            const prev = entries[out[at - 1]];
            const ps = score(prev.name, prev.desc, query).?;
            if (s > ps or (s == ps and (recent(entry.name, mru) > recent(prev.name, mru) or
                (recent(entry.name, mru) == recent(prev.name, mru) and !std.ascii.lessThanIgnoreCase(entry.name, prev.name))))) break;
            out[at] = out[at - 1];
            at -= 1;
        }
        out[at] = @intCast(i);
        n += 1;
    }
    return n;
}

pub fn selectionAfterRank(entries: []const Entry, order: []const u16, kind: u8, name: []const u8) usize {
    if (name.len == 0) return 0;
    for (order, 0..) |index, i| {
        const entry = entries[index];
        if (entry.kind == kind and std.mem.eql(u8, entry.name, name)) return i;
    }
    return 0;
}

pub fn promoteRecent(items: *[20][201]u8, count: *usize, name: []const u8) void {
    var i: usize = 0;
    while (i < count.*) {
        if (std.ascii.eqlIgnoreCase(std.mem.sliceTo(&items[i], 0), name)) {
            for (i..count.* - 1) |j| items[j] = items[j + 1];
            count.* -= 1;
        } else i += 1;
    }
    const kept = @min(19, count.*);
    i = kept;
    while (i > 0) : (i -= 1) items[i] = items[i - 1];
    @memset(&items[0], 0);
    @memcpy(items[0][0..@min(name.len, 200)], name[0..@min(name.len, 200)]);
    count.* = kept + 1;
}

pub fn insertionFor(agent: Agent, mode: Mode, e: Entry, buf: []u8) []const u8 {
    const prefix: []const u8 = if (mode == .file and agent == .codex) "" else if (mode == .dollar or e.kind == 'K') "$" else if (mode == .file) "@" else "/";
    const suffix: []const u8 = if (e.kind == 'D') "/" else " ";
    if (prefix.len + e.name.len + suffix.len > buf.len) return "";
    @memcpy(buf[0..prefix.len], prefix);
    @memcpy(buf[prefix.len..][0..e.name.len], e.name);
    @memcpy(buf[prefix.len + e.name.len ..][0..suffix.len], suffix);
    return buf[0 .. prefix.len + e.name.len + suffix.len];
}

pub fn applyAccept(text: []const u16, tok: Token, ins: []const u16, out: []u16) struct { len: usize, caret: usize } {
    if (tok.start > tok.end or tok.end > text.len or text.len - (tok.end - tok.start) + ins.len > out.len) return .{ .len = 0, .caret = 0 };
    @memcpy(out[0..tok.start], text[0..tok.start]);
    @memcpy(out[tok.start..][0..ins.len], ins);
    @memcpy(out[tok.start + ins.len ..][0 .. text.len - tok.end], text[tok.end..]);
    return .{ .len = text.len - (tok.end - tok.start) + ins.len, .caret = tok.start + ins.len };
}

test "triggers, caret position and final token" {
    const c = Agent.claude;
    try std.testing.expectEqual(@as(usize, 8), tokenAtCaret(&.{ 'f', 'i', 'x', ' ', 't', 'h', 'e', ' ', '/', 'c', 'o' }, 11, c).?.start);
    try std.testing.expect(tokenAtCaret(&.{ 'f', 'i', 'x', ' ', 't', 'h', 'e', ' ', '/', 'c', 'o' }, 11, .codex) == null);
    try std.testing.expect(tokenAtCaret(&.{ 'a', '@', 'b' }, 3, c) == null);
    try std.testing.expectEqual(Mode.dollar, tokenAtCaret(&.{ '$', 's', 'k' }, 2, .codex).?.mode);
    try std.testing.expect(tokenAtCaret(&.{'$'}, 1, c) == null);
    try std.testing.expect(endsInTriggerToken(&.{ '/', 'p', 'o', 's' }, c));
    try std.testing.expect(endsInTriggerToken(&.{ '@', 's', 'r', 'c' }, .other));
    try std.testing.expect(endsInTriggerToken(&.{ '$', 's', 'k' }, .claude));
    try std.testing.expect(!endsInTriggerToken(&.{ '/', 'p', 'o', 's', ' ' }, c));
}

test "response framing, rank and insertion" {
    var entries: [4]Entry = undefined;
    try std.testing.expect(parseResponse("@mp\t4\tslash\tok\t/\t2\nB\tx\t\t\n", &entries) == null);
    const result = parseResponse("@mp\t4\tslash\tok\t/home/test\t2\nB\tcompact\t[hint]\tSummarize\nS\tpospeak\t\tPost for owners\n@@MP_END@@\n", &entries).?;
    try std.testing.expectEqual(@as(usize, 2), result.n);
    var order: [4]u16 = undefined;
    try std.testing.expectEqual(@as(usize, 1), rank(entries[0..2], "pos", &.{}, &order));
    try std.testing.expectEqualStrings("pospeak", entries[order[0]].name);
    try std.testing.expectEqual(@as(?u16, 1), score("compact", "", "co"));
    try std.testing.expectEqual(@as(?u16, 4), score("ticket", "Post updates", "pos"));
    const commands = [_]Entry{
        .{ .kind = 'B', .name = "copy", .hint = "", .desc = "" },
        .{ .kind = 'B', .name = "context", .hint = "", .desc = "" },
        .{ .kind = 'B', .name = "color", .hint = "", .desc = "" },
        .{ .kind = 'B', .name = "compact", .hint = "", .desc = "" },
    };
    try std.testing.expectEqual(@as(usize, 4), rank(&commands, "co", &.{}, &order));
    try std.testing.expectEqualStrings("color", commands[order[0]].name);
    try std.testing.expectEqualStrings("compact", commands[order[1]].name);
    try std.testing.expectEqualStrings("context", commands[order[2]].name);
    try std.testing.expectEqualStrings("copy", commands[order[3]].name);
    try std.testing.expectEqual(@as(usize, 4), rank(&commands, "", &.{"copy"}, &order));
    try std.testing.expectEqualStrings("copy", commands[order[0]].name);
    var buf: [128]u8 = undefined;
    try std.testing.expectEqualStrings("/compact ", insertionFor(.claude, .slash, entries[0], &buf));
    try std.testing.expectEqualStrings("$pospeak ", insertionFor(.codex, .slash, .{ .kind = 'K', .name = "pospeak", .hint = "", .desc = "" }, &buf));
    try std.testing.expectEqualStrings("@dir/", insertionFor(.claude, .file, .{ .kind = 'D', .name = "dir", .hint = "", .desc = "" }, &buf));
    const input = [_]u16{ '/', 'c', 'o', 'x' };
    var wide: [32]u16 = undefined;
    const applied = applyAccept(&input, .{ .mode = .slash, .start = 0, .end = 3 }, &.{ '/', 'c', 'o', 'm', 'p', ' ' }, &wide);
    try std.testing.expectEqualSlices(u16, &.{ '/', 'c', 'o', 'm', 'p', ' ', 'x' }, wide[0..applied.len]);
}

test "selection survives a re-rank with the same query" {
    const entries = [_]Entry{
        .{ .kind = 'B', .name = "clear", .hint = "", .desc = "" },
        .{ .kind = 'B', .name = "compact", .hint = "", .desc = "" },
        .{ .kind = 'B', .name = "copy", .hint = "", .desc = "" },
    };
    var order: [3]u16 = undefined;
    const n = rank(&entries, "c", &.{"copy"}, &order);
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqual(@as(usize, 2), selectionAfterRank(&entries, order[0..n], 'B', "compact"));
    const refreshed = rank(&entries, "c", &.{"compact"}, &order);
    try std.testing.expectEqual(@as(usize, 0), selectionAfterRank(&entries, order[0..refreshed], 'B', "compact"));
    try std.testing.expectEqual(@as(usize, 0), selectionAfterRank(&entries, order[0..refreshed], 'B', "missing"));
}

test "oversized response fields are rejected" {
    var entries: [1]Entry = undefined;
    const name = "x" ** 256;
    const response = "@mp\t1\tslash\tok\t/\t1\nB\t" ++ name ++ "\t\t\n@@MP_END@@\n";
    try std.testing.expect(parseResponse(response, &entries) == null);
}

test "recent picks move to front without duplicates" {
    var items: [20][201]u8 = .{.{0} ** 201} ** 20;
    var count: usize = 0;
    promoteRecent(&items, &count, "clear");
    promoteRecent(&items, &count, "compact");
    promoteRecent(&items, &count, "clear");
    try std.testing.expectEqual(@as(usize, 2), count);
    try std.testing.expectEqualStrings("clear", std.mem.sliceTo(&items[0], 0));
    try std.testing.expectEqualStrings("compact", std.mem.sliceTo(&items[1], 0));
    for (0..22) |i| {
        var buf: [8]u8 = undefined;
        promoteRecent(&items, &count, try std.fmt.bufPrint(&buf, "item{d}", .{i}));
    }
    try std.testing.expectEqual(@as(usize, 20), count);
    try std.testing.expectEqualStrings("item21", std.mem.sliceTo(&items[0], 0));
}
