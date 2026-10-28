const std = @import("std");
const versionNewer = @import("update_check.zig").versionNewer;

pub const Release = struct { version: []const u8, changes: []const []const u8 };
pub const Document = struct { version: []const u8, releases: []const Release };
pub const COLLAPSED_LINES = 3;

pub const Notes = struct {
    lines: [16][512]u8 = @splat(@splat(0)),
    lengths: [16]usize = @splat(0),
    count: usize = 0,
    total: usize = 0,

    pub fn shown(self: *const Notes, expanded: bool) usize {
        return if (expanded) self.count else @min(self.count, COLLAPSED_LINES);
    }

    pub fn hidden(self: *const Notes, expanded: bool) usize {
        return self.total - self.shown(expanded);
    }

    pub fn line(self: *const Notes, i: usize) []const u8 {
        return self.lines[i][0..self.lengths[i]];
    }

    pub fn more(self: *const Notes, buf: []u8, expanded: bool) []const u8 {
        const rest = self.hidden(expanded);
        if (rest == 0) return "";
        return std.fmt.bufPrint(buf, "and {d} more", .{rest}) catch "";
    }
};

pub fn plain(text: []const u8) bool {
    if (text.len == 0 or text.len > 512 or !std.unicode.utf8ValidateSlice(text)) return false;
    for (text, 0..) |c, i| {
        if (c < 32 or c == 127 or c == '/' or c == '\\' or c == '`') return false;
        for ([_][]const u8{ "PR ", "pull request " }) |prefix| {
            if (i + prefix.len < text.len and std.ascii.eqlIgnoreCase(text[i .. i + prefix.len], prefix)) {
                const rest = std.mem.trimStart(u8, text[i + prefix.len ..], " #");
                if (rest.len > 0 and std.ascii.isDigit(rest[0])) return false;
            }
        }
        if (c == '#' and i + 1 < text.len and std.ascii.isDigit(text[i + 1])) return false;
        if (c == '-' and i + 1 < text.len and std.ascii.isDigit(text[i + 1])) {
            var start = i;
            while (start > 0 and std.ascii.isUpper(text[start - 1])) start -= 1;
            if (start < i) return false;
        }
        if (c == '.' and i > 0 and i + 1 < text.len and std.ascii.isAlphanumeric(text[i - 1]) and std.ascii.isAlphabetic(text[i + 1])) return false;
    }
    for ([_][]const u8{ "behind the scenes", "latest improvements" }) |filler| {
        if (std.ascii.indexOfIgnoreCase(text, filler) != null) return false;
    }
    for ([_][]const u8{ "Various improvements.", "Bug fixes.", "Maintenance.", "Improvements.", "Fixes." }) |filler| {
        if (std.ascii.eqlIgnoreCase(text, filler)) return false;
    }
    var words = std.mem.tokenizeAny(u8, text, " .,;:!?()-");
    while (words.next()) |word| {
        for ([_][]const u8{ "check", "checks", "test", "tests", "CI", "proof", "proofs", "pipeline", "pipelines", "workflow", "workflows" }) |internal| {
            if (std.ascii.eqlIgnoreCase(word, internal)) return false;
        }
    }
    return true;
}

pub fn pick(releases: []const Release, installed: []const u8, offered: []const u8) Notes {
    var result = Notes{};
    var versions: [16][]const u8 = undefined;
    for (releases) |release| {
        if (!versionNewer(installed, release.version) or versionNewer(offered, release.version)) continue;
        for (release.changes) |raw| {
            const text = std.mem.trim(u8, raw, " \t\r\n");
            if (!plain(text)) continue;
            result.total += 1;
            var at: usize = 0;
            while (at < result.count and !versionNewer(versions[at], release.version)) at += 1;
            if (at == result.lines.len) continue;
            var end = @min(result.count, result.lines.len - 1);
            while (end > at) : (end -= 1) {
                result.lines[end] = result.lines[end - 1];
                result.lengths[end] = result.lengths[end - 1];
                versions[end] = versions[end - 1];
            }
            @memcpy(result.lines[at][0..text.len], text);
            result.lengths[at] = text.len;
            versions[at] = release.version;
            result.count = @min(result.count + 1, result.lines.len);
        }
    }
    return result;
}

