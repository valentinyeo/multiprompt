const std = @import("std");
const archive_rules = @import("archive_rules.zig");

pub fn parse(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(std.json.Value) {
    return std.json.parseFromSlice(std.json.Value, allocator, bytes, .{ .parse_numbers = false });
}

pub fn field(value: std.json.Value, key: []const u8) std.json.Value {
    return if (value == .object) value.object.get(key) orelse .null else .null;
}

pub fn array(value: std.json.Value) []const std.json.Value {
    return if (value == .array) value.array.items else &.{};
}

pub fn string(value: std.json.Value) ?[]const u8 {
    return if (value == .string) value.string else null;
}

pub fn boolean(value: std.json.Value, fallback: bool) bool {
    return if (value == .bool) value.bool else fallback;
}

pub fn unsigned(value: std.json.Value, fallback: u64) u64 {
    return switch (value) {
        .integer => if (value.integer >= 0) @intCast(value.integer) else fallback,
        .number_string => std.fmt.parseInt(u64, value.number_string, 10) catch fallback,
        .string => std.fmt.parseInt(u64, value.string, 10) catch fallback,
        else => fallback,
    };
}

pub fn uint(value: std.json.Value, key: []const u8) u64 {
    return unsigned(field(value, key), 0);
}

pub fn uintDefault(value: std.json.Value, key: []const u8, fallback: u64) u64 {
    const v = field(value, key);
    return if (v == .string) fallback else unsigned(v, fallback);
}

pub fn boolTrue(value: std.json.Value, key: []const u8) bool {
    return boolean(field(value, key), false);
}

pub fn boolFalse(value: std.json.Value, key: []const u8) bool {
    return !boolean(field(value, key), true);
}

pub fn copyString(value: std.json.Value, key: []const u8, out: []u8) u32 {
    if (out.len == 0) return 0;
    const text = string(field(value, key)) orelse return 0;
    var n = @min(text.len, out.len - 1);
    while (n > 0 and n < text.len and text[n] & 0xc0 == 0x80) n -= 1;
    @memcpy(out[0..n], text[0..n]);
    out[n] = 0;
    return @intCast(n);
}

pub fn copyWide(value: std.json.Value, key: []const u8, out: []u16) u32 {
    return wide(string(field(value, key)) orelse "", out);
}

pub fn wide(text: []const u8, out: []u16) u32 {
    if (out.len == 0) return 0;
    var it = std.unicode.Utf8View.init(text) catch return 0;
    var iter = it.iterator();
    var n: usize = 0;
    while (iter.nextCodepointSlice()) |cp| {
        const units: usize = if (cp.len == 4) 2 else 1;
        if (n + units >= out.len) break;
        n += std.unicode.utf8ToUtf16Le(out[n..], cp) catch break;
    }
    out[n] = 0;
    return @intCast(n);
}

pub fn utf8(text: []const u16, out: []u8) []const u8 {
    const n = std.unicode.utf16LeToUtf8(out, text) catch return "";
    return out[0..n];
}

pub fn archiveContent(value: std.json.Value, key: []const u8) archive_rules.Content {
    var result = archive_rules.Content{};
    const text = string(field(value, key)) orelse return result;
    var p: usize = 0;
    while (p + 16 <= text.len and result.len < result.rows.len) : (p += 16) {
        result.rows[result.len] = std.fmt.parseInt(u64, text[p..][0..16], 16) catch return result;
        result.len += 1;
    }
    return result;
}

pub fn sessionTabs(root: std.json.Value, tabs: anytype, max_workspaces: u8) u32 {
    const Tab = @TypeOf(tabs[0]);
    var count: u32 = 0;
    for (array(field(root, "tabs"))) |obj| {
        if (count == tabs.len) break;
        const kind = string(field(obj, "kind")) orelse continue;
        if (string(field(obj, "name")) == null) continue;
        const tab = &tabs[count];
        tab.* = std.mem.zeroes(Tab);
        tab.kind = if (std.mem.eql(u8, kind, "pwsh")) .pwsh else if (std.mem.eql(u8, kind, "vps")) .vps else if (std.mem.eql(u8, kind, "tmux")) .tmux else if (std.mem.eql(u8, kind, "vps2")) .vps2 else if (std.mem.eql(u8, kind, "bash")) .bash else if (std.mem.eql(u8, kind, "gitbash")) .gitbash else .cmd;
        tab.name_len = copyWide(obj, "name", &tab.name);
        tab.tmux_session_len = copyString(obj, "tmux_session", &tab.tmux_session);
        tab.cwd_len = copyString(obj, "cwd", &tab.cwd);
        tab.favicon_path_len = copyString(obj, "favicon_path", &tab.favicon_path);
        tab.claude_sid_len = copyString(obj, "csid", &tab.claude_sid);
        tab.claude_cwd_len = copyString(obj, "ccwd", &tab.claude_cwd);
        tab.burl_len = copyString(obj, "burl", &tab.burl);
        inline for (.{ "sync_owned", "manual", "sem", "claude_session", "muted", "keep_alive", "pinned_top", "inbox_excluded", "favorite", "locked", "bon", "kaw", "cv" }) |key| {
            @field(tab, key) = boolTrue(obj, key);
        }
        tab.inbox_archived = boolTrue(obj, "iah");
        tab.needs_attention = boolTrue(obj, "att");
        tab.bnat = !boolFalse(obj, "bnat");
        tab.wake_id = @intCast(@min(uint(obj, "wake_id"), std.math.maxInt(u32)));
        tab.pid = @truncate(uint(obj, "pid"));
        tab.group_id = @truncate(uint(obj, "group_id"));
        tab.tmux_host = @truncate(uint(obj, "tmux_host"));
        const workspace = uint(obj, "workspace");
        tab.workspace = if (workspace < max_workspaces) @intCast(workspace) else 0;
        tab.last_active = uint(obj, "la");
        tab.last_viewed = uint(obj, "lv");
        tab.archive_time = uint(obj, "archive_time");
        tab.archive_done = uint(obj, "archive_done");
        tab.last_done_time = uint(obj, "last_done_time");
        tab.archive_content = archiveContent(obj, "archive_rows");
        tab.archive_content_valid = string(field(obj, "archive_rows")) != null;
        tab.last_done_content = archiveContent(obj, "done_rows");
        tab.last_done_content_valid = string(field(obj, "done_rows")) != null;
        const split = unsigned(field(obj, "bsplit"), 350);
        tab.bsplit_permille = @intCast(@max(50, @min(split, 950)));
        count += 1;
    }
    return count;
}

test "JSON fields are scoped and decode escapes, Unicode, nested extras and reordered keys" {
    var parsed = try parse(std.testing.allocator, "{\"extra\":{\"csid\":\"wrong\"},\"name\":\"quote \\\"csid\\\":\\\"x\\\" } ] \\n café \\u65e5\\ud83d\\ude80\",\"csid\":\"right\",\"n\":18446744073709551615,\"old_number\":\"42\",\"favorite\":true}");
    defer parsed.deinit();
    var out: [128]u8 = undefined;
    const n = copyString(parsed.value, "name", &out);
    try std.testing.expectEqualStrings("quote \"csid\":\"x\" } ] \n café 日🚀", out[0..n]);
    try std.testing.expectEqualStrings("right", string(field(parsed.value, "csid")).?);
    try std.testing.expectEqual(std.math.maxInt(u64), uint(parsed.value, "n"));
    try std.testing.expectEqual(@as(u64, 42), uint(parsed.value, "old_number"));
    try std.testing.expect(boolTrue(parsed.value, "favorite"));
    try std.testing.expect(!boolTrue(parsed.value, "missing"));
    try std.testing.expect(!boolFalse(parsed.value, "missing"));
    try std.testing.expectEqual(@as(u64, 7), uintDefault(parsed.value, "missing", 7));
    const serialized = try std.json.Stringify.valueAlloc(std.testing.allocator, parsed.value, .{});
    defer std.testing.allocator.free(serialized);
    var restored = try parse(std.testing.allocator, serialized);
    defer restored.deinit();
    try std.testing.expectEqualStrings(string(field(parsed.value, "name")).?, string(field(restored.value, "name")).?);
}

test "UTF16 truncation keeps surrogate pairs intact and handles raw and escaped Unicode identically" {
    var parsed = try parse(std.testing.allocator, "{\"a\":\"日🚀é\",\"b\":\"\\u65e5\\ud83d\\ude80\\u00e9\"}");
    defer parsed.deinit();
    var a: [8]u16 = undefined;
    var b: [8]u16 = undefined;
    const n = copyWide(parsed.value, "a", &a);
    try std.testing.expectEqual(n, copyWide(parsed.value, "b", &b));
    try std.testing.expectEqualSlices(u16, a[0..n], b[0..n]);
    var short: [3]u16 = undefined;
    try std.testing.expectEqual(@as(u32, 1), copyWide(parsed.value, "a", &short));
}