test "IGSH-728 picks only versions between installed and offered, newest first" {
    const releases = [_]Release{
        .{ .version = "1.9.0", .changes = &.{"Already installed."} },
        .{ .version = "1.10.0", .changes = &.{"Older change."} },
        .{ .version = "2.0.0", .changes = &.{"Not offered yet."} },
        .{ .version = "1.11.0", .changes = &.{ "Newest change.", "Another new change." } },
    };
    const notes = pick(&releases, "1.9.0", "1.11.0");
    try std.testing.expectEqual(@as(usize, 3), notes.count);
    try std.testing.expectEqualStrings("Newest change.", notes.line(0));
    try std.testing.expectEqualStrings("Another new change.", notes.line(1));
    try std.testing.expectEqualStrings("Older change.", notes.line(2));
    try std.testing.expectEqual(@as(usize, 0), pick(&releases, "1.11.0", "1.9.0").count);
}

test "IGSH-948 shows three lines then and N more, and the full list when expanded" {
    const releases = [_]Release{.{ .version = "1.1.0", .changes = &.{ "One.", "Two.", "Three.", "Four." } }};
    const notes = pick(&releases, "1.0.0", "1.1.0");
    try std.testing.expectEqual(@as(usize, 4), notes.count);
    try std.testing.expectEqual(@as(usize, 3), notes.shown(false));
    try std.testing.expectEqual(@as(usize, 4), notes.shown(true));
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("and 1 more", notes.more(&buf, false));
    try std.testing.expectEqualStrings("", notes.more(&buf, true));
    try std.testing.expectEqualStrings("", (Notes{}).more(&buf, false));
}

test "IGSH-948 keeps sixteen lines and counts the rest as more even when expanded" {
    const releases = [_]Release{.{ .version = "1.1.0", .changes = &.{ "A1.", "A2.", "A3.", "A4.", "A5.", "A6.", "A7.", "A8.", "A9.", "B1.", "B2.", "B3.", "B4.", "B5.", "B6.", "B7.", "B8.", "B9." } }};
    const notes = pick(&releases, "1.0.0", "1.1.0");
    try std.testing.expectEqual(@as(usize, 16), notes.count);
    try std.testing.expectEqual(@as(usize, 18), notes.total);
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("and 15 more", notes.more(&buf, false));
    try std.testing.expectEqualStrings("and 2 more", notes.more(&buf, true));
}

test "IGSH-1090 keeps real notes individual and maintenance releases quiet" {
    const releases = [_]Release{
        .{ .version = "1.1.0", .changes = &.{"Typing feels faster."} },
        .{ .version = "1.2.0", .changes = &.{"Updates include the latest improvements."} },
        .{ .version = "1.3.0", .changes = &.{ "Behind the scenes fixes.", "Chat speed checks now ignore shared-machine pauses." } },
        .{ .version = "1.4.0", .changes = &.{} },
        .{ .version = "1.5.0", .changes = &.{"Dictation shortcuts keep working when keys queue up."} },
    };
    const notes = pick(&releases, "1.0.0", "1.5.0");
    try std.testing.expectEqual(@as(usize, 2), notes.count);
    try std.testing.expectEqualStrings("Dictation shortcuts keep working when keys queue up.", notes.line(0));
    try std.testing.expectEqualStrings("Typing feels faster.", notes.line(1));
    const quiet = pick(&releases, "1.1.0", "1.4.0");
    try std.testing.expectEqual(@as(usize, 0), quiet.count);
    try std.testing.expectEqual(@as(usize, 0), quiet.total);
    const waiting = pick(&releases, "1.0.0", "1.4.0");
    try std.testing.expectEqualStrings("Typing feels faster.", waiting.line(0));
}

test "IGSH-728 skips ticket ids, file paths, file names and PR numbers" {
    const releases = [_]Release{.{ .version = "1.1.0", .changes = &.{ "Fix IGSH-123.", "Fix src/main.zig.", "Fix C:\\app\\settings.", "Fix update.zig.", "Fix PR #12.", "Fix PR 12.", "Typing feels faster." } }};
    const notes = pick(&releases, "1.0.0", "1.1.0");
    try std.testing.expectEqual(@as(usize, 1), notes.total);
    try std.testing.expectEqualStrings("Typing feels faster.", notes.line(0));
}
